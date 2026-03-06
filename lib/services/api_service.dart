import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://reyhanli.hataysepetim.com.tr/api';

  static String optimizeGorsel(String? url, {int width = 400}) {
    return url ?? '';
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    debugPrint('[TOKEN] SharedPreferences keys: ${prefs.getKeys()}');
    debugPrint('[TOKEN] token değeri: $token');
    return token;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    debugPrint('[HEADERS] oluşturulan headers: $headers');
    return headers;
  }

  // KATEGORİLER
  static Future<List<dynamic>> getKategoriler() async {
    final res = await http.get(Uri.parse('$baseUrl/kategoriler.php'));
    final data = jsonDecode(res.body);
    return data['data'] ?? [];
  }

  // MAĞAZALAR
  static Future<List<dynamic>> getMagazalar({String? category, String? subcategory, String? search}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (subcategory != null) params['subcategory'] = subcategory;
    if (search != null) params['search'] = search;
    final uri = Uri.parse('$baseUrl/magazalar_api.php').replace(queryParameters: params);
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    return data['data'] ?? [];
  }

  // MAĞAZA DETAY — store_id ile mağazayı bul
  static Future<Map<String, dynamic>?> getMagazaById(int storeId) async {
    try {
      final uri = Uri.parse('$baseUrl/magazalar_api.php')
          .replace(queryParameters: {'store_id': '$storeId'});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final list = data['data'] as List?;
      if (list != null && list.isNotEmpty) return list.first as Map<String, dynamic>;
      return null;
    } catch (_) { return null; }
  }

  // ÜRÜNLER
  static Future<List<dynamic>> getUrunler(String magazaSlug, {String? search}) async {
    final params = <String, String>{'magaza': magazaSlug};
    if (search != null) params['search'] = search;
    final uri = Uri.parse('$baseUrl/urunler_api.php').replace(queryParameters: params);
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    return data['data'] ?? [];
  }

  static Future<Map<String, dynamic>?> getUrunDetay(int urunId) async {
    final uri = Uri.parse('$baseUrl/urunler_api.php').replace(queryParameters: {'urun_id': '$urunId'});
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    return data['success'] ? data['data'] : null;
  }

  // MÜŞTERİ
  static Future<Map<String, dynamic>> girisYap(String phone, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/musteri_api.php?action=giris'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'giris', 'phone': phone, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> kayitOl(String fullName, String phone, String password, String address) async {
    final res = await http.post(
      Uri.parse('$baseUrl/musteri_api.php?action=kayit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'kayit', 'full_name': fullName, 'phone': phone, 'password': password, 'address': address}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>?> getProfil() async {
    final headers = await _headers();
    final res = await http.get(Uri.parse('$baseUrl/musteri_api.php?action=profil'), headers: headers);
    final data = jsonDecode(res.body);
    return data['success'] ? data['data'] : null;
  }

  static Future<Map<String, dynamic>> profilGuncelle({required String fullName, required String address}) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$baseUrl/musteri_api.php?action=profil_guncelle'),
      headers: headers,
      body: jsonEncode({'action': 'profil_guncelle', 'full_name': fullName, 'address': address}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> sifreGuncelle({required String eskiSifre, required String yeniSifre}) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$baseUrl/musteri_api.php?action=sifre_guncelle'),
      headers: headers,
      body: jsonEncode({'action': 'sifre_guncelle', 'eski_sifre': eskiSifre, 'yeni_sifre': yeniSifre}),
    );
    return jsonDecode(res.body);
  }

  // SİPARİŞ
  static Future<Map<String, dynamic>> siparisDe({
    required int storeId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String paymentMethod,
    required String deliveryType,
    required List<Map<String, dynamic>> urunler,
    String? siparisnotu,
  }) async {
    final headers = await _headers();
    final body = <String, dynamic>{
      'action': 'olustur',
      'store_id': storeId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'payment_method': paymentMethod,
      'delivery_type': deliveryType,
      'urunler': urunler,
    };
    if (siparisnotu != null && siparisnotu.isNotEmpty) body['note'] = siparisnotu;
    final res = await http.post(
      Uri.parse('$baseUrl/siparis_api.php?action=olustur'),
      headers: headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  // DEKONT YÜKLE
  static String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'pdf':  return 'application/pdf';
      default:     return 'image/jpeg';
    }
  }

  static Future<Map<String, dynamic>> dekontYukle({
    required dynamic orderId,
    required File dosya,
  }) async {
    final token = await getToken();
    final mime  = _mimeFromPath(dosya.path);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/musteri_api.php?action=dekont_yukle'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['order_id'] = '$orderId';
    request.files.add(await http.MultipartFile.fromPath(
      'receipt',
      dosya.path,
      contentType: MediaType.parse(mime),
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }

  // SİPARİŞLERİM
  static Future<List<dynamic>> getSiparislerim(String phone) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$baseUrl/siparis_api.php?action=liste'),
      headers: headers,
      body: jsonEncode({'action': 'liste', 'phone': phone}),
    );
    final data = jsonDecode(res.body);
    return data['data'] ?? [];
  }

  // ── YORUMLAR ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getYorumlar(int urunId) async {
    try {
      final uri = Uri.parse('$baseUrl/yorumlar_api.php').replace(queryParameters: {'urun_id': '$urunId'});
      final res = await http.get(uri);
      final data = jsonDecode(res.body);
      return data['data'] ?? [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> yorumEkle({
    required int urunId,
    required int puan,
    required String yorum,
  }) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$baseUrl/yorumlar_api.php?action=ekle'),
      headers: headers,
      body: jsonEncode({'urun_id': urunId, 'puan': puan, 'yorum': yorum}),
    );
    return jsonDecode(res.body);
  }

  // ── ONESIGNAL ID KAYDET ────────────────────────────────────────────
  static Future<void> onesignalIdKaydet(String onesignalId) async {
    try {
      final headers = await _headers();
      if (!headers.containsKey('Authorization')) return;
      await http.post(
        Uri.parse('$baseUrl/onesignal_kaydet.php'),
        headers: headers,
        body: jsonEncode({'onesignal_id': onesignalId}),
      );
    } catch (_) {}
  }

  // ── BİLDİRİMLER ───────────────────────────────────────────────────

  static Future<int> bildirimSayisiGetir() async {
    try {
      final headers = await _headers();
      if (!headers.containsKey('Authorization')) {
        debugPrint('[BİLDİRİM SAYI] Authorization yok, return 0');
        return 0;
      }
      final res = await http.get(
        Uri.parse('$baseUrl/bildirimler_api.php?action=sayi'),
        headers: headers,
      );
      debugPrint('[BİLDİRİM SAYI] status: ${res.statusCode}, body: ${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['sayi'] ?? 0;
      }
    } catch (e) {
      debugPrint('[BİLDİRİM SAYI] hata: $e');
    }
    return 0;
  }

  static Future<List<dynamic>> bildirimleriGetir({int sayfa = 1}) async {
    try {
      final headers = await _headers();
      debugPrint('[BİLDİRİM LİSTE] headers: $headers');
      if (!headers.containsKey('Authorization')) {
        debugPrint('[BİLDİRİM LİSTE] Authorization yok, return []');
        return [];
      }
      final res = await http.get(
        Uri.parse('$baseUrl/bildirimler_api.php?action=liste&sayfa=$sayfa'),
        headers: headers,
      );
      debugPrint('[BİLDİRİM LİSTE] status: ${res.statusCode}');
      debugPrint('[BİLDİRİM LİSTE] body: ${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('[BİLDİRİM LİSTE] hata: $e');
    }
    return [];
  }

  // ── FCM Token Kaydet ─────────────────────────────────────────────────
  static Future<bool> fcmTokenKaydet({
    required String telefon,
    required String fcmToken,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/fcm_token_kaydet.php'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'telefon': telefon, 'fcm_token': fcmToken}),
      );
      debugPrint('[FCM TOKEN] status: ${res.statusCode} | body: ${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('[FCM TOKEN] hata: $e');
    }
    return false;
  }

}
