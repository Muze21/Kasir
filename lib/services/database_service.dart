import 'package:intl/intl.dart';
import '../models/pos_models.dart';
import '../config/supabase_config.dart';

class DatabaseService {
  final _supabase = SupabaseConfig.client;

  String get currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    return user.id;
  }

  // GET PROFIL USER SEKARANG
  Future<Profile?> getCurrentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final res = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return res != null ? Profile.fromJson(res) : null;
  }

  // GET SHIFT ACTIVE
  Future<Shift?> getActiveShift() async {
    final res = await _supabase
        .from('shifts')
        .select()
        .eq('status', 'open')
        .order('opened_at', ascending: false)
        .maybeSingle();
    return res != null ? Shift.fromJson(res) : null;
  }

  // BUKA TOKO (OPEN SHIFT)
  Future<Shift> openShift() async {
    final res = await _supabase.from('shifts').insert({
      'opened_by': currentUserId,
      'status': 'open',
    }).select().single();
    return Shift.fromJson(res);
  }

  // TUTUP TOKO (CLOSE SHIFT)
  Future<void> closeShift(String shiftId) async {
    await _supabase.from('shifts').update({
      'status': 'closed',
      'closed_at': DateTime.now().toIso8601String(),
      'closed_by': currentUserId,
    }).eq('id', shiftId);
  }

  // GET LIST RIWAYAT SHIFT TUTUP
  Future<List<Shift>> getClosedShifts() async {
    final res = await _supabase
        .from('shifts')
        .select('*, opener:profiles!opened_by(*), closer:profiles!closed_by(*)')
        .eq('status', 'closed')
        .order('closed_at', ascending: false)
        .limit(30);

    return (res as List).map((json) => Shift.fromJson(json)).toList();
  }

  // GET SHIFT TUTUP TERAKHIR
  Future<Shift?> getLastClosedShift() async {
    final res = await _supabase
        .from('shifts')
        .select('*, opener:profiles!opened_by(*), closer:profiles!closed_by(*)')
        .eq('status', 'closed')
        .order('closed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return res != null ? Shift.fromJson(res) : null;
  }

  // GET SHIFT BERDASARKAN ID
  Future<Shift?> getShiftById(String shiftId) async {
    try {
      final res = await _supabase
          .from('shifts')
          .select('*, opener:profiles!opened_by(*), closer:profiles!closed_by(*)')
          .eq('id', shiftId)
          .maybeSingle();

      return res != null ? Shift.fromJson(res) : null;
    } catch (_) {
      final res = await _supabase
          .from('shifts')
          .select()
          .eq('id', shiftId)
          .maybeSingle();
      return res != null ? Shift.fromJson(res) : null;
    }
  }

  // GET SHIFT STATS SEMENTARA
  Future<ShiftStats> getShiftStats(String shiftId) async {
    List<dynamic> ordersList;
    try {
      final orders = await _supabase
          .from('orders')
          .select('total_amount, status')
          .eq('shift_id', shiftId);
      ordersList = orders as List;
    } catch (_) {
      final orders = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('shift_id', shiftId);
      ordersList = orders as List;
    }
    final expenses = await _supabase
        .from('expenses')
        .select('amount')
        .eq('shift_id', shiftId);
    return ShiftStats.fromData(
      orderCount: ordersList.length,
      orders: ordersList,
      expenses: expenses as List,
    );
  }

  // GET PROFILE BY ID
  Future<Profile?> getProfileById(String id) async {
    final res = await _supabase
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return res != null ? Profile.fromJson(res) : null;
  }

  // BUAT TRANSAKSI (CREATE ORDER + ITEMS)
  Future<int> createOrder({
    required String shiftId,
    required double total,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? customerName,
  }) async {
    // 1. Hitung nomor antrean berikutnya di shift ini
    final existingOrders = await _supabase
        .from('orders')
        .select('id')
        .eq('shift_id', shiftId);
    final nextQueueNumber = (existingOrders as List).length + 1;

    // 2. Insert order
    final orderRes = await _supabase.from('orders').insert({
      'shift_id': shiftId,
      'total_amount': total,
      'payment_method': paymentMethod, // 'cash' atau 'qris'
      'customer_name': (customerName != null && customerName.isNotEmpty) ? customerName : null,
      'user_id': currentUserId,
      'queue_number': nextQueueNumber,
    }).select().single();

    final orderId = orderRes['id'];

    // 3. Insert items
    final orderItems = items.map((item) {
      final name = (item['item_name'] ?? item['name'] ?? 'Item').toString();
      final rawQty = item['qty'] ?? item['quantity'] ?? 1;
      final rawPrice = item['price'] ?? 0;
      final qty = (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 1);
      final price = (rawPrice is num) ? rawPrice.toDouble() : (double.tryParse(rawPrice.toString()) ?? 0.0);
      final rawSubtotal = item['subtotal'];
      final subtotal = (rawSubtotal is num) ? rawSubtotal.toDouble() : (qty * price);

      return {
        'order_id': orderId,
        'item_name': name,
        'qty': qty,
        'price': price,
        'subtotal': subtotal,
      };
    }).toList();

    await _supabase.from('order_items').insert(orderItems);

    final rawQueue = orderRes['queue_number'];
    return (rawQueue is num) ? rawQueue.toInt() : nextQueueNumber;
  }

  // CATAT PENGELUARAN (CREATE EXPENSE)
  Future<void> createExpense({
    required String shiftId,
    required String note,
    required double amount,
  }) async {
    await _supabase.from('expenses').insert({
      'shift_id': shiftId,
      'note': note,
      'amount': amount,
      'user_id': currentUserId,
    });
  }

  // AMBIL SEMUA ORDER DI SATU SHIFT (BESERTA ITEMS & PROFILE INPUT)
  Future<List<Order>> getOrders(String shiftId) async {
    final response = await _supabase
        .from('orders')
        .select('*, profiles(id, full_name), order_items(*)')
        .eq('shift_id', shiftId)
        .order('queue_number', ascending: false);

    return (response as List).map((json) => Order.fromJson(json)).toList();
  }

  // BATALKAN / VOID ORDER
  Future<bool> voidOrder(String orderId, {String? reason}) async {
    try {
      // Coba soft-delete jika kolom status sudah ada di Supabase
      await _supabase.from('orders').update({
        'status': 'voided',
        'void_reason': (reason != null && reason.trim().isNotEmpty) ? reason.trim() : 'Dibatalkan kasir',
      }).eq('id', orderId);
      return true;
    } catch (_) {
      // Fallback jika database belum ada kolom status:
      // Lakukan hard-delete agar pesanan terhapus dan omzet shift tetap akurat
      await _supabase.from('orders').delete().eq('id', orderId);
      return false;
    }
  }

  // AMBIL SEMUA PENGELUARAN DI SATU SHIFT
  Future<List<Expense>> getExpenses(String shiftId) async {
    final response = await _supabase
        .from('expenses')
        .select('*, profiles(id, full_name)')
        .eq('shift_id', shiftId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Expense.fromJson(json)).toList();
  }

  // HITUNG LAPORAN LENGKAP SHIFT (TOTAL TOKO + BREAKDOWN USER)
  Future<ShiftReportData> getShiftReport(String shiftId) async {
    // Ambil info shift
    final shiftRes = await _supabase
        .from('shifts')
        .select('*, opener:profiles!opened_by(*), closer:profiles!closed_by(*)')
        .eq('id', shiftId)
        .single();
    final shift = Shift.fromJson(shiftRes);

    final orders = await getOrders(shiftId);
    final expenses = await getExpenses(shiftId);

    double totalOmzet = 0;
    double totalCash = 0;
    double totalQris = 0;
    int activeOrdersCount = 0;

    for (final o in orders) {
      if (o.isVoided) continue;
      activeOrdersCount++;
      totalOmzet += o.totalAmount;
      if (o.paymentMethod == 'qris') {
        totalQris += o.totalAmount;
      } else {
        totalCash += o.totalAmount;
      }
    }

    double totalExpenses = 0;
    for (final e in expenses) {
      totalExpenses += e.amount;
    }

    // Breakdown per user
    final Map<String, _UserStatsAcc> userMap = {};

    for (final o in orders) {
      if (o.isVoided) continue;
      final uid = o.userId;
      final name = o.profile?.fullName ?? 'User ($uid)';
      userMap.putIfAbsent(uid, () => _UserStatsAcc(userId: uid, userName: name));
      userMap[uid]!.orderCount += 1;
      userMap[uid]!.omzet += o.totalAmount;
    }

    for (final e in expenses) {
      final uid = e.userId;
      final name = e.profile?.fullName ?? 'User ($uid)';
      userMap.putIfAbsent(uid, () => _UserStatsAcc(userId: uid, userName: name));
      userMap[uid]!.expenses += e.amount;
    }

    final contributions = userMap.values.map((u) => UserContribution(
      userId: u.userId,
      userName: u.userName,
      orderCount: u.orderCount,
      omzet: u.omzet,
      expenses: u.expenses,
    )).toList();

    return ShiftReportData(
      shift: shift,
      totalOrders: activeOrdersCount,
      totalOmzet: totalOmzet,
      totalCash: totalCash,
      totalQris: totalQris,
      totalExpenses: totalExpenses,
      bersih: totalOmzet - totalExpenses,
      userContributions: contributions,
      orders: orders,
      expenses: expenses,
    );
  }

  // LAPORAN BERKALA (MINGGUAN / BULANAN / HARIAN)
  Future<PeriodicReportData> getPeriodicReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startIso = startDate.toUtc().toIso8601String();
    final endIso = endDate.toUtc().toIso8601String();

    // 1. Ambil orders dalam rentang waktu
    final ordersRes = await _supabase
        .from('orders')
        .select('*, profiles(id, full_name), order_items(*)')
        .gte('created_at', startIso)
        .lte('created_at', endIso)
        .order('created_at', ascending: true);

    final orders = (ordersRes as List).map((j) => Order.fromJson(j)).toList();

    // 2. Ambil expenses dalam rentang waktu
    final expensesRes = await _supabase
        .from('expenses')
        .select('*, profiles(id, full_name)')
        .gte('created_at', startIso)
        .lte('created_at', endIso)
        .order('created_at', ascending: true);

    final expenses = (expensesRes as List).map((j) => Expense.fromJson(j)).toList();

    // 3. Hitung total finansial
    double totalOmzet = 0;
    double totalCash = 0;
    double totalQris = 0;
    int cashCount = 0;
    int qrisCount = 0;
    int activeOrdersCount = 0;

    for (final o in orders) {
      if (o.isVoided) continue;
      activeOrdersCount++;
      totalOmzet += o.totalAmount;
      if (o.paymentMethod == 'qris') {
        totalQris += o.totalAmount;
        qrisCount++;
      } else {
        totalCash += o.totalAmount;
        cashCount++;
      }
    }

    double totalExpenses = 0;
    for (final e in expenses) {
      totalExpenses += e.amount;
    }

    // 4. Hitung Top Selling Items (Menu Terlaris)
    final Map<String, _ItemAgg> itemMap = {};
    for (final o in orders) {
      if (o.isVoided) continue;
      for (final item in o.items) {
        final name = item.itemName;
        itemMap.putIfAbsent(name, () => _ItemAgg(itemName: name));
        itemMap[name]!.totalQty += item.qty;
        itemMap[name]!.totalRevenue += item.subtotal;
      }
    }
    final topItems = itemMap.values
        .map((i) => TopItemSummary(
              itemName: i.itemName,
              totalQty: i.totalQty,
              totalRevenue: i.totalRevenue,
            ))
        .toList()
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));

    // 5. Agregasi Harian (Daily Summary) untuk grafik
    final Map<String, _DailyAgg> dailyMap = {};
    DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    while (!cursor.isAfter(endDay)) {
      final key = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      dailyMap[key] = _DailyAgg(date: cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    for (final o in orders) {
      if (o.isVoided) continue;
      final localDate = o.createdAt.toLocal();
      final key = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
      if (dailyMap.containsKey(key)) {
        dailyMap[key]!.omzet += o.totalAmount;
        dailyMap[key]!.orderCount += 1;
      }
    }

    for (final e in expenses) {
      final localDate = e.createdAt.toLocal();
      final key = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
      if (dailyMap.containsKey(key)) {
        dailyMap[key]!.expenses += e.amount;
      }
    }

    final dayFmt = DateFormat('E, d MMM', 'id_ID');
    final dailySummaries = dailyMap.values.map((d) {
      return DailySummary(
        date: d.date,
        dayLabel: dayFmt.format(d.date),
        omzet: d.omzet,
        expenses: d.expenses,
        orderCount: d.orderCount,
      );
    }).toList();

    return PeriodicReportData(
      startDate: startDate,
      endDate: endDate,
      totalOmzet: totalOmzet,
      totalExpenses: totalExpenses,
      bersih: totalOmzet - totalExpenses,
      totalOrders: activeOrdersCount,
      totalCash: totalCash,
      totalQris: totalQris,
      cashOrderCount: cashCount,
      qrisOrderCount: qrisCount,
      dailySummaries: dailySummaries,
      topItems: topItems,
      expenses: expenses,
      orders: orders,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MANAJEMEN PRODUK / MENU TOKO (CRUD)
  // ───────────────────────────────────────────────────────────────────────────
  static final List<Product> _fallbackProducts = [
    Product(id: 'prod-1', name: 'soto nasi', price: 12000.0, category: 'Makanan'),
    Product(id: 'prod-2', name: 'kerupuk gede', price: 5000.0, category: 'Makanan'),
    Product(id: 'prod-3', name: 'kerupuk kecil', price: 2000.0, category: 'Makanan'),
  ];

  Future<List<Product>> getProducts() async {
    try {
      final res = await _supabase
          .from('products')
          .select()
          .order('name', ascending: true);
      final list = (res as List).map((j) => Product.fromJson(j)).toList();
      if (list.isNotEmpty) {
        _fallbackProducts.clear();
        _fallbackProducts.addAll(list);
        return list;
      }
    } catch (_) {
      // Fallback ke cache in-memory jika tabel belum dibuat di Supabase
    }
    return List<Product>.from(_fallbackProducts);
  }

  Future<Product> addProduct({
    required String name,
    required double price,
    required String category,
  }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final newProduct = Product(
      id: tempId,
      name: name,
      price: price,
      category: category,
    );

    try {
      final res = await _supabase.from('products').insert({
        'name': name,
        'price': price,
        'category': category,
      }).select().single();
      final created = Product.fromJson(res);
      _fallbackProducts.removeWhere((p) => p.id == tempId);
      _fallbackProducts.add(created);
      return created;
    } catch (_) {
      _fallbackProducts.add(newProduct);
      return newProduct;
    }
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required double price,
    required String category,
  }) async {
    final index = _fallbackProducts.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _fallbackProducts[index] = Product(
        id: id,
        name: name,
        price: price,
        category: category,
      );
    }

    try {
      await _supabase.from('products').update({
        'name': name,
        'price': price,
        'category': category,
      }).eq('id', id);
    } catch (_) {
      // Offline fallback updated
    }
  }

  Future<void> deleteProduct(String id) async {
    _fallbackProducts.removeWhere((p) => p.id == id);
    try {
      await _supabase.from('products').delete().eq('id', id);
    } catch (_) {
      // Offline fallback deleted
    }
  }
}

class _UserStatsAcc {
  final String userId;
  final String userName;
  int orderCount = 0;
  double omzet = 0;
  double expenses = 0;

  _UserStatsAcc({required this.userId, required this.userName});
}

class _ItemAgg {
  final String itemName;
  int totalQty = 0;
  double totalRevenue = 0;
  _ItemAgg({required this.itemName});
}

class _DailyAgg {
  final DateTime date;
  double omzet = 0;
  double expenses = 0;
  int orderCount = 0;
  _DailyAgg({required this.date});
}
