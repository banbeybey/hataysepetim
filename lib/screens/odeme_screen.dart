import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/sepet_provider.dart';
import '../providers/kullanici_provider.dart';
import '../services/api_service.dart';

class OdemeScreen extends StatefulWidget {
  const OdemeScreen({super.key});

  @override
  State<OdemeScreen> createState() => _OdemeScreenState();
}

class _OdemeScreenState extends State<OdemeScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _adCtrl      = TextEditingController();
  final _telefonCtrl = TextEditingController();
  final _adresCtrl   = TextEditingController();
  final _notCtrl     = TextEditingController();

  String _odemeYontemi = 'cod';
  String _teslimatTipi = 'standard';
  bool   _gonderiyor   = false;

  bool _bilgilerYuklendi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bilgilerYuklendi) {
      final kullanici = context.read<KullaniciProvider>().kullanici;
      if (kullanici != null) {
        _adCtrl.text      = kullanici['full_name'] ?? '';
        _telefonCtrl.text = kullanici['phone'] ?? '';
        _adresCtrl.text   = kullanici['address'] ?? '';
      }
      _bilgilerYuklendi = true;
    }
  }

  double get _kargo => _teslimatTipi == 'standard' ? 60.0 : 120.0;

  @override
  Widget build(BuildContext context) {
    final sepet       = context.watch<SepetProvider>();
    final genelToplam = sepet.araToplam + _kargo;

    return Scaffold(
      appBar: AppBar(title: const Text('Siparişi Tamamla')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Baslik('Teslimat Bilgileri'),
            const SizedBox(height: 12),
            _Alan(ctrl: _adCtrl, label: 'Ad Soyad', icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'Ad Soyad gerekli' : null),
            const SizedBox(height: 12),
            _Alan(ctrl: _telefonCtrl, label: 'Telefon', icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Telefon gerekli' : null),
            const SizedBox(height: 12),
            _Alan(ctrl: _adresCtrl, label: 'Adres', icon: Icons.location_on_outlined,
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Adres gerekli' : null),
            const SizedBox(height: 12),
            // NOT ALANI
            _Alan(ctrl: _notCtrl, label: 'Sipariş Notu (isteğe bağlı)',
                icon: Icons.note_outlined, maxLines: 2),

            const SizedBox(height: 24),
            _Baslik('Teslimat Seçeneği'),
            const SizedBox(height: 12),
            _TeslimatSecenegi(
                secili: _teslimatTipi == 'standard',
                baslik: 'Standart Teslimat',
                aciklama: 'Aynı gün teslimat',
                fiyat: 60,
                onTap: () => setState(() => _teslimatTipi = 'standard')),
            const SizedBox(height: 8),
            _TeslimatSecenegi(
                secili: _teslimatTipi == 'returnable',
                baslik: 'İadeli Teslimat',
                aciklama: 'Aynı gün iade hakkı',
                fiyat: 120,
                onTap: () => setState(() => _teslimatTipi = 'returnable')),

            const SizedBox(height: 24),
            _Baslik('Ödeme Yöntemi'),
            const SizedBox(height: 12),
            _OdemeSecenegi(
                secili: _odemeYontemi == 'cod',
                icon: '💵',
                baslik: 'Kapıda Ödeme',
                aciklama: 'Nakit veya kart',
                onTap: () => setState(() => _odemeYontemi = 'cod')),
            const SizedBox(height: 8),
            _OdemeSecenegi(
                secili: _odemeYontemi == 'bank_transfer',
                icon: '🏦',
                baslik: 'Havale / EFT',
                aciklama: 'Ziraat Bankası — Mert Şanverdi',
                onTap: () => setState(() => _odemeYontemi = 'bank_transfer')),

            // HAVALE SEÇİLİNCE IBAN BİLGİSİ GÖSTER
            if (_odemeYontemi == 'bank_transfer') ...[
              const SizedBox(height: 12),
              _IbanKarti(),
            ],

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _SatirOzet('Ara Toplam', sepet.araToplam),
                  const SizedBox(height: 6),
                  _SatirOzet('Kargo', _kargo),
                  const Divider(height: 20),
                  _SatirOzet('Genel Toplam', genelToplam, kalin: true),
                ],
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _gonderiyor ? null : _siparisVer,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54)),
              child: _gonderiyor
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Siparişi Ver • ${genelToplam.toStringAsFixed(0)} ₺',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _siparisVer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _gonderiyor = true);

    final sepet   = context.read<SepetProvider>();
    final urunler = sepet.urunler.map<Map<String, dynamic>>((u) => {
      'urun_id': u.urunId,
      'adet':    u.adet,
      'beden':   u.beden,
    }).toList();

    try {
      final sonuc = await ApiService.siparisDe(
        storeId:         sepet.aktifStoreId!,
        customerName:    _adCtrl.text.trim(),
        customerPhone:   _telefonCtrl.text.trim(),
        customerAddress: _adresCtrl.text.trim(),
        paymentMethod:   _odemeYontemi,
        deliveryType:    _teslimatTipi,
        siparisnotu:     _notCtrl.text.trim(),
        urunler:         urunler,
      );

      if (!mounted) return;
      setState(() => _gonderiyor = false);

      if (sonuc['success'] == true) {
        final orderId = sonuc['order_id'];
        sepet.temizle();
        if (!mounted) return;

        Navigator.of(context).pop(); // Ödeme ekranını kapat
        Navigator.of(context).pop(); // Sepet ekranını kapat

        if (_odemeYontemi == 'bank_transfer') {
          // Havale ekranını göster
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _HavaleEkrani(orderId: orderId),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('🎉 Siparişiniz alındı! Sipariş No: #$orderId'),
            backgroundColor: const Color(0xFF2BDC6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sonuc['message']?.toString() ?? 'Hata oluştu'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiyor = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bağlantı hatası. Lütfen tekrar deneyin.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ─── IBAN KARTI ─────────────────────────────────────────────────────────────

class _IbanKarti extends StatelessWidget {
  static const String _iban = 'TR13 0001 0003 3097 4137 6550 17';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e3a8a), Color(0xFF1d4ed8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, color: Colors.white70, size: 14),
              SizedBox(width: 6),
              Text('ZİRAAT BANKASI',
                  style: TextStyle(color: Colors.white70, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.person, color: Colors.white70, size: 14),
              SizedBox(width: 6),
              Text('Alıcı: Mert Şanverdi',
                  style: TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(_iban,
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(
                  text: 'TR13000100033097413765501 7'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ IBAN kopyalandı'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white38),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('IBAN\'ı Kopyala',
                      style: TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HAVALE EKRANI (BottomSheet) ─────────────────────────────────────────────

class _HavaleEkrani extends StatefulWidget {
  final dynamic orderId;
  const _HavaleEkrani({required this.orderId});

  @override
  State<_HavaleEkrani> createState() => _HavaleEkraniState();
}

class _HavaleEkraniState extends State<_HavaleEkrani> {
  File? _dekont;
  bool _yukleniyor = false;
  bool _tamamlandi = false;

  Future<void> _dekontSec() async {
    // Seçim yöntemi sor
    final secim = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Dekont Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFFFF8C00).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFFFF8C00)),
              ),
              title: const Text('Galeriden Fotoğraf', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('JPG, PNG'),
              onTap: () => Navigator.pop(context, 'galeri'),
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF1d4ed8).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF1d4ed8)),
              ),
              title: const Text('Dosyadan Seç', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('PDF, JPG, PNG, WEBP'),
              onTap: () => Navigator.pop(context, 'dosya'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (secim == null) return;

    if (secim == 'galeri') {
      final picker = ImagePicker();
      final secilen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (secilen != null) setState(() => _dekont = File(secilen.path));
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _dekont = File(result.files.single.path!));
      }
    }
  }

Future<void> _dekontGonder() async {
  if (_dekont == null) return;
  setState(() => _yukleniyor = true);

  try {
    final sonuc = await ApiService.dekontYukle(
      orderId: widget.orderId,
      dosya: _dekont!,
    );
    if (sonuc['success'] == true) {
      setState(() => _tamamlandi = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sonuc['message'] ?? 'Hata oluştu'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hata: $e'), behavior: SnackBarBehavior.floating),
    );
  }
  setState(() => _yukleniyor = false);
}

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Tutma çubuğu
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: _tamamlandi ? _tamamlandiEkrani() : _havaleIcerigi(),
          ),
        ],
      ),
    );
  }

  Widget _tamamlandiEkrani() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF16a34a), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          const Text('Dekontunuz İletildi!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text(
            'Siparişiniz alındı ve ödeme dekontunuz başarıyla gönderildi. Ekibimiz en kısa sürede inceleyecektir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _havaleIcerigi() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const Text('Havale / EFT ile Ödeme',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Sipariş #${widget.orderId}',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 20),

        // IBAN kartı
        _IbanKarti(),
        const SizedBox(height: 16),

        // Bilgi kutusu
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFeff6ff),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFbfdbfe)),
          ),
          child: Column(
            children: [
              _BilgiSatiri(Icons.info_outline,
                  'Havale açıklamasına sipariş numaranızı (#${widget.orderId}) yazmanız işlemi hızlandırır.'),
              const SizedBox(height: 8),
              const _BilgiSatiri(Icons.access_time,
                  'Ödemenizin onaylanması genellikle 1-2 iş saati içinde gerçekleşir.'),
              const SizedBox(height: 8),
              const _BilgiSatiri(Icons.phone_outlined,
                  'Ödemeniz onaylandıktan sonra sizinle iletişime geçilecektir.'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Dekont yükleme
        const Text('Dekont Yükle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Ödeme yaptıktan sonra dekontu seçip gönderin.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: _dekontSec,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: _dekont != null
                  ? const Color(0xFFf0fdf4)
                  : const Color(0xFFF8F8F8),
              border: Border.all(
                color: _dekont != null
                    ? const Color(0xFF16a34a)
                    : Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _dekont != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_dekont!, fit: BoxFit.cover),
                        Container(color: Colors.black26),
                        const Center(
                          child: Text('Değiştir',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Dekont Seçin',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('JPG, PNG veya PDF — Maks. 5MB',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: (_dekont == null || _yukleniyor) ? null : _dekontGonder,
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52)),
          child: _yukleniyor
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Gönderdim',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Şimdi yüklemeyeyim, sonra göndereceğim',
              style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _BilgiSatiri extends StatelessWidget {
  final IconData icon;
  final String metin;
  const _BilgiSatiri(this.icon, this.metin);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF1d4ed8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(metin,
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.5)),
        ),
      ],
    );
  }
}

