import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kullanici_provider.dart';
import '../services/api_service.dart';

// ─── BİLDİRİM MODELİ ────────────────────────────────────────────────────────

class Bildirim {
  final int id;
  final String mesaj;
  final String tip;
  final bool okundu;
  final DateTime olusturmaTarihi;
  final int? siparisId;

  const Bildirim({
    required this.id,
    required this.mesaj,
    required this.tip,
    required this.okundu,
    required this.olusturmaTarihi,
    this.siparisId,
  });

  factory Bildirim.fromJson(Map<String, dynamic> j) => Bildirim(
        id: j['id'] ?? 0,
        mesaj: j['mesaj'] ?? j['message'] ?? '',
        tip: j['tip'] ?? j['type'] ?? 'genel',
        okundu: (j['okundu'] ?? j['is_read'] ?? 0) == 1,
        olusturmaTarihi: j['tarih'] != null
            ? DateTime.tryParse(j['tarih'].toString()) ?? DateTime.now()
            : DateTime.now(),
        siparisId: j['siparis_id'],
      );
}

// ═══════════════════════════════════════════════════════
// ÇAN İKONU — AppBar'a ekle
// ═══════════════════════════════════════════════════════
// Kullanım:
//   AppBar(
//     actions: [BildirimCani()],
//   )
// ═══════════════════════════════════════════════════════

class BildirimCani extends StatefulWidget {
  const BildirimCani({super.key});

  @override
  State<BildirimCani> createState() => _BildirimCaniState();
}

class _BildirimCaniState extends State<BildirimCani> {
  int _sayi = 0;
  bool _ilkYuklemeYapildi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider yüklenince ve giriş yapılmışsa sayıyı çek
    // initState'te değil burada çünkü Provider o anda hazır olmayabilir
    final provider = context.read<KullaniciProvider>();
    if (provider.yuklendi && provider.girisYapildi && !_ilkYuklemeYapildi) {
      _ilkYuklemeYapildi = true;
      _sayiyiYukle();
    }
  }

  Future<void> _sayiyiYukle() async {
    try {
      final sayi = await ApiService.bildirimSayisiGetir();
      if (mounted) setState(() => _sayi = sayi);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Provider değişince (yuklendi → true olunca) build tetiklensin
    final provider = context.watch<KullaniciProvider>();

    // Provider yeni yüklendiyse ve henüz istek atmadıysak çek
    if (provider.yuklendi && provider.girisYapildi && !_ilkYuklemeYapildi) {
      _ilkYuklemeYapildi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sayiyiYukle());
    }

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, size: 26),
          if (_sayi > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  _sayi > 99 ? '99+' : '$_sayi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: () async {
        setState(() => _sayi = 0);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BildirimlerScreen()),
        );
        _sayiyiYukle();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// BİLDİRİMLER SAYFASI
// ═══════════════════════════════════════════════════════

class BildirimlerScreen extends StatefulWidget {
  const BildirimlerScreen({super.key});

  @override
  State<BildirimlerScreen> createState() => _BildirimlerScreenState();
}

