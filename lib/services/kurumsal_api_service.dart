import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KurumsalApiService {
  static const String _base = 'https://reyhanli.hataysepetim.com.tr/panel/api';

  // ── SharedPreferences ──────────────────────────────────────────────────────
  static Future<void> _kaydet(int storeId, int userId, String username,
      String role, String storeCategory) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('k_store_id', storeId);
    await p.setInt('k_user_id', userId);
    await p.setString('k_username', username);
    await p.setString('k_role', role);
    await p.setString('k_store_category', storeCategory);
  }

  static Future<void> temizle() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('k_store_id');
    await p.remove('k_user_id');
    await p.remove('k_username');
    await p.remove('k_role');
    await p.remove('k_store_category');
    // Beni hatırla aktifse kimlik bilgilerini silme,
    // sadece oturum bilgilerini temizle.
  }

  static Future<int?> getStoreId() async =>
      (await SharedPreferences.getInstance()).getInt('k_store_id');

  static Future<int?> getUserId() async =>
      (await SharedPreferences.getInstance()).getInt('k_user_id');

  static Future<Map<String, String?>> getKurumsalBilgi() async {
    final p = await SharedPreferences.getInstance();
    return {
      'username':       p.getString('k_username'),
      'role':           p.getString('k_role'),
      'store_category': p.getString('k_store_category'),
    };
  }

  // ── BENİ HATIRLA — Güvenli Kimlik Bilgisi Kaydet/Yükle ───────────────────
  //
  // Kullanıcı adı + şifre → flutter_secure_storage (iOS Keychain / Android Keystore)
  // Beni hatırla bayrağı  → SharedPreferences (hassas değil, düz metin tamam)
  //
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kUsername    = 'k_sec_username';
  static const _kPassword    = 'k_sec_password';
  static const _kHatirla     = 'k_beni_hatirla';

  /// Kullanıcı adı ve şifreyi cihazın güvenli deposuna yazar.
  /// iOS → Keychain, Android → EncryptedSharedPreferences (AES-256)
  static Future<void> kimlikKaydet({
    required String username,
    required String password,
  }) async {
    await _secure.write(key: _kUsername, value: username);
    await _secure.write(key: _kPassword, value: password);
    // Bayrağı normal prefs'e yaz (hassas veri değil)
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHatirla, true);
  }

  /// Güvenli depodan kimlik bilgilerini ve bayrağı siler.
  static Future<void> kimlikSil() async {
    await _secure.delete(key: _kUsername);
    await _secure.delete(key: _kPassword);
    final p = await SharedPreferences.getInstance();
    await p.remove(_kHatirla);
  }

  /// Kayıtlı kimlik bilgilerini döndürür.
  /// Beni hatırla aktif değilse veya veri yoksa null döner.
  static Future<Map<String, String>?> kayitliKimlikGetir() async {
    final p       = await SharedPreferences.getInstance();
    final hatirla = p.getBool(_kHatirla) ?? false;
    if (!hatirla) return null;
    final username = await _secure.read(key: _kUsername);
    final password = await _secure.read(key: _kPassword);
    if (username == null || password == null) return null;
    return {'username': username, 'password': password};
  }

  static Future<bool> beniHatirlaAktifMi() async =>
      (await SharedPreferences.getInstance()).getBool(_kHatirla) ?? false;

  // ── GİRİŞ ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> girisYap({
    required String username,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/login_api.php'),
        body: {'username': username.trim(), 'password': password},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['status'] == 'success') {
        final storeId = _toInt(data['store_id']);
        final userId  = _toInt(data['user_id'] ?? data['store_id']);
        await _kaydet(
          storeId,
          userId,
          data['username']?.toString() ?? username,
          data['role']?.toString() ?? 'store',
          data['store_category']?.toString() ?? '',
        );
        data['store_id'] = storeId;
        data['user_id']  = userId;
      }
      return data;
    } catch (e) {
      return {'status': 'error', 'message': 'Bağlantı hatası: $e'};
    }
  }

  // ── İSTATİSTİKLER ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats(int storeId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/stats.php'),
        body: {'store_id': '$storeId'},
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  // ── SİPARİŞLER ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getSiparisler(int storeId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/siparisler.php'),
        body: {'store_id': '$storeId'},
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['orders'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> siparisDurumGuncelle({
    required int orderId,
    required int storeId,
    required String durum,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/siparis_durum_guncelle.php'),
        body: {
          'order_id': '$orderId',
          'store_id': '$storeId',
          'status':   durum,
        },
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  // ── ÜRÜNLER ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getUrunler(int storeId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/urunler.php'),
        body: {'store_id': '$storeId'},
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        return (data['products'] as List?) ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> stokGuncelle({
    required int productId,
    required int storeId,
    required int delta,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/stok_guncelle.php'),
        body: {
          'product_id': '$productId',
          'store_id':   '$storeId',
          'delta':      '$delta',
        },
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  static Future<bool> urunSil({
    required int productId,
    required int storeId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/urun_sil.php'),
        body: {'product_id': '$productId', 'store_id': '$storeId'},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasSizeToggle({
    required int productId,
    required int storeId,
    required int hasSizeValue,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/beden_toggle.php'),
        body: {
          'id':       '$productId',
          'store_id': '$storeId',
          'has_size': '$hasSizeValue',
        },
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Ürün Ekle — multipart/form-data
  static Future<Map<String, dynamic>> urunEkle({
    required int storeId,
    required int userId,
    required String name,
    required double price,
    required int stock,
    String description = '',
    double? oldPrice,
    String sizes = '',
    File? image,
    File? image2,
    File? image3,
    File? video,
    bool saveAndNew = false,
  }) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('$_base/urun_ekle.php'));
      req.fields['store_id']    = '$storeId';
      req.fields['user_id']     = '$userId';
      req.fields['name']        = name;
      req.fields['price']       = '$price';
      req.fields['stock']       = '$stock';
      req.fields['description'] = description;
      req.fields['sizes']       = sizes;
      if (oldPrice != null && oldPrice > 0) {
        req.fields['old_price'] = '$oldPrice';
      }
      if (saveAndNew) req.fields['save_and_new'] = '1';

      for (final entry in {'image': image, 'image2': image2, 'image3': image3}
          .entries) {
        if (entry.value != null) {
          final ext  = entry.value!.path.split('.').last.toLowerCase();
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          req.files.add(await http.MultipartFile.fromPath(
            entry.key, entry.value!.path,
            contentType: MediaType.parse(mime),
          ));
        }
      }

      if (video != null) {
        final ext = video.path.split('.').last.toLowerCase();
        final mimeMap = {
          'mp4': 'video/mp4', 'mov': 'video/mp4', 'avi': 'video/x-msvideo',
          'wmv': 'video/x-ms-wmv', 'flv': 'video/x-flv',
          'mkv': 'video/x-matroska', 'webm': 'video/webm',
          'm4v': 'video/mp4', '3gp': 'video/3gpp',
          'mpeg': 'video/mpeg', 'mpg': 'video/mpeg',
        };
        final mime = mimeMap[ext] ?? 'video/mp4';
        req.files.add(await http.MultipartFile.fromPath(
          'video', video.path,
          contentType: MediaType.parse(mime),
        ));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final res = await http.Response.fromStream(streamed);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  /// Son ürünü getir (klonlamak için)
  static Future<Map<String, dynamic>?> getSonUrun(int storeId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/son_urun.php'),
        body: {'store_id': '$storeId'},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'success') return data['product'] as Map<String, dynamic>?;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ürün Düzenle — multipart/form-data
  static Future<Map<String, dynamic>> urunDuzenle({
    required int productId,
    required int storeId,
    required String name,
    required double price,
    required int stock,
    String description = '',
    double? oldPrice,
    String sizes = '',
    File? image,
    File? image2,
    File? image3,
    File? video,
    bool removeVideo = false,
  }) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('$_base/urun_duzenle.php'));
      req.fields['product_id']  = '$productId';
      if (removeVideo) req.fields['remove_video'] = '1';
      req.fields['store_id']    = '$storeId';
      req.fields['name']        = name;
      req.fields['price']       = '$price';
      req.fields['stock']       = '$stock';
      req.fields['description'] = description;
      req.fields['sizes']       = sizes;
      if (oldPrice != null && oldPrice > 0) {
        req.fields['old_price'] = '$oldPrice';
      }

      for (final entry in {'image': image, 'image2': image2, 'image3': image3}
          .entries) {
        if (entry.value != null) {
          final ext  = entry.value!.path.split('.').last.toLowerCase();
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          req.files.add(await http.MultipartFile.fromPath(
            entry.key, entry.value!.path,
            contentType: MediaType.parse(mime),
          ));
        }
      }

      if (video != null) {
        final ext = video.path.split('.').last.toLowerCase();
        final mimeMap = {
          'mp4': 'video/mp4', 'mov': 'video/mp4', 'avi': 'video/x-msvideo',
          'wmv': 'video/x-ms-wmv', 'flv': 'video/x-flv',
          'mkv': 'video/x-matroska', 'webm': 'video/webm',
          'm4v': 'video/mp4', '3gp': 'video/3gpp',
          'mpeg': 'video/mpeg', 'mpg': 'video/mpeg',
        };
        final mime = mimeMap[ext] ?? 'video/mp4';
        req.files.add(await http.MultipartFile.fromPath(
          'video', video.path,
          contentType: MediaType.parse(mime),
        ));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final res = await http.Response.fromStream(streamed);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  // ── MAĞAZA LOGO ────────────────────────────────────────────────────────────
  static Future<String?> getStoreLogo(int storeId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/store_logo.php'),
        body: {'store_id': '$storeId'},
      ).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        return data['logo_url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── YARDIMCI ───────────────────────────────────────────────────────────────
  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