// ─── YARDIMCI WİDGET'LAR ────────────────────────────────────────────────────

class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);
  @override
  Widget build(BuildContext context) =>
      Text(metin, style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1D1D1F)));
}

class _Alan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;
  const _Alan({required this.ctrl, required this.label, required this.icon,
      this.keyboard, this.maxLines = 1, this.validator});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl, keyboardType: keyboard,
      maxLines: maxLines, validator: validator,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon),
        filled: true, fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2)),
      ),
    );
  }
}

class _TeslimatSecenegi extends StatelessWidget {
  final bool secili;
  final String baslik, aciklama;
  final int fiyat;
  final VoidCallback onTap;
  const _TeslimatSecenegi({required this.secili, required this.baslik,
      required this.aciklama, required this.fiyat, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: secili ? const Color(0xFFFF8C00).withOpacity(0.08) : Colors.white,
          border: Border.all(
              color: secili ? const Color(0xFFFF8C00) : const Color(0xFFE0E0E0),
              width: secili ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(secili ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: secili ? const Color(0xFFFF8C00) : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(aciklama, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Text('$fiyat ₺', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      ),
    );
  }
}

class _OdemeSecenegi extends StatelessWidget {
  final bool secili;
  final String icon, baslik, aciklama;
  final VoidCallback onTap;
  const _OdemeSecenegi({required this.secili, required this.icon,
      required this.baslik, required this.aciklama, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: secili ? const Color(0xFFFF8C00).withOpacity(0.08) : Colors.white,
          border: Border.all(
              color: secili ? const Color(0xFFFF8C00) : const Color(0xFFE0E0E0),
              width: secili ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(secili ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: secili ? const Color(0xFFFF8C00) : Colors.grey),
          const SizedBox(width: 12),
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(aciklama, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
        ]),
      ),
    );
  }
}

class _SatirOzet extends StatelessWidget {
  final String baslik;
  final double fiyat;
  final bool kalin;
  const _SatirOzet(this.baslik, this.fiyat, {this.kalin = false});
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: kalin ? 16 : 14,
        fontWeight: kalin ? FontWeight.w800 : FontWeight.w500);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(baslik, style: style.copyWith(
            color: kalin ? const Color(0xFF1D1D1F) : Colors.grey)),
        Text('${fiyat.toStringAsFixed(0)} ₺', style: style.copyWith(
            color: kalin ? const Color(0xFFFF8C00) : Colors.grey)),
      ],
    );
  }
}
