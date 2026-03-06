import 'package:flutter/foundation.dart';

class SepetUrun {
  final int urunId;
  final int storeId;
  final String storeName;
  final String storeSlug;
  final String urunAdi;
  final double fiyat;
  final String? imageUrl;
  final String? beden;
  int adet;

  SepetUrun({
    required this.urunId,
    required this.storeId,
    required this.storeName,
    required this.storeSlug,
    required this.urunAdi,
    required this.fiyat,
    this.imageUrl,
    this.beden,
    this.adet = 1,
  });

  double get toplamFiyat => fiyat * adet;
}

class SepetProvider extends ChangeNotifier {
  final List<SepetUrun> _urunler = [];

  List<SepetUrun> get urunler => _urunler;

  int get toplamAdet => _urunler.fold(0, (sum, u) => sum + u.adet);

  double get araToplam => _urunler.fold(0.0, (sum, u) => sum + u.toplamFiyat);

  double get kargoUcreti {
    if (_urunler.isEmpty) return 0;
    return 60.0; // Standart kargo
  }

  double get genelToplam => araToplam + kargoUcreti;

  // Sepete ekle
  void ekle(SepetUrun yeniUrun) {
    final index = _urunler.indexWhere(
      (u) => u.urunId == yeniUrun.urunId && u.beden == yeniUrun.beden,
    );

    if (index >= 0) {
      _urunler[index].adet++;
    } else {
      _urunler.add(yeniUrun);
    }
    notifyListeners();
  }

  // Adet azalt
  void azalt(int urunId, String? beden) {
    final index = _urunler.indexWhere(
      (u) => u.urunId == urunId && u.beden == beden,
    );
    if (index < 0) return;

    if (_urunler[index].adet > 1) {
      _urunler[index].adet--;
    } else {
      _urunler.removeAt(index);
    }
    notifyListeners();
  }

  // Ürün kaldır
  void kaldir(int urunId, String? beden) {
    _urunler.removeWhere((u) => u.urunId == urunId && u.beden == beden);
    notifyListeners();
  }

  // Sepeti temizle
  void temizle() {
    _urunler.clear();
    notifyListeners();
  }

  // Sipariş için mağaza kontrolü (tek mağazadan sipariş)
  int? get aktifStoreId {
    if (_urunler.isEmpty) return null;
    return _urunler.first.storeId;
  }

  bool farkliMagaza(int storeId) {
    if (_urunler.isEmpty) return false;
    return _urunler.first.storeId != storeId;
  }
}
