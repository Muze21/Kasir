import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Palet warna Kaskita — hangat, tenang, bukan default Material.
class _Palette {
  static const ink = Color(0xFF17150F);
  static const paper = Color(0xFFFBFAF6);
  static const moss = Color(0xFF2F4A34);
  static const ember = Color(0xFF9F2F2D);
  static const sand = Color(0xFF938C7C);
  static const line = Color(0xFFE6E1D6);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Register

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isLogin) {
        // Proses Login
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        // Proses Register
        final name = _nameController.text.trim();
        if (name.isEmpty) throw Exception('Nama lengkap wajib diisi.');

        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name}, // Akan ditangkap oleh trigger DB
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pendaftaran berhasil. Silakan login (atau cek email jika butuh verifikasi).',
              ),
              backgroundColor: _Palette.moss,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLogin = true); // Balik ke halaman login
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_isLogin ? 'Login' : 'Daftar'} Gagal: ${e.toString()}'),
            backgroundColor: _Palette.ember,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      // Eksplisit dimatikan — kalau tidak, field jatuh balik ke
      // InputDecorationTheme global (kalau ada filled:true di ThemeData),
      // dan hasilnya jadi kotak putih dengan shadow, bukan underline flat.
      filled: false,
      fillColor: Colors.transparent,
      isDense: true,
      labelStyle: const TextStyle(color: _Palette.sand, fontSize: 15),
      floatingLabelStyle: const TextStyle(
        color: _Palette.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.only(bottom: 10, top: 8),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: _Palette.line),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _Palette.line),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _Palette.moss, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 48.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Masthead ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(34, 34),
                        painter: _CoinMarkPainter(),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Kaskita.',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: _Palette.ink,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      _isLogin
                          ? 'Sistem pencatatan toko keluarga.'
                          : 'Daftarkan anggota keluarga baru.',
                      key: ValueKey(_isLogin),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _Palette.sand,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Container(height: 1, color: _Palette.line),
                  const SizedBox(height: 32),

                  // --- Form ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: !_isLogin
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: TextField(
                              controller: _nameController,
                              decoration: _fieldDecoration('Nama'),
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: _Palette.ink, fontSize: 16),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  TextField(
                    controller: _emailController,
                    decoration: _fieldDecoration('email'),
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: _Palette.ink, fontSize: 16),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _passwordController,
                    decoration: _fieldDecoration('password'),
                    obscureText: true,
                    style: const TextStyle(color: _Palette.ink, fontSize: 16),
                  ),
                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Material(
                      color: _isLoading ? _Palette.sand : _Palette.moss,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _isLoading ? null : _submit,
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _Palette.paper,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Masuk' : 'Daftar sekarang',
                                  style: const TextStyle(
                                    color: _Palette.paper,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _toggleMode,
                      style: TextButton.styleFrom(
                        foregroundColor: _Palette.sand,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: _isLogin
                              ? 'Belum punya akun? '
                              : 'Sudah punya akun? ',
                          style: const TextStyle(fontSize: 14, color: _Palette.sand),
                          children: [
                            TextSpan(
                              text: _isLogin ? 'Daftar di sini' : 'Masuk',
                              style: const TextStyle(
                                fontSize: 14,
                                color: _Palette.moss,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tanda kecil bermotif koin/celengan — pengganti Icons.store generik.
/// Lingkaran dengan slot koin di atas, merepresentasikan "pundi" (kas keluarga).
class _CoinMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = _Palette.moss
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    canvas.drawCircle(center, radius, ringPaint);

    // Slot koin — garis horizontal pendek di tengah, seperti lubang
    // celengan, ditambah satu titik koin kecil di bawahnya.
    final slotPaint = Paint()
      ..color = _Palette.ember
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - 5, center.dy - 2),
      Offset(center.dx + 5, center.dy - 2),
      slotPaint,
    );

    final coinPaint = Paint()
      ..color = _Palette.ember
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy + 5), 2, coinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}