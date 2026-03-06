import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/siparis_bildirim_servisi.dart';

class KullaniciProvider extends ChangeNotifier {
  Map<String, dynamic>? _kullanici;
  String? _token;
  bool _yuklendi = false;

  Map<String, dynamic>? get kullanici => _kullanici;
  String? get token => _token;
  bool get girisYapildi => _kullanici != null;
  bool get yuklendi => _yuklendi;

  KullaniciProvider() {
    _yukle();
  }

  Future<void> _yukle() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final ad = prefs.getString('kullanici_ad');
    final tel = prefs.getString('kullanici_tel');
    final id = prefs.getInt('kullanici_id');
    final adres = prefs.getString('kullanici_adres');

    if (_token != null && ad != null) {
      _kullanici = {
        'id': id,
        'full_name': ad,
        'phone': tel,
        'address': adres ?? '',
      };
    }
    _yuklendi = true;
    notifyListeners();
  }

  Future<void> girisKaydet(String token, Map<String, dynamic> kullanici) async {
    _token = token;
    _kullanici = kullanici;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('kullanici_ad', kullanici['full_name'] ?? '');
    await prefs.setString('kullanici_tel', kullanici['phone'] ?? '');
    await prefs.setInt('kullanici_id', int.tryParse('${kullanici['id']}') ?? 0);
    await prefs.setString('kullanici_adres', kullanici['address'] ?? '');

    notifyListeners();
  }

  // Profil güncellemesi sonrası çağrılır — hem memory hem SharedPreferences güncellenir
  Future<void> kullaniciBilgisiGuncelle(Map<String, dynamic> yeniVeri) async {
    // Mevcut verilerle birleştir — phone/id gibi alanlar silinmesin
    _kullanici = {...?_kullanici, ...yeniVeri};

    final prefs = await SharedPreferences.getInstance();
    if (yeniVeri['full_name'] != null) {
      await prefs.setString('kullanici_ad', yeniVeri['full_name'].toString());
    }
    if (yeniVeri['address'] != null) {
      await prefs.setString('kullanici_adres', yeniVeri['address'].toString());
    }
    // phone ve id değişmez ama güncelleme sırasında silinmemesi için yaz
    if (yeniVeri['phone'] != null) {
      await prefs.setString('kullanici_tel', yeniVeri['phone'].toString());
    }
    if (yeniVeri['id'] != null) {
      final id = int.tryParse('${yeniVeri['id']}');
      if (id != null) await prefs.setInt('kullanici_id', id);
    }

    notifyListeners();
  }

  Future<void> cikisYap() async {
    _token = null;
    _kullanici = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('kullanici_ad');
    await prefs.remove('kullanici_tel');
    await prefs.remove('kullanici_id');
    await prefs.remove('kullanici_adres');

    SiparisBildirimServisi.instance.durdurPolling();
    notifyListeners();
  }
}
