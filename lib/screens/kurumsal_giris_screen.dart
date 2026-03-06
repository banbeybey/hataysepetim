import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kurumsal_provider.dart';
import '../services/kurumsal_api_service.dart';
import 'kurumsal_panel_screen.dart';

class KurumsalGirisScreen extends StatefulWidget {
  const KurumsalGirisScreen({super.key});

  @override
  State<KurumsalGirisScreen> createState() => _KurumsalGirisScreenState();
}

class _KurumsalGirisScreenState extends State<KurumsalGirisScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _userCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _gizle      = true;
  bool _yukleniyor = false;
  bool _beniHatirla = false;

  // Kayıtlı kimlik bilgisi varsa gösterilir
  Map<String, String>? _kayitliKimlik;
  bool _kayitliBannerGoster = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _baslat();
  }

  Future<void> _baslat() async {
    // 1) Otomatik giriş kontrolü (token zaten geçerliyse panel'e yönlendir)
    await _otomatikGirisKontrol();
    // 2) Kayıtlı kimlik varsa banner göster
    await _kayitliKimlikKontrol();
    // 3) Beni hatırla durumunu yükle
    final hatirla = await KurumsalApiService.beniHatirlaAktifMi();
    if (mounted) setState(() => _beniHatirla = hatirla);
  }

  Future<void> _otomatikGirisKontrol() async {
    final k = context.read<KurumsalProvider>();
    if (!k.yuklendi) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;
    if (k.girisYapildi) {
      _paneleGit();
    }
  }

  Future<void> _kayitliKimlikKontrol() async {
    final kimlik = await KurumsalApiService.kayitliKimlikGetir();
    if (!mounted) return;
    if (kimlik != null) {
      setState(() {
        _kayitliKimlik = kimlik;
        _kayitliBannerGoster = true;
      });
    }
  }

  /// Kayıtlı kimliği tek tıkla uygula (Google şifre yöneticisi davranışı)
  void _kayitliKimligiKullan() {
    if (_kayitliKimlik == null) return;
    _userCtrl.text = _kayitliKimlik!['username'] ?? '';
    _passCtrl.text = _kayitliKimlik!['password'] ?? '';
    setState(() => _kayitliBannerGoster = false);
    // Hemen giriş yap
    _girisYap();
  }

  /// Kayıtlı kimliği alanları doldur ama giriş yapma
  void _alanlariDoldur() {
    if (_kayitliKimlik == null) return;
    _userCtrl.text = _kayitliKimlik!['username'] ?? '';
    _passCtrl.text = _kayitliKimlik!['password'] ?? '';
    setState(() => _kayitliBannerGoster = false);
  }

  /// Kayıtlı kimliği unut ve sil
  Future<void> _kimligiUnut() async {
    await KurumsalApiService.kimlikSil();
    if (!mounted) return;
    setState(() {
      _kayitliKimlik = null;
      _kayitliBannerGoster = false;
      _beniHatirla = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Kayıtlı şifre silindi'),
      backgroundColor: const Color(0xFF333333),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _paneleGit() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const KurumsalPanelScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _yukleniyor = true);

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    final sonuc = await context.read<KurumsalProvider>().girisYap(
      username,
      password,
    );

    if (!mounted) return;
    setState(() => _yukleniyor = false);

    if (sonuc['status'] == 'success') {
      // Beni hatırla aktifse kimliği kaydet
      if (_beniHatirla) {
        await KurumsalApiService.kimlikKaydet(
          username: username,
          password: password,
        );
      } else {
        // Kullanıcı beni hatırla seçmediyse varsa eski kaydı sil
        await KurumsalApiService.kimlikSil();
      }
      _paneleGit();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sonuc['message']?.toString() ?? 'Giriş başarısız'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // ── Arka plan degrade ──────────────────────────────────────────────
          Positioned(
            top: -100, left: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFF8C00).withOpacity(0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -80, right: -40,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFF4500).withOpacity(0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── İçerik ────────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 60),

                        // Logo
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8C00).withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 44),
                          ),
                        ),

                        const SizedBox(height: 24),

                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFFF8C00), Color(0xFFFFB347)],
                          ).createShader(bounds),
                          child: const Text(
                            'Kurumsal Giriş',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        const Text(
                          'Mağaza yönetim panelinize erişin',
                          style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                        ),

                        const SizedBox(height: 36),

                        // ── Google tarzı Kayıtlı Şifre Banner'ı ─────────────
                        if (_kayitliBannerGoster && _kayitliKimlik != null)
                          _SavedCredentialBanner(
                            username: _kayitliKimlik!['username'] ?? '',
                            onUse: _kayitliKimligiKullan,
                            onFill: _alanlariDoldur,
                            onDismiss: _kimligiUnut,
                          ),

                        if (_kayitliBannerGoster && _kayitliKimlik != null)
                          const SizedBox(height: 20),

                        if (!_kayitliBannerGoster) const SizedBox(height: 12),

                        // Kullanıcı Adı
                        _DarkField(
                          controller: _userCtrl,
                          label: 'Kullanıcı Adı',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Kullanıcı adı gerekli'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Şifre
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _gizle,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          validator: (v) =>
                              (v?.length ?? 0) < 4 ? 'Şifre çok kısa' : null,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            labelStyle: const TextStyle(color: Color(0xFF888888)),
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: Color(0xFF888888)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _gizle
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF888888),
                              ),
                              onPressed: () => setState(() => _gizle = !_gizle),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A1A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFFFF8C00), width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Beni Hatırla ────────────────────────────────────
                        GestureDetector(
                          onTap: () => setState(() => _beniHatirla = !_beniHatirla),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: _beniHatirla
                                      ? const Color(0xFFFF8C00)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _beniHatirla
                                        ? const Color(0xFFFF8C00)
                                        : const Color(0xFF555555),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: _beniHatirla
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 15)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Beni Hatırla',
                                style: TextStyle(
                                    color: Color(0xFFAAAAAA), fontSize: 14),
                              ),
                              const Spacer(),
                              if (_kayitliKimlik != null && !_kayitliBannerGoster)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _kayitliBannerGoster = true),
                                  child: const Text(
                                    'Kayıtlı şifreyi göster',
                                    style: TextStyle(
                                      color: Color(0xFFFF8C00),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Giriş Butonu
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _yukleniyor ? null : _girisYap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C00),
                              disabledBackgroundColor:
                                  const Color(0xFFFF8C00).withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _yukleniyor
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Bilgi kutusu
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: const Color(0xFFFF8C00).withOpacity(0.8),
                                  size: 18),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Bu alan sadece mağaza sahipleri için tasarlanmıştır. '
                                  'Giriş bilgilerinizi yöneticinizden temin edebilirsiniz.',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Geri butonu
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google tarzı Kayıtlı Şifre Banner'ı ──────────────────────────────────────
class _SavedCredentialBanner extends StatelessWidget {
  final String username;
  final VoidCallback onUse;      // Tek tıkla giriş yap
  final VoidCallback onFill;     // Sadece alanları doldur
  final VoidCallback onDismiss;  // Kayıtlı şifreyi sil/unut

  const _SavedCredentialBanner({
    required this.username,
    required this.onUse,
    required this.onFill,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.key_rounded,
                      color: Color(0xFFFF8C00), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kayıtlı Şifre',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF555555), size: 18),
                  onPressed: onDismiss,
                  tooltip: 'Kayıtlı şifreyi sil',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF2A2A2A), height: 20),

          // Butonlar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onFill,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3A3A3A)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Doldur',
                      style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onUse,
                    icon: const Icon(Icons.login_rounded,
                        color: Colors.white, size: 16),
                    label: const Text(
                      'Giriş Yap',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Koyu Tema Metin Alanı ────────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        prefixIcon: Icon(icon, color: const Color(0xFF888888)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
