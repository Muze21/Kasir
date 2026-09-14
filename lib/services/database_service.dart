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

  // GET SHIFT STATS SEMENTARA
  Future<ShiftStats> getShiftStats(String shiftId) async {
    final orders = await _supabase
        .from('orders')
        .select('total_amount')
        .eq('shift_id', shiftId);
    final expenses = await _supabase
        .from('expenses')
        .select('amount')
        .eq('shift_id', shiftId);
    return ShiftStats.fromData(
      orderCount: (orders as List).length,
      orders: orders as List,
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
        .order('created_at', ascending: false);

    return (response as List).map((json) => Order.fromJson(json)).toList();
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
    for (final o in orders) {
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
      totalOrders: orders.length,
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
}

class _UserStatsAcc {
  final String userId;
  final String userName;
  int orderCount = 0;
  double omzet = 0;
  double expenses = 0;

  _UserStatsAcc({required this.userId, required this.userName});
}
