import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../models/pos_models.dart';
import 'pos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  Profile? _profile;
  Shift? _activeShift;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final profile = await _db.getCurrentProfile();
    final shift = await _db.getActiveShift();
    setState(() {
      _profile = profile;
      _activeShift = shift;
      _isLoading = false;
    });
  }

  Future<void> _openShift() async {
    try {
      final shift = await _db.openShift();
      setState(() => _activeShift = shift);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PosScreen(shift: shift)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Buka Toko: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kaskita'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${_profile?.fullName ?? 'User'}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Toko: ${_activeShift != null ? 'BUKA' : 'TUTUP'}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _activeShift != null ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _activeShift == null
                              ? ElevatedButton(
                                  onPressed: _openShift,
                                  child: const Text('Buka Toko'),
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PosScreen(shift: _activeShift!),
                                      ),
                                    ).then((_) => _loadData());
                                  },
                                  child: const Text('Masuk ke Kasir'),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
