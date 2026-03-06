import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/sepet_provider.dart';
import '../providers/kullanici_provider.dart';
import 'odeme_screen.dart';

class SepetScreen extends StatelessWidget {
  const SepetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sepet = context.watch<SepetProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sepetim'),
        actions: [
          if (sepet.urunler.isNotEmpty)
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sepeti Temizle'),
                  content: const Text('Tüm ürünler sepetten kaldırılacak.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                    TextButton(
                      onPressed: () { context.read<SepetProvider>().temizle(); Navigator.pop(context); },
                      child: const Text('Temizle', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              child: const Text('Temizle', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: sepet.urunler.isEmpty
          ? _BosSepeT()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sepet.urunler.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _SepetKalem(urun: sepet.urunler[i]),
                  ),
                ),
                _OzetPanel(sepet: sepet),
              ],
            ),
    );
  }
}

class _BosSepeT extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(child: Text('🛒', style: TextStyle(fontSize: 50))),
          ),
          const SizedBox(height: 24),
          const Text('Sepetiniz Boş', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1D1D1F))),
          const SizedBox(height: 8),
          const Text('Mağazaları keşfedin ve alışverişe başlayın', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SepetKalem extends StatelessWidget {
  final SepetUrun urun;
  const _SepetKalem({required this.urun});

  @override
  Widget build(BuildContext context) {
    final sepet = context.read<SepetProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          // Resim
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: urun.imageUrl != null
                ? CachedNetworkImage(imageUrl: urun.imageUrl!, width: 70, height: 80, fit: BoxFit.cover)
                : Container(width: 70, height: 80, color: const Color(0xFFF2F2F7),
                    child: const Icon(Icons.image_outlined, color: Colors.grey)),
          ),
          const SizedBox(width: 14),

          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(urun.urunAdi, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (urun.beden != null) Text('Beden: ${urun.beden}', style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis,),
                Text(urun.storeName, style: const TextStyle(color: Color(0xFFFF8C00), fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1,),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text('${_fmt(urun.toplamFiyat)} ₺', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1D1D1F)), overflow: TextOverflow.ellipsis),
                    ),
                    const Spacer(),
                    // Adet kontrolü
                    _AdetKontrol(
                      adet: urun.adet,
                      onAzalt: () => sepet.azalt(urun.urunId, urun.beden),
                      onArtir: () => sepet.ekle(SepetUrun(
                        urunId: urun.urunId, storeId: urun.storeId,
                        storeName: urun.storeName, storeSlug: urun.storeSlug,
                        urunAdi: urun.urunAdi, fiyat: urun.fiyat,
                        imageUrl: urun.imageUrl, beden: urun.beden,
                      )),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sil butonu
          IconButton(
            onPressed: () => sepet.kaldir(urun.urunId, urun.beden),
            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  String _fmt(double f) => f.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class _AdetKontrol extends StatelessWidget {
  final int adet;
  final VoidCallback onAzalt;
  final VoidCallback onArtir;
  const _AdetKontrol({required this.adet, required this.onAzalt, required this.onArtir});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: onAzalt, icon: const Icon(Icons.remove, size: 18), padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
          Text('$adet', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          IconButton(onPressed: onArtir, icon: const Icon(Icons.add, size: 18), padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
        ],
      ),
    );
  }
}

class _OzetPanel extends StatelessWidget {
  final SepetProvider sepet;
  const _OzetPanel({required this.sepet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _SatirFiyat(baslik: 'Ara Toplam', fiyat: sepet.araToplam),
            const SizedBox(height: 8),
            _SatirFiyat(baslik: 'Kargo', fiyat: sepet.kargoUcreti),
            const Divider(height: 20),
            _SatirFiyat(baslik: 'Genel Toplam', fiyat: sepet.genelToplam, kalin: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OdemeScreen())),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                child: Text('Siparişi Tamamla • ${_fmt(sepet.genelToplam)} ₺'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double f) => f.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class _SatirFiyat extends StatelessWidget {
  final String baslik;
  final double fiyat;
  final bool kalin;
  const _SatirFiyat({required this.baslik, required this.fiyat, this.kalin = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: kalin ? 16 : 14, fontWeight: kalin ? FontWeight.w800 : FontWeight.w500, color: kalin ? const Color(0xFF1D1D1F) : Colors.grey);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(baslik, style: style),
        Text('${fiyat.toStringAsFixed(0)} ₺', style: style.copyWith(color: kalin ? const Color(0xFFFF8C00) : Colors.grey)),
      ],
    );
  }
}
