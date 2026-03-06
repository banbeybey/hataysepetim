import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kullanici_provider.dart';
import '../services/bildirim_servisi.dart';
import '../services/api_service.dart';

class GirisScreen extends StatefulWidget {
  final bool kayitModu;
  const GirisScreen({super.key, this.kayitModu = false});

  @override
  State<GirisScreen> createState() => _GirisScreenState();
}

class _GirisScreenState extends State<GirisScreen> {
  late bool _kayitModu;
  final _formKey   = GlobalKey<FormState>();
  final _adCtrl    = TextEditingController();
  final _telCtrl   = TextEditingController();
  final _sifreCtrl = TextEditingController();
  final _adresCtrl = TextEditingController();
  bool _gizle = true;
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _kayitModu = widget.kayitModu;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_kayitModu ? 'Kayıt Ol' : 'Giriş Yap')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF4500), Color(0xFFFF8C00)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(child: Text('HS', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(height: 20),
                Text(_kayitModu ? 'Hesap Oluştur' : 'Hoş Geldiniz', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(_kayitModu ? 'Kayıt olarak alışverişe başlayın' : 'Hesabınıza giriş yapın',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),

                if (_kayitModu) ...[
                  _Alan(ctrl: _adCtrl, label: 'Ad Soyad', icon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? 'Ad Soyad gerekli' : null),
                  const SizedBox(height: 14),
                ],

                _Alan(ctrl: _telCtrl, label: 'Telefon', icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Telefon gerekli' : null),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _sifreCtrl,
                  obscureText: _gizle,
                  validator: (v) => (v?.length ?? 0) < 6 ? 'En az 6 karakter' : null,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_gizle ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _gizle = !_gizle),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2)),
                  ),
                ),

                if (_kayitModu) ...[
                  const SizedBox(height: 14),
                  _Alan(ctrl: _adresCtrl, label: 'Adres (isteğe bağlı)', icon: Icons.location_on_outlined, maxLines: 2),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _yukleniyor ? null : _gonder,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                    child: _yukleniyor
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(_kayitModu ? 'Kayıt Ol' : 'Giriş Yap', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => _kayitModu = !_kayitModu),
                  child: Text(
                    _kayitModu ? 'Zaten hesabın var mı? Giriş Yap' : 'Hesabın yok mu? Kayıt Ol',
                    style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _gonder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _yukleniyor = true);

    try {
      Map<String, dynamic> sonuc;
      if (_kayitModu) {
        sonuc = await ApiService.kayitOl(_adCtrl.text.trim(), _telCtrl.text.trim(), _sifreCtrl.text, _adresCtrl.text.trim());
      } else {
        sonuc = await ApiService.girisYap(_telCtrl.text.trim(), _sifreCtrl.text);
      }

      if (!mounted) return;
      setState(() => _yukleniyor = false);

      if (sonuc['success'] == true) {
        await context.read<KullaniciProvider>().girisKaydet(sonuc['token'], sonuc['customer']);
        // Giriş sonrası OneSignal token'ını sunucuya bağla
        await BildirimServisi.tokenGonder();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sonuc['message'] ?? 'Hata oluştu'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
      ));
    }
  }
}

class _Alan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Alan({required this.ctrl, required this.label, required this.icon, this.keyboard, this.maxLines = 1, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2)),
      ),
    );
  }
}
