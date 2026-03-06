import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

// ── FCM arka plan mesaj handler (top-level, isolate dışında) ─────────
@pragma('vm:entry-point')
Future<void> _fcmArkaplanHandler(RemoteMessage message) async {
  // Bu fonksiyon uygulama arka planda/kapalıyken çalışır.
  // Firebase zaten bildirimi otomatik gösterir, ekstra işlem gerekmez.
  debugPrint('[FCM Arka Plan] Mesaj: ${message.notification?.title}');
}

// ── WorkManager arka plan görevi ──────────────────────────────────────
const _bgTaskAdi = 'siparis_kontrol';

@pragma('vm:entry-point')
void workmanagerCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await _arkaPlankontrol();
    } catch (e) {
      debugPrint('[BG] Hata: $e');
    }
    return Future.value(true);
  });
}

Future<void> _arkaPlankontrol() async {
  final prefs = await SharedPreferences.getInstance();
  final phone = prefs.getString('kullanici_tel') ?? '';
  final token = prefs.getString('token');
  if (phone.isEmpty || token == null) return;

  final kayitliJson = prefs.getString('siparis_durumlari') ?? '{}';
  final kayitli = Map<String, String>.from(jsonDecode(kayitliJson));
  if (kayitli.isEmpty) return;

  final siparisler = await ApiService.getSiparislerim(phone);
  final yeniDurumlar = <String, String>{};

  const durumlar = {
    'new':        '📋 Siparişiniz Alındı',
    'preparing':  '👨‍🍳 Siparişiniz Hazırlanıyor',
    'on_the_way': '🛵 Siparişiniz Yola Çıktı!',
    'completed':  '✅ Siparişiniz Teslim Edildi',
    'cancelled':  '❌ Siparişiniz İptal Edildi',
  };

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));

  for (final s in siparisler) {
    final id    = s['id']?.toString() ?? s['order_id']?.toString() ?? '';
    final durum = s['status']?.toString() ?? '';
    if (id.isEmpty || durum.isEmpty) continue;
    yeniDurumlar[id] = durum;

    if (kayitli.containsKey(id) && kayitli[id] != durum) {
      final baslik = durumlar[durum] ?? 'Sipariş Güncellendi';
      await plugin.show(
        id.hashCode, baslik, 'Sipariş #$id',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'siparis_kanal', 'Sipariş Bildirimleri',
            importance: Importance.max, priority: Priority.high,
            playSound: true, enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true,
          ),
        ),
      );
    }
  }
  await prefs.setString('siparis_durumlari', jsonEncode(yeniDurumlar));
}

// ═══════════════════════════════════════════════════════════════════════
// SiparisBildirimServisi
// ═══════════════════════════════════════════════════════════════════════
class SiparisBildirimServisi {
  SiparisBildirimServisi._();
  static final instance = SiparisBildirimServisi._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _fcm    = FirebaseMessaging.instance;
  Timer? _timer;

  static const _basliklar = {
    'new':        'HataySepetim — Siparişiniz Alındı!',
    'preparing':  'HataySepetim — Siparişiniz Hazırlanıyor!',
    'on_the_way': 'HataySepetim — Siparişiniz Yola Çıktı!',
    'completed':  'HataySepetim — Siparişiniz Teslim Edildi!',
    'cancelled':  'HataySepetim — Siparişiniz İptal Edildi!',
  };

  static const _icerikler = {
    'new':        'Siparişiniz Mağaza Tarafından Alındı 🎉',
    'preparing':  'Siparişiniz Mağaza Tarafından Hazırlanıyor 👨‍🍳',
    'on_the_way': 'Siparişiniz Yola Çıktı, Kapınızda! 🚀',
    'completed':  'Siparişiniz Teslim Edildi. İyi Günler! ✅',
    'cancelled':  'Siparişiniz İptal Edildi. Detaylar için uygulamayı açın.',
  };

  // ── Ana init — main() içinde çağrılır ────────────────────────────────
  Future<void> init() async {
    debugPrint('[BildirimServisi] init başladı');

    // 1. Local notifications
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );

    // 2. Android 13+ bildirim izni
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 3. FCM izin (iOS)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 4. Arka plan FCM handler kayıt
    FirebaseMessaging.onBackgroundMessage(_fcmArkaplanHandler);