class _BildirimlerScreenState extends State<BildirimlerScreen> {
  List<Bildirim> _bildirimler = [];
  bool _yukleniyor = false;
  bool _dahaFazla = true;
  int _sayfa = 1;
  bool _ilkYuklemeYapildi = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_sonsuzKaydir);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider yüklenince bildirimleri çek — initState'te değil!
    // Çünkü initState sırasında SharedPreferences henüz okunmamış olabilir.
    final provider = context.read<KullaniciProvider>();
    if (provider.yuklendi && provider.girisYapildi && !_ilkYuklemeYapildi) {
      _ilkYuklemeYapildi = true;
      _yukle();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle({bool yenile = false}) async {
    if (yenile) {
      _sayfa = 1;
      _dahaFazla = true;
    }
    if (mounted) setState(() => _yukleniyor = true);
    try {
      final ham = await ApiService.bildirimleriGetir(sayfa: _sayfa);
      final yeni = ham
          .map((e) => Bildirim.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          if (yenile) _bildirimler = yeni;
          else _bildirimler.addAll(yeni);
          _dahaFazla = yeni.length == 20;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _sonsuzKaydir() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_yukleniyor &&
        _dahaFazla) {
      _sayfa++;
      _yukle();
    }
  }

  String _zamanFarki(DateTime tarih) {
    final fark = DateTime.now().difference(tarih);
    if (fark.inMinutes < 1) return 'Az önce';
    if (fark.inHours < 1) return '${fark.inMinutes} dk önce';
    if (fark.inDays < 1) return '${fark.inHours} sa önce';
    if (fark.inDays < 7) return '${fark.inDays} gün önce';
    return '${tarih.day}.${tarih.month}.${tarih.year}';
  }

  Widget _bildirimIkon(Bildirim b) {
    final IconData ikon;
    final Color renk;

    if (b.mesaj.contains('hazırlanıyor') || b.mesaj.contains('Hazırlanıyor')) {
      ikon = Icons.restaurant_rounded;
      renk = const Color(0xFFFF8C00);
    } else if (b.mesaj.contains('yola çıktı') || b.mesaj.contains('Yola çıktı')) {
      ikon = Icons.delivery_dining_rounded;
      renk = const Color(0xFF007AFF);
    } else if (b.mesaj.contains('teslim') || b.mesaj.contains('Teslim')) {
      ikon = Icons.check_circle_rounded;
      renk = const Color(0xFF34C759);
    } else if (b.mesaj.contains('iptal') || b.mesaj.contains('İptal')) {
      ikon = Icons.cancel_rounded;
      renk = const Color(0xFFFF3B30);
    } else if (b.mesaj.contains('alındı') || b.mesaj.contains('Alındı')) {
      ikon = Icons.shopping_bag_rounded;
      renk = const Color(0xFF5856D6);
    } else {
      ikon = Icons.notifications_rounded;
      renk = const Color(0xFF8E8E93);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: renk.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(ikon, color: renk, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KullaniciProvider>();

    // Provider yeni yüklendiyse ve henüz istek atmadıysak çek
    // (didChangeDependencies'i kaçırdığımız edge-case için güvence)
    if (provider.yuklendi && provider.girisYapildi && !_ilkYuklemeYapildi) {
      _ilkYuklemeYapildi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _yukle());
    }

    final ad = provider.kullanici?['full_name'] ?? '';

    // Provider henüz SharedPreferences'ı okumadıysa bekle
    if (!provider.yuklendi) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F7),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
        ),
      );
    }

    // Giriş yapılmamışsa bilgi ver
    if (!provider.girisYapildi) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Bildirimler',
            style: TextStyle(
              color: Color(0xFF1D1D1F),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFF1D1D1F), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Bildirimleri görmek için\ngiriş yapmanız gerekiyor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bildirimler',
          style: TextStyle(
            color: Color(0xFF1D1D1F),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1D1D1F), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF8C00),
        onRefresh: () => _yukle(yenile: true),
        child: _bildirimler.isEmpty && !_yukleniyor
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.notifications_off_outlined,
                          size: 40, color: Color(0xFFD1D1D6)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Henüz bildirim yok',
                        style: TextStyle(
                            color: Color(0xFF1D1D1F),
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      ad.isNotEmpty
                          ? '$ad, sipariş verdiğinizde\nburada bildirim alacaksınız.'
                          : 'Sipariş verdiğinizde\nburada bildirim alacaksınız.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF8E8E93), fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _bildirimler.length + (_yukleniyor ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 16,
                  color: Color(0xFFE5E5EA),
                ),
                itemBuilder: (ctx, i) {
                  if (i == _bildirimler.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF8C00),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  final b = _bildirimler[i];
                  return Material(
                    color: b.okundu
                        ? Colors.white
                        : const Color(0xFFFFF8F0),
                    child: InkWell(
                      onTap: b.siparisId != null ? () {} : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bildirimIkon(b),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.mesaj,
                                    style: TextStyle(
                                      color: const Color(0xFF1D1D1F),
                                      fontSize: 14,
                                      fontWeight: b.okundu
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _zamanFarki(b.olusturmaTarihi),
                                    style: const TextStyle(
                                      color: Color(0xFF8E8E93),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!b.okundu)
                              Container(
                                width: 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.only(top: 4, left: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF8C00),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
