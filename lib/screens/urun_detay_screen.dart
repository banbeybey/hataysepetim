import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../providers/sepet_provider.dart';
import '../providers/kullanici_provider.dart';
import 'giris_screen.dart';

class UrunDetayScreen extends StatefulWidget {
  final int urunId;
  final int storeId;
  final String storeName;
  final String storeSlug;
  final Color renk;

  const UrunDetayScreen({
    super.key,
    required this.urunId,
    required this.storeId,
    required this.storeName,
    required this.storeSlug,
    required this.renk,
  });

  @override
  State<UrunDetayScreen> createState() => _UrunDetayScreenState();
}

class _UrunDetayScreenState extends State<UrunDetayScreen> {
  Map<String, dynamic>? _urun;
  List<dynamic> _ilgiliUrunler = [];
  bool _yukleniyor = true;
  String? _secilenBeden;
  int _aktifResim = 0;
  VideoPlayerController? _videoCtrl;
  bool _videoOynuyor = false;
  OverlayEntry? _uyariOverlay;

  // Ana ekran flip durumları (max 3 resim)
  final List<bool> _yatayCevrik = [false, false, false];
  final List<bool> _dikeyCevrik = [false, false, false];
  // Döndürme: 0, 1, 2, 3 → 0°, 90°, 180°, 270°
  final List<int> _donme = [0, 0, 0];

  int _toInt(dynamic val) => int.tryParse(val?.toString() ?? '0') ?? 0;
  double _toDouble(dynamic val) => double.tryParse(val?.toString() ?? '0') ?? 0.0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _uyariOverlay?.remove();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final data = await ApiService.getUrunDetay(widget.urunId);

    List<dynamic> ilgili = [];
    try {
      ilgili = await ApiService.getUrunler(widget.storeSlug);
      ilgili = ilgili.where((u) => _toInt(u['id']) != widget.urunId).take(4).toList();
    } catch (_) {}

