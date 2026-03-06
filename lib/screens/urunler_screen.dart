import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/sepet_provider.dart';
import '../providers/kullanici_provider.dart';
import 'urun_detay_screen.dart';
import 'sepet_screen.dart';
import 'giris_screen.dart';

class UrunlerScreen extends StatefulWidget {
  final String magazaSlug;
  final String magazaAdi;
  final Color renk;
  final int storeId;

  const UrunlerScreen({
    super.key,
    required this.magazaSlug,
    required this.magazaAdi,
    required this.renk,
    required this.storeId,
  });

  @override
  State<UrunlerScreen> createState() => _UrunlerScreenState();
}

class _UrunlerScreenState extends State<UrunlerScreen> {
  List<dynamic> _urunler = [];
  bool _yukleniyor = true;
  final _aramaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle({String? search}) async {
    setState(() => _yukleniyor = true);
    try {
      final data = await ApiService.getUrunler(widget.magazaSlug, search: search);
      setState(() { _urunler = data; _yukleniyor = false; });
    } catch (_) {
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.magazaAdi),
        actions: [
          Consumer<SepetProvider>(
            builder: (_, sepet, __) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SepetScreen()),
                  ),
                ),
                if (sepet.toplamAdet > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                      child: Text('${sepet.toplamAdet}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _aramaCtrl,
              onChanged: (v) => _yukle(search: v.isEmpty ? null : v),
              decoration: InputDecoration(
                hintText: 'Ürün ara...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)))
          : _urunler.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📦', style: TextStyle(fontSize: 60)),
                      SizedBox(height: 16),
                      Text('Henüz ürün eklenmemiş', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: (_urunler.length / 2).ceil(),
                  itemBuilder: (_, rowIndex) {
                    final i1 = rowIndex * 2;
                    final i2 = i1 + 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _UrunKart(
                                urun: _urunler[i1],
                                renk: widget.renk,
                                storeId: widget.storeId,
                                storeName: widget.magazaAdi,
                                storeSlug: widget.magazaSlug,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: i2 < _urunler.length
                                  ? _UrunKart(
                                      urun: _urunler[i2],
                                      renk: widget.renk,
                                      storeId: widget.storeId,
                                      storeName: widget.magazaAdi,
                                      storeSlug: widget.magazaSlug,
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _UrunKart extends StatelessWidget {
  final Map<String, dynamic> urun;
  final Color renk;
  final int storeId;
  final String storeName;
  final String storeSlug;

  const _UrunKart({required this.urun, required this.renk, required this.storeId, required this.storeName, required this.storeSlug});

  int _toInt(dynamic val) => int.tryParse(val?.toString() ?? '0') ?? 0;
  double _toDouble(dynamic val) => double.tryParse(val?.toString() ?? '0') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final stok      = _toInt(urun['stock']);
    final tukendi   = stok <= 0;
    final indirim   = _toInt(urun['discount_percent']);
    final hasSiz    = _toInt(urun['has_size']) == 1 && (urun['beden_listesi'] as List? ?? []).isNotEmpty;
    final urunId    = _toInt(urun['id']);
    final fiyat     = _toDouble(urun['price']);
    final eskiFiyat = urun['old_price'] != null ? _toDouble(urun['old_price']) : null;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UrunDetayScreen(
        urunId: urunId, storeId: storeId, storeName: storeName, storeSlug: storeSlug, renk: renk,
      ))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        // Column mainAxisSize.min — içerik kadar yer kaplar, boşluk kalmaz
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Görsel
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 0.9,
                    child: urun['image_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: urun['image_url'],
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF2F2F7),
                              child: const Center(child: SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8C00)),
                              )),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF2F2F7),
                              child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 40)),
                            ),
                          )
                        : Container(color: const Color(0xFFF2F2F7),
                            child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 40))),
                  ),
                ),
                if (indirim > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF00C8)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('%$indirim', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
                if (tukendi)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Container(
                        color: Colors.black54,
                        child: const Center(child: Text('TÜKENDİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1))),
                      ),
                    ),
                  ),
              ],
            ),

            // Bilgi alanı — buton her zaman en altta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Üst kısım: isim + stok + fiyat
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          urun['name']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          !tukendi ? 'Stok: $stok' : 'Stokta Yok',
                          style: TextStyle(fontSize: 10, color: tukendi ? Colors.red : Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${_fmt(fiyat)} ₺',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: renk),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (eskiFiyat != null && eskiFiyat > 0) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${_fmt(eskiFiyat)} ₺',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    // Alt kısım: buton her zaman en altta
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: tukendi ? null : () => _sepeteEkle(context, hasSiz, urunId, fiyat),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tukendi ? Colors.grey.shade200 : renk,
                          foregroundColor: tukendi ? Colors.grey : Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          elevation: 0,
                        ),
                        child: Text(tukendi ? 'Tükendi' : hasSiz ? 'Beden Seç' : 'Sepete Ekle'),
                      ),
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

  void _sepeteEkle(BuildContext context, bool hasSiz, int urunId, double fiyat) {
    // Giriş kontrolü
    final kullanici = context.read<KullaniciProvider>();
    if (!kullanici.girisYapildi) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: Color(0xFFFF8C00)),
              SizedBox(width: 10),
              Text('Giriş Gerekli', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: const Text('Sepete ürün eklemek için hesabınıza giriş yapmanız gerekiyor.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GirisScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Giriş Yap', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    if (hasSiz) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UrunDetayScreen(
        urunId: urunId, storeId: storeId, storeName: storeName, storeSlug: storeSlug, renk: renk,
      )));
      return;
    }
    final sepet = context.read<SepetProvider>();
    if (sepet.farkliMagaza(storeId)) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Sepeti Temizle'),
        content: const Text('Farklı bir mağazadan ürün eklemek için sepetinizi temizlemeniz gerekiyor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () { sepet.temizle(); _ekle(context, sepet, urunId, fiyat); Navigator.pop(context); },
            child: const Text('Temizle ve Ekle', style: TextStyle(color: Colors.red))),
        ],
      ));
      return;
    }
    _ekle(context, sepet, urunId, fiyat);
  }

  void _ekle(BuildContext context, SepetProvider sepet, int urunId, double fiyat) {
    sepet.ekle(SepetUrun(
      urunId: urunId, storeId: storeId, storeName: storeName, storeSlug: storeSlug,
      urunAdi: urun['name']?.toString() ?? '', fiyat: fiyat, imageUrl: urun['image_url']?.toString(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${urun['name']} sepete eklendi ✓'),
      backgroundColor: const Color(0xFF2BDC6B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  String _fmt(double f) => f.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}