    // 5. Ön plan FCM mesajı — uygulama açıkken gelen push
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n != null) {
        _bildirimGoster(
          id: message.hashCode,
          baslik: n.title ?? 'HataySepetim',
          mesaj:  n.body  ?? '',
        );
      }
    });

    // 6. Uygulama ARKA PLANDA iken bildirime tıklanırsa
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Arka planda tıklandı: ${message.data}');
      // İstersen burada belirli bir ekrana yönlendirebilirsin
    });

    // 7. Uygulama KAPALI iken bildirime tıklanarak açıldıysa
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] Kapalıyken tıklandı: ${initialMessage.data}');
    }

    // 8. FCM token al ve kaydet
    await _fcmTokenKaydet();

    // 9. Token yenilenince güncelle
    _fcm.onTokenRefresh.listen((yeniToken) {
      debugPrint('[FCM] Token yenilendi');
      _tokenSunucuyaGonder(yeniToken);
    });

    // 10. WorkManager başlat
    await Workmanager().initialize(workmanagerCallback, isInDebugMode: false);

    // 11. Oturum açıksa polling başlat
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final phone = prefs.getString('kullanici_tel') ?? '';
    if (token != null && phone.isNotEmpty) {
      baslatPolling();
    }

    debugPrint('[BildirimServisi] init tamamlandı');
  }

  // ── FCM token al, kaydet, sunucuya gönder ────────────────────────────
  Future<void> _fcmTokenKaydet() async {
    try {
      final fcmToken = await _fcm.getToken();
      if (fcmToken == null) {
        debugPrint('[FCM] Token alınamadı');
        return;
      }
      debugPrint('[FCM] Token alındı');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmToken);

      final tel = prefs.getString('kullanici_tel') ?? '';
      if (tel.isNotEmpty) await _tokenSunucuyaGonder(fcmToken);
    } catch (e) {
      debugPrint('[FCM] Token hatası: $e');
    }
  }

  Future<void> _tokenSunucuyaGonder(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tel = prefs.getString('kullanici_tel') ?? '';
      if (tel.isEmpty) return;
      await ApiService.fcmTokenKaydet(telefon: tel, fcmToken: fcmToken);
      debugPrint('[FCM] Token sunucuya kaydedildi');
    } catch (e) {
      debugPrint('[FCM] Token kaydetme hatası: $e');
    }
  }

  /// Kullanıcı giriş yaptığında çağır
  Future<void> kullaniciGirisYapti(String telefon) async {
    final prefs = await SharedPreferences.getInstance();
    final fcmToken = prefs.getString('fcm_token');
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await ApiService.fcmTokenKaydet(telefon: telefon, fcmToken: fcmToken);
    }
    baslatPolling();
  }

  // ── Polling ──────────────────────────────────────────────────────────
  void baslatPolling() {
    _timer?.cancel();
    _kontrol();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _kontrol());

    Workmanager().registerPeriodicTask(
      _bgTaskAdi, _bgTaskAdi,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(seconds: 10),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
    debugPrint('[BildirimServisi] Polling başladı');
  }

  void durdurPolling() {
    _timer?.cancel();
    _timer = null;
    Workmanager().cancelByUniqueName(_bgTaskAdi);
    debugPrint('[BildirimServisi] Polling durduruldu');
  }

  Future<void> _kontrol() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('kullanici_tel') ?? '';
      if (phone.isEmpty) return;

      final kayitliJson = prefs.getString('siparis_durumlari') ?? '{}';
      final kayitli = Map<String, String>.from(jsonDecode(kayitliJson));
      final siparisler = await ApiService.getSiparislerim(phone);
      final yeniDurumlar = <String, String>{};

      for (final s in siparisler) {
        final id    = s['id']?.toString() ?? s['order_id']?.toString() ?? '';
        final durum = s['status']?.toString() ?? '';
        if (id.isEmpty || durum.isEmpty) continue;
        yeniDurumlar[id] = durum;

        if (kayitli.isNotEmpty && kayitli.containsKey(id) && kayitli[id] != durum) {
          debugPrint('[BildirimServisi] #$id değişti: ${kayitli[id]} → $durum');
          await _bildirimGoster(
            id: id.hashCode,
            baslik: _basliklar[durum] ?? 'HataySepetim — Sipariş Güncellendi',
            mesaj:  _icerikler[durum] ?? 'Siparişiniz güncellendi.',
          );
        }
      }
      await prefs.setString('siparis_durumlari', jsonEncode(yeniDurumlar));
    } catch (e) {
      debugPrint('[BildirimServisi] Kontrol hatası: $e');
    }
  }

  // ── Test bildirimi ───────────────────────────────────────────────────
  Future<void> testBildirimi() async {
    await _bildirimGoster(
      id: 9999,
      baslik: 'HataySepetim — Test',
      mesaj: 'Bildirimler çalışıyor! 🚀',
    );
  }

  // ── Göster ──────────────────────────────────────────────────────────
  Future<void> _bildirimGoster({
    required int id,
    required String baslik,
    required String mesaj,
  }) async {
    await _plugin.show(
      id, baslik, mesaj,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'siparis_kanal', 'Sipariş Bildirimleri',
          channelDescription: 'Sipariş durum güncellemeleri',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
    );
  }
}