    if (data != null && data['video_url'] != null) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(data['video_url']))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }

    setState(() {
      _urun = data;
      _ilgiliUrunler = ilgili;
      _yukleniyor = false;
    });
  }

  List<String> get _resimler {
    final list = <String>[];
    if (_urun?['image_url'] != null)  list.add(_urun!['image_url']);
    if (_urun?['image2_url'] != null) list.add(_urun!['image2_url']);
    if (_urun?['image3_url'] != null) list.add(_urun!['image3_url']);
    return list;
  }

  bool get _videoVar => _videoCtrl != null && _videoCtrl!.value.isInitialized;

  void _tamEkranAc(int baslangicIndex) {
    if (_videoVar && _aktifResim == _resimler.length) {
      _videoCtrl?.pause();
      setState(() => _videoOynuyor = false);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TamEkranGaleri(
          resimler: _resimler,
          videoCtrl: _videoVar ? _videoCtrl : null,
          baslangicIndex: baslangicIndex,
          renk: widget.renk,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00))));
    if (_urun == null) return const Scaffold(body: Center(child: Text('Ürün bulunamadı')));

    final hasSiz   = _toInt(_urun!['has_size']) == 1;
    final bedenler = (_urun!['beden_listesi'] as List? ?? []);
    final stok     = _toInt(_urun!['stock']);
    final tukendi  = stok <= 0;
    final indirim  = _toInt(_urun!['discount_percent']);
    final fiyat    = _toDouble(_urun!['price']);
    final eskiFiyat = _urun!['old_price'] != null ? _toDouble(_urun!['old_price']) : null;
    final aciklama  = _urun!['description']?.toString();
    final toplamMedya = _resimler.length + (_videoVar ? 1 : 0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── GÖRSEL/VİDEO GALERİSİ ─────────────────────────────
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Color(0xFF1D1D1F)),
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () => _tamEkranAc(_aktifResim),
                child: Stack(
                  children: [
                    // PageView
                    PageView.builder(
                      itemCount: toplamMedya,
                      onPageChanged: (i) {
                        if (_videoOynuyor) {
                          _videoCtrl?.pause();
                          setState(() => _videoOynuyor = false);
                        }
                        setState(() => _aktifResim = i);
                      },
                      itemBuilder: (_, i) {
                        // Video sayfası
                        if (_videoVar && i == _resimler.length) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _videoOynuyor = !_videoOynuyor;
                                _videoOynuyor ? _videoCtrl!.play() : _videoCtrl!.pause();
                              });
                            },
                            child: Container(
                              color: Colors.black,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: VideoPlayer(_videoCtrl!)),
                                  if (!_videoOynuyor)
                                    Container(
                                      width: 64, height: 64,
                                      decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }
                        // Resim sayfası — tam ekran için tıklanabilir
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateZ(_donme[i] * 3.14159265 / 2)
                            ..scale(
                              _yatayCevrik[i] ? -1.0 : 1.0,
                              _dikeyCevrik[i] ? -1.0 : 1.0,
                            ),
                          child: CachedNetworkImage(
                            imageUrl: _resimler[i],
                            fit: BoxFit.contain,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (_, __) => Container(color: const Color(0xFFF2F2F7),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8C00)))),
                            errorWidget: (_, __, ___) => Container(color: const Color(0xFFF2F2F7),
                                child: const Icon(Icons.image_outlined, color: Colors.grey, size: 60)),
                          ),
                        );
                      },
                    ),

                    // Tam ekran ikonu + Flip butonları — sağ alt
                    if (!(_videoVar && _aktifResim == _resimler.length))
                      Positioned(
                        bottom: 30, right: 16,
                        child: GestureDetector(
                          onTap: () {}, // tıklamanın arkaya geçmesini engelle
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Döndür (saat yönü)
                              GestureDetector(
                                onTap: () => setState(() => _donme[_aktifResim] = (_donme[_aktifResim] + 1) % 4),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _donme[_aktifResim] != 0 ? widget.renk : Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.rotate_right, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Yatay çevir
                              GestureDetector(
                                onTap: () => setState(() => _yatayCevrik[_aktifResim] = !_yatayCevrik[_aktifResim]),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _yatayCevrik[_aktifResim] ? widget.renk : Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.flip, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Dikey çevir
                              GestureDetector(
                                onTap: () => setState(() => _dikeyCevrik[_aktifResim] = !_dikeyCevrik[_aktifResim]),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _dikeyCevrik[_aktifResim] ? widget.renk : Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.swap_vert, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Tam ekran
                              GestureDetector(
                                onTap: () => _tamEkranAc(_aktifResim),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Video sayfasında sadece tam ekran
                      Positioned(
                        bottom: 30, right: 16,
                        child: GestureDetector(
                          onTap: () => _tamEkranAc(_aktifResim),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                          ),
                        ),
                      ),

                    // Nokta indikatörü
                    if (toplamMedya > 1)
                      Positioned(
                        bottom: 16, left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(toplamMedya, (i) {
                            final isVideo = _videoVar && i == _resimler.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _aktifResim == i ? 20 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: _aktifResim == i
                                    ? (isVideo ? Colors.red : widget.renk)
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),

                    // İndirim etiketi
                    if (indirim > 0)
                      Positioned(
                        top: 60, right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF00C8)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('%$indirim İndirim',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ),

                    // Video badge
                    if (_videoVar && _aktifResim < _resimler.length)
                      Positioned(
                        bottom: 40, right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_filled, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Video', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── ÜRÜN BİLGİLERİ ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.storeName,
                      style: TextStyle(color: widget.renk, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(_urun!['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1D1D1F))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${_fmt(fiyat)} ₺',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: widget.renk)),
                      if (eskiFiyat != null && eskiFiyat > 0) ...[
                        const SizedBox(width: 12),
                        Text('${_fmt(eskiFiyat)} ₺',
                            style: const TextStyle(fontSize: 16, color: Colors.grey,
                                decoration: TextDecoration.lineThrough)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tukendi ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tukendi ? '● Stokta Yok' : '● Son $stok adet',
                      style: TextStyle(
                          color: tukendi ? Colors.red : const Color(0xFF2BDC6B),
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Beden seçimi
                  if (hasSiz && bedenler.isNotEmpty) ...[
                    const Text('Beden Seçin',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: bedenler.map((b) {
                        final bStok  = _toInt(b['stok']);
                        final stoklu = bStok > 0;
                        final secili = _secilenBeden == b['beden']?.toString();
                        return GestureDetector(
                          onTap: stoklu ? () => setState(() => _secilenBeden = b['beden']?.toString()) : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: secili ? widget.renk : (stoklu ? Colors.white : const Color(0xFFF5F5F5)),
                              border: Border.all(
                                color: secili ? widget.renk : (stoklu ? const Color(0xFFE0E0E0) : Colors.transparent),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(b['beden']?.toString() ?? '',
                              style: TextStyle(
                                color: secili ? Colors.white : (stoklu ? const Color(0xFF1D1D1F) : Colors.grey),
                                fontWeight: FontWeight.w700,
                                decoration: !stoklu ? TextDecoration.lineThrough : null,
                              )),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Açıklama
                  if (aciklama != null && aciklama.isNotEmpty) ...[
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Icon(Icons.info_outline_rounded, color: widget.renk, size: 20),
                      const SizedBox(width: 8),
                      const Text('Ürün Açıklaması',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1D1D1F))),
                    ]),
                    const SizedBox(height: 12),
                    _AciklamaKutusu(aciklama: aciklama, renk: widget.renk),
                    const SizedBox(height: 24),
                  ],

                  // Özellik kartları
                  _ozellikSatiri('🚀', 'Hızlı Teslimat', 'Aynı gün kargo', '🔒', 'Güvenli Alışveriş', 'SSL korumalı'),
                  const SizedBox(height: 10),
                  _ozellikSatiri('↩️', 'Kolay İade', 'Aynı gün iade', '💳', 'Kapıda Ödeme', 'Nakit veya kart'),
                  const SizedBox(height: 32),

                  // İlgili ürünler
                  if (_ilgiliUrunler.isNotEmpty) ...[
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Icon(Icons.star_rounded, color: widget.renk, size: 20),
                      const SizedBox(width: 8),
                      const Text('Bu Mağazadan Öneriler',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1D1D1F))),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _ilgiliUrunler.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _IlgiliUrunKart(
                          urun: _ilgiliUrunler[i],
                          renk: widget.renk,
                          storeId: widget.storeId,
                          storeName: widget.storeName,
                          storeSlug: widget.storeSlug,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: (tukendi || (hasSiz && _secilenBeden == null)) ? null : _sepeteEkle,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.renk,
              disabledBackgroundColor: Colors.grey.shade200,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              tukendi ? 'Tükendi' : (hasSiz && _secilenBeden == null) ? 'Beden Seçin' : 'Sepete Ekle',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ozellikSatiri(String i1, String b1, String a1, String i2, String b2, String a2) =>
      Row(children: [
        Expanded(child: _ozellikKart(i1, b1, a1)),
        const SizedBox(width: 10),
        Expanded(child: _ozellikKart(i2, b2, a2)),
      ]);

  Widget _ozellikKart(String icon, String baslik, String aciklama) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(baslik, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(aciklama, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    );
  }

  void _girisUyarisiGoster() {
    _uyariOverlay?.remove();
    _uyariOverlay = OverlayEntry(
      builder: (_) => _GirisUyariBanner(
        onGirisYap: () {
          _uyariOverlay?.remove();
          _uyariOverlay = null;
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GirisScreen()));
        },
        onKapat: () {
          _uyariOverlay?.remove();
          _uyariOverlay = null;
        },
      ),
    );
    Overlay.of(context).insert(_uyariOverlay!);
    Future.delayed(const Duration(seconds: 4), () {
      _uyariOverlay?.remove();
      _uyariOverlay = null;
    });
  }

  void _sepeteEkle() {
    final kullanici = context.read<KullaniciProvider>();
    if (!kullanici.girisYapildi) {
      _girisUyarisiGoster();
      return;
    }
    final sepet = context.read<SepetProvider>();
    final fiyat = _toDouble(_urun!['price']);
    if (sepet.farkliMagaza(widget.storeId)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sepeti Temizle'),
          content: const Text('Farklı bir mağazadan ürün eklemek için sepetinizi temizlemeniz gerekiyor.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            TextButton(
              onPressed: () { sepet.temizle(); Navigator.pop(context); _ekle(sepet, fiyat); },
              child: const Text('Temizle ve Ekle', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }
    _ekle(sepet, fiyat);
  }

  void _ekle(SepetProvider sepet, double fiyat) {
    sepet.ekle(SepetUrun(
      urunId: widget.urunId,
      storeId: widget.storeId,
      storeName: widget.storeName,
      storeSlug: widget.storeSlug,
      urunAdi: _urun!['name']?.toString() ?? '',
      fiyat: fiyat,
      imageUrl: _urun!['image_url']?.toString(),
      beden: _secilenBeden,
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_urun!['name']} sepete eklendi ✓'),
      backgroundColor: const Color(0xFF2BDC6B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmt(double f) => f.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

// ══════════════════════════════════════════════════════
// TAM EKRAN GALERİ — Zoom + Swipe + Video
// ══════════════════════════════════════════════════════
class _TamEkranGaleri extends StatefulWidget {
  final List<String> resimler;
  final VideoPlayerController? videoCtrl;
  final int baslangicIndex;
  final Color renk;

  const _TamEkranGaleri({
    required this.resimler,
    required this.videoCtrl,
    required this.baslangicIndex,
    required this.renk,
  });

  @override
  State<_TamEkranGaleri> createState() => _TamEkranGaleriState();
}

class _TamEkranGaleriState extends State<_TamEkranGaleri> {
  late PageController _pageCtrl;
  late int _aktif;
  bool _videoOynuyor = false;

  // Flip durumları — her resim için ayrı tutuluyor
  late List<bool> _yatayCevrik;
  late List<bool> _dikeyCevrik;
  // Döndürme: 0,1,2,3 → 0°,90°,180°,270°
  late List<int> _donme;

  bool get _videoVar => widget.videoCtrl != null && widget.videoCtrl!.value.isInitialized;
  int get _toplamSayfa => widget.resimler.length + (_videoVar ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _aktif = widget.baslangicIndex;
    _pageCtrl = PageController(initialPage: _aktif);
    _yatayCevrik = List.filled(widget.resimler.length, false);
    _dikeyCevrik = List.filled(widget.resimler.length, false);
    _donme       = List.filled(widget.resimler.length, 0);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    widget.videoCtrl?.pause();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _toplamSayfa,
            onPageChanged: (i) {
              if (_videoOynuyor) {
                widget.videoCtrl?.pause();
                setState(() => _videoOynuyor = false);
              }
              setState(() => _aktif = i);
            },
            itemBuilder: (_, i) {
              // Video sayfası
              if (_videoVar && i == widget.resimler.length) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _videoOynuyor = !_videoOynuyor;
                      _videoOynuyor ? widget.videoCtrl!.play() : widget.videoCtrl!.pause();
                    });
                  },
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: widget.videoCtrl!.value.aspectRatio,
                          child: VideoPlayer(widget.videoCtrl!),
                        ),
                        if (!_videoOynuyor)
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                          ),
                      ],
                    ),
                  ),
                );
              }

              // Resim sayfası — InteractiveViewer ile zoom
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateZ(_donme[i] * 3.14159265 / 2)
                      ..scale(
                        _yatayCevrik[i] ? -1.0 : 1.0,
                        _dikeyCevrik[i] ? -1.0 : 1.0,
                      ),
                    child: CachedNetworkImage(
                      imageUrl: widget.resimler[i],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8C00)),
                      ),
                      errorWidget: (_, __, ___) => const Icon(Icons.image_outlined, color: Colors.grey, size: 60),
                    ),
                  ),
                ),
              );
            },
          ),

          // Geri butonu
          Positioned(
            top: 50, left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Sayaç
          Positioned(
            top: 55, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_aktif + 1} / $_toplamSayfa',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Alt nokta indikatörü
          if (_toplamSayfa > 1)
            Positioned(
              bottom: 30, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_toplamSayfa, (i) {
                  final isVideo = _videoVar && i == widget.resimler.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _aktif == i ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _aktif == i
                          ? (isVideo ? Colors.red : widget.renk)
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

          // Flip butonları — sadece resim sayfalarında göster
          if (!(_videoVar && _aktif == widget.resimler.length))
            Positioned(
              bottom: 52, right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FlipButon(
                    icon: Icons.rotate_right,
                    tooltip: 'Döndür',
                    onTap: () => setState(() => _donme[_aktif] = (_donme[_aktif] + 1) % 4),
                    aktif: _donme[_aktif] != 0,
                    renk: widget.renk,
                  ),
                  const SizedBox(height: 8),
                  _FlipButon(
                    icon: Icons.flip,
                    tooltip: 'Yatay Çevir',
                    onTap: () => setState(() => _yatayCevrik[_aktif] = !_yatayCevrik[_aktif]),
                    aktif: _yatayCevrik[_aktif],
                    renk: widget.renk,
                  ),
                  const SizedBox(height: 8),
                  _FlipButon(
                    icon: Icons.swap_vert,
                    tooltip: 'Dikey Çevir',
                    onTap: () => setState(() => _dikeyCevrik[_aktif] = !_dikeyCevrik[_aktif]),
                    aktif: _dikeyCevrik[_aktif],
                    renk: widget.renk,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// İLGİLİ ÜRÜN KARTI
// ══════════════════════════════════════════════════════
class _IlgiliUrunKart extends StatelessWidget {
  final Map<String, dynamic> urun;
  final Color renk;
  final int storeId;
  final String storeName;
  final String storeSlug;

  const _IlgiliUrunKart({
    required this.urun, required this.renk,
    required this.storeId, required this.storeName, required this.storeSlug,
  });

  int _toInt(dynamic val) => int.tryParse(val?.toString() ?? '0') ?? 0;
  double _toDouble(dynamic val) => double.tryParse(val?.toString() ?? '0') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final urunId = _toInt(urun['id']);
    final fiyat  = _toDouble(urun['price']);
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UrunDetayScreen(
          urunId: urunId, storeId: storeId,
          storeName: storeName, storeSlug: storeSlug, renk: renk,
        )),
      ),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: urun['image_url'] != null
                  ? CachedNetworkImage(imageUrl: urun['image_url'], width: 130, height: 120, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(height: 120, color: const Color(0xFFF2F2F7)),
                      errorWidget: (_, __, ___) => Container(height: 120, color: const Color(0xFFF2F2F7),
                          child: const Icon(Icons.image_outlined, color: Colors.grey)))
                  : Container(height: 120, color: const Color(0xFFF2F2F7)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(urun['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F))),
                const SizedBox(height: 4),
                Text('${fiyat.toStringAsFixed(0)} ₺',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: renk)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// FLIP BUTONU
// ══════════════════════════════════════════════════════
class _FlipButon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool aktif;
  final Color renk;

  const _FlipButon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.aktif,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: aktif ? renk : Colors.black54,
            borderRadius: BorderRadius.circular(12),
            border: aktif ? Border.all(color: Colors.white38, width: 1.5) : null,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// AÇIKLAMA KUTUSU
// ══════════════════════════════════════════════════════
class _AciklamaKutusu extends StatefulWidget {
  final String aciklama;
  final Color renk;
  const _AciklamaKutusu({required this.aciklama, required this.renk});
  @override
  State<_AciklamaKutusu> createState() => _AciklamaKutusuState();
}

class _AciklamaKutusuState extends State<_AciklamaKutusu> {
  bool _genisletildi = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.aciklama,
            style: const TextStyle(fontSize: 14, color: Color(0xFF444444), height: 1.6),
            maxLines: _genisletildi ? null : 4,
            overflow: _genisletildi ? TextOverflow.visible : TextOverflow.ellipsis),
        if (widget.aciklama.length > 150) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _genisletildi = !_genisletildi),
            child: Text(_genisletildi ? 'Daha Az Göster' : 'Devamını Gör',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.renk)),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════
// GİRİŞ UYARI BANNER — Üstten kayan kırmızı uyarı
// ══════════════════════════════════════════════════════
class _GirisUyariBanner extends StatefulWidget {
  final VoidCallback onGirisYap;
  final VoidCallback onKapat;
  const _GirisUyariBanner({required this.onGirisYap, required this.onKapat});

  @override
  State<_GirisUyariBanner> createState() => _GirisUyariBannerState();
}

class _GirisUyariBannerState extends State<_GirisUyariBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade600, Colors.red.shade800],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Giriş Yapmanız Gerekiyor',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Sepete eklemek için lütfen giriş yapın.',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onGirisYap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Giriş Yap',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onKapat,
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
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
