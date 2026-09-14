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

  // GET SHIFT STATS (summary buat dashboard)
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

  // GET PROFILE BY ID (buat "Dibuka oleh")
  Future<Profile?> getProfileById(String id) async {
    final res = await _supabase
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return res != null ? Profile.fromJson(res) : null;
  }

  // OPEN SHIFT
  Future<Shift> openShift() async {
    final res = await _supabase.from('shifts').insert({
      'opened_by': currentUserId,
      'status': 'open',
    }).select().single();
    return Shift.fromJson(res);
  }

  // CREATE ORDER
  Future<void> createOrder(String shiftId, double total, List<Map<String, dynamic>> items, {String? customerName}) async {
    // Insert order (user_id otomatis diisi Supabase karena DEFAULT auth.uid(), 
    // tapi kita bisa force kirim dari Flutter untuk safety)
    final orderResponse = await _supabase.from('orders').insert({
      'shift_id': shiftId,
      'total_amount': total,
      'customer_name': customerName,
      'user_id': currentUserId, // UUID otomatis dari akun yang login
    }).select().single();

    final orderId = orderResponse['id'];

    // Insert items
    final orderItems = items.map((item) => {
      'order_id': orderId,
      'item_name': item['name'],
      'qty': item['qty'],
      'price': item['price'],
      'subtotal': item['qty'] * item['price'],
    }).toList();

    await _supabase.from('order_items').insert(orderItems);
  }

  // CREATE EXPENSE
  Future<void> createExpense(String shiftId, String note, double amount) async {
    await _supabase.from('expenses').insert({
      'shift_id': shiftId,
      'note': note,
      'amount': amount,
      'user_id': currentUserId, // UUID otomatis dari akun yang login
    });
  }

  // GET ORDERS DENGAN NAMA PENCATAT (JOIN PROFILES)
  Future<List<Order>> getOrders(String shiftId) async {
    final response = await _supabase
        .from('orders')
        .select('*, profiles(id, full_name)') // Query relasi otomatis
        .eq('shift_id', shiftId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Order.fromJson(json)).toList();
  }

  // GET EXPENSES DENGAN NAMA PENCATAT (JOIN PROFILES)
  Future<List<Expense>> getExpenses(String shiftId) async {
    final response = await _supabase
        .from('expenses')
        .select('*, profiles(id, full_name)') // Query relasi otomatis
        .eq('shift_id', shiftId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Expense.fromJson(json)).toList();
  }
}
