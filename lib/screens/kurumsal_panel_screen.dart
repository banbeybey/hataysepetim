import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/kurumsal_provider.dart';
import '../services/kurumsal_api_service.dart';
import 'ana_sayfa.dart';
import 'urunler_screen.dart';
import '../services/api_service.dart' as pub_api;

// ─── RENKLER ──────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF020617);
const _kCard    = Color(0xFF0F172A);
const _kBorder  = Color(0xFF1E293B);
const _kAccent  = Color(0xFFEAB308);
const _kDanger  = Color(0xFFEF4444);
const _kSuccess = Color(0xFF10B981);
const _kText    = Color(0xFFF1F5F9);
const _kMuted   = Color(0xFF64748B);
const _kBlue    = Color(0xFF60A5FA);
const _kPurple  = Color(0xFFC084FC);

// ─── ANA EKRAN ────────────────────────────────────────────────────────────────
class KurumsalPanelScreen extends StatefulWidget {
  const KurumsalPanelScreen({super.key});
  @override
  State<KurumsalPanelScreen> createState() => _KurumsalPanelScreenState();
}

class _KurumsalPanelScreenState extends State<KurumsalPanelScreen> {
  int _tab = 0;
  int _yeniSiparisSayisi = 0; // Nav badge için
  Timer? _siparisPollTimer;
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _bildirimServisiBaslat();
  }

  @override
  void dispose() {
    _siparisPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bildirimServisiBaslat() async {
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    _siparisPollTimer?.cancel();
    await _siparisleriKontrolEt();
    _siparisPollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _siparisleriKontrolEt());
  }

  Future<void> _siparisleriKontrolEt() async {
    final k = context.read<KurumsalProvider>();
    if (!k.girisYapildi || k.storeId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final kayitliJson = prefs.getString('kurumsal_siparis_ids_${k.storeId}') ?? '[]';
      final kayitliIds = Set<String>.from(jsonDecode(kayitliJson) as List);

      final siparisler = await KurumsalApiService.getSiparisler(k.storeId!);
      final tumIds = siparisler.map((s) => s['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

      // Yeni siparişler = bekleyen (new/pending) siparişler
      final yeniSiparisler = siparisler.where((s) {
        final id = s['id']?.toString() ?? '';
        final durum = s['status']?.toString() ?? s['order_status']?.toString() ?? '';
        return !kayitliIds.contains(id) && (durum == 'new' || durum == 'pending' || durum == 'bekliyor');
      }).toList();

      if (yeniSiparisler.isNotEmpty) {
        // Bildirim gönder
        await _plugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          '🛍️ Yeni Sipariş Geldi!',
          '${yeniSiparisler.length} yeni sipariş hazırlanmayı bekliyor.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'kurumsal_siparis_kanal',
              'Mağaza Sipariş Bildirimleri',
              channelDescription: 'Yeni sipariş bildirimleri',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }

      // Badge güncelle — bekleyen sipariş sayısı
      final bekleyenler = siparisler.where((s) {
        final durum = s['status']?.toString() ?? s['order_status']?.toString() ?? '';
        return durum == 'new' || durum == 'pending' || durum == 'bekliyor';
      }).length;

      if (mounted) setState(() => _yeniSiparisSayisi = bekleyenler);

      // ID'leri kaydet
      await prefs.setString('kurumsal_siparis_ids_${k.storeId}', jsonEncode(tumIds.toList()));
    } catch (e) {
      debugPrint('[KurumsalBildirim] Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.watch<KurumsalProvider>();
    if (!k.girisYapildi) {
      return const Scaffold(
          backgroundColor: _kBg,
          body: Center(child: CircularProgressIndicator(color: _kAccent)));
    }
    final tabs = [
      _DashboardTab(
        storeId: k.storeId!,
        onGoSiparisler: () => setState(() => _tab = 1),
        onGoUrunler:    () => setState(() => _tab = 2),
      ),
      _SiparislerTab(storeId: k.storeId!),
      _UrunlerTab(storeId: k.storeId!, userId: k.userId ?? k.storeId!),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0F1E),
          elevation: 0,
          bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _kBorder)),
          title: Text(
            _tab == 0 ? 'Mağaza Yönetim' : _tab == 1 ? 'Siparişler' : 'Ürünler',
            style: const TextStyle(
                color: _kText, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          actions: _tab == 0 ? const [] : [
            IconButton(
              tooltip: 'Ana Sayfaya Dön',
              icon: const Icon(Icons.home_rounded, color: _kMuted, size: 22),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AnaSayfa()),
                (route) => false,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: _kMuted, size: 20),
              onPressed: () => _cikisOnay(context, k),
            ),
          ],
        ),
        body: IndexedStack(index: _tab, children: tabs),
        bottomNavigationBar: _BottomNav(
            aktif: _tab, siparisBadge: _yeniSiparisSayisi, onTap: (i) => setState(() => _tab = i)),
      ),
    );
  }

  void _cikisOnay(BuildContext ctx, KurumsalProvider k) {
    showDialog(
      context: ctx,
      builder: (_) => _DarkDialog(
        title: 'Oturumu Kapat',
        content: 'Güvenli çıkış yapmak istiyor musunuz?',
        actions: [
          _DarkDialogBtn('Vazgeç', onTap: () => Navigator.pop(ctx)),
          _DarkDialogBtn('Çıkış', danger: true, onTap: () {
            k.cikisYap();
            Navigator.pop(ctx);
            Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  final int storeId;
  final VoidCallback onGoSiparisler, onGoUrunler;
  const _DashboardTab({
    required this.storeId,
    required this.onGoSiparisler,
    required this.onGoUrunler,
  });
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _stats;
  List<dynamic> _sonSiparisler = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      KurumsalApiService.getStats(widget.storeId),
      KurumsalApiService.getSiparisler(widget.storeId),
    ]);
    if (!mounted) return;
    final statsRes = results[0] as Map<String, dynamic>;
    final siparisler = results[1] as List<dynamic>;
    setState(() {
      if (statsRes['status'] == 'success') {
        _stats = statsRes['stats'] as Map<String, dynamic>?;
      }
      // En son 5 siparişi göster
      _sonSiparisler = siparisler.take(5).toList();
      _loading = false;
    });
  }

  int _n(String k) => int.tryParse('${_stats?[k] ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final k = context.watch<KurumsalProvider>();
    return RefreshIndicator(
      color: _kAccent,
      backgroundColor: _kCard,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── PROFIL HEADER ──────────────────────────────────────────
                _ProfileHeader(
                  username: k.username ?? '',
                  logoUrl: k.logoUrl,
                  storeCategory: k.storeCategory ?? '',
                  onLogout: () {
                    k.cikisYap();
                    Navigator.pop(context);
                  },
                  onHome: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AnaSayfa()),
                    (route) => false,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── STAT KARTLARI ────────────────────────────────────
                      Row(children: [
                        Expanded(child: _StatCard(
                          label: 'Bekleyen',
                          value: '${_n('pending_orders')}',
                          icon: Icons.hourglass_top_rounded,
                          iconColor: _kDanger,
                          urgent: _n('pending_orders') > 0,
                          onTap: widget.onGoSiparisler,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _StatCard(
                          label: 'Bugün',
                          value: '${_n('today_orders')}',
                          icon: Icons.today_rounded,
                          iconColor: _kBlue,
                          onTap: widget.onGoSiparisler,
                        )),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _StatCard(
                          label: 'Ürünler',
                          value: '${_n('total_products')}',
                          icon: Icons.inventory_2_rounded,
                          iconColor: _kAccent,
                          onTap: widget.onGoUrunler,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _StatCard(
                          label: 'Kritik Stok',
                          value: '${_n('low_stock')}',
                          icon: Icons.warning_amber_rounded,
                          iconColor: _n('low_stock') > 0 ? _kDanger : _kMuted,
                          urgent: _n('low_stock') > 0,
                          onTap: widget.onGoUrunler,
                        )),
                      ]),

                      const SizedBox(height: 24),

                      // ── HIZLI ERİŞİM ─────────────────────────────────────
                      Row(children: [
                        Expanded(child: _QuickBtn(
                          label: 'Siparişler',
                          icon: Icons.receipt_long_rounded,
                          color: _kBlue,
                          onTap: widget.onGoSiparisler,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _QuickBtn(
                          label: 'Ürünler',
                          icon: Icons.inventory_2_rounded,
                          color: _kAccent,
                          onTap: widget.onGoUrunler,
                        )),
                      ]),
                      const SizedBox(height: 10),
                      _MagazamiGorBtn(
                        storeId:  widget.storeId,
                        username: k.username ?? 'Mağazam',
                      ),

                      const SizedBox(height: 28),

                      // ── SON SİPARİŞLER ────────────────────────────────────
                      if (_sonSiparisler.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Son Siparişler',
                                style: TextStyle(color: _kText, fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            GestureDetector(
                              onTap: widget.onGoSiparisler,
                              child: const Text('Tümünü Gör',
                                  style: TextStyle(color: _kAccent, fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._sonSiparisler.map((s) => _SonSiparisRow(siparis: s)),
                      ],

                      const SizedBox(height: 32),
                      Center(child: Text('© ${DateTime.now().year} HataySepetim',
                          style: const TextStyle(color: _kMuted, fontSize: 11))),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── PROFİL HEADER ────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String username, storeCategory;
  final String? logoUrl;
  final VoidCallback onLogout, onHome;

  const _ProfileHeader({
    required this.username,
    required this.storeCategory,
    required this.logoUrl,
    required this.onLogout,
    required this.onHome,
  });

  String _categoryLabel(String cat) {
    const map = {
      'giyim': 'Giyim Mağazası',
      'elektronik': 'Elektronik',
      'gida': 'Gıda & Market',
      'kozmetik': 'Kozmetik',
      'ev': 'Ev & Yaşam',
    };
    return map[cat.toLowerCase()] ?? cat;
  }

  @override
  Widget build(BuildContext context) {
    final initials = username.isNotEmpty
        ? username.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'HS';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1E),
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          // Avatar / Logo
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kAccent.withOpacity(0.35), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: logoUrl != null && logoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: logoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5)),
                    errorWidget: (_, __, ___) => Center(
                        child: Text(initials,
                            style: const TextStyle(color: _kAccent, fontSize: 16,
                                fontWeight: FontWeight.w800))),
                  )
                : Center(
                    child: Text(initials,
                        style: const TextStyle(color: _kAccent, fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
          ),
          const SizedBox(width: 14),

          // İsim & kategori
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username,
                    style: const TextStyle(color: _kText, fontSize: 15,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: _kSuccess, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('Çevrimiçi',
                      style: const TextStyle(color: _kSuccess, fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  if (storeCategory.isNotEmpty) ...[
                    const Text('  ·  ',
                        style: TextStyle(color: _kMuted, fontSize: 11)),
                    Text(_categoryLabel(storeCategory),
                        style: const TextStyle(color: _kMuted, fontSize: 11)),
                  ],
                ]),
              ],
            ),
          ),

          // Aksiyon butonlar
          _HeaderIconBtn(icon: Icons.home_rounded, onTap: onHome),
          const SizedBox(width: 6),
          _HeaderIconBtn(icon: Icons.logout_rounded, onTap: onLogout, danger: true),
        ],
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _HeaderIconBtn({required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: danger ? _kDanger.withOpacity(0.1) : _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: danger ? _kDanger.withOpacity(0.25) : _kBorder,
        ),
      ),
      child: Icon(icon,
          color: danger ? _kDanger : _kMuted, size: 16),
    ),
  );
}

// ─── STAT KARTI ───────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final bool urgent;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.urgent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: urgent ? iconColor.withOpacity(0.35) : _kBorder,
          ),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    color: urgent ? iconColor : _kText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  )),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(color: _kMuted, fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          )),
          if (urgent)
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── HIZLI ERİŞİM BUTONU ──────────────────────────────────────────────────────
class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.icon,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13,
            fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 10),
      ]),
    ),
  );
}

// ─── SON SİPARİŞ SATIRI ───────────────────────────────────────────────────────
class _SonSiparisRow extends StatelessWidget {
  final Map<String, dynamic> siparis;
  const _SonSiparisRow({required this.siparis});

  static const _statusMap = {
    // Bekleyen
    'new'          : ('Yeni',         _kDanger),
    'pending'      : ('Bekliyor',     _kDanger),
    'bekliyor'     : ('Bekliyor',     _kDanger),
    'waiting'         : ('Bekliyor',          _kDanger),
    'waiting_payment' : ('Ödeme Bekleniyor',  _kAccent),
    // Hazırlanıyor
    'preparing'    : ('Hazırlanıyor', _kAccent),
    'hazirlaniyor' : ('Hazırlanıyor', _kAccent),
    'processing'   : ('İşleniyor',    _kAccent),
    'confirmed'    : ('Onaylandı',    _kAccent),
    'onaylandi'    : ('Onaylandı',    _kAccent),
    // Yolda
    'shipped'      : ('Kargoda',      _kBlue),
    'kargoda'      : ('Kargoda',      _kBlue),
    'on_the_way'   : ('Yolda',        _kBlue),
    'on_way'       : ('Yolda',        _kBlue),
    'out_for_delivery' : ('Dağıtımda', _kBlue),
    'in_transit'   : ('Taşımada',     _kBlue),
    'ready'        : ('Hazır',        _kBlue),
    // Teslim
    'delivered'    : ('Teslim Edildi', _kSuccess),
    'teslim'       : ('Teslim Edildi', _kSuccess),
    'completed'    : ('Tamamlandı',   _kSuccess),
    'tamamlandi'   : ('Tamamlandı',   _kSuccess),
    'done'         : ('Tamamlandı',   _kSuccess),
    // İptal / İade
    'cancelled'    : ('İptal',        _kDanger),
    'canceled'     : ('İptal',        _kDanger),
    'iptal'        : ('İptal',        _kDanger),
    'refunded'     : ('İade Edildi',  _kMuted),
    'returned'     : ('İade',         _kMuted),
    'rejected'     : ('Reddedildi',   _kDanger),
  };

  Color _statusColor(String s) =>
      (_statusMap[s.toLowerCase()] ?? (s, _kMuted)).$2;

  String _statusLabel(String s) =>
      (_statusMap[s.toLowerCase()] ?? (s, _kMuted)).$1;

  @override
  Widget build(BuildContext context) {
    final status   = siparis['status']?.toString() ?? siparis['order_status']?.toString() ?? '';
    final color    = _statusColor(status);
    final id       = siparis['id']?.toString() ?? '';
    final musteri  = siparis['customer_name']?.toString()
        ?? siparis['name']?.toString() ?? 'Müşteri';
    final tutar    = siparis['total']?.toString() ?? siparis['total_price']?.toString() ?? '';
    final tarih    = siparis['created_at']?.toString() ?? '';

    // Tarihi kısalt: "2024-01-15 14:32:00" → "15 Oca 14:32"
    String _formatTarih(String t) {
      try {
        final dt = DateTime.parse(t);
        const aylar = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
                       'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
        return '${dt.day} ${aylar[dt.month]} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) { return t.length > 10 ? t.substring(0, 10) : t; }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        // Sol çizgi — status rengi
        Container(
          width: 3, height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),

        // Sipariş bilgisi
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#$id',
                  style: const TextStyle(color: _kText, fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Expanded(child: Text(musteri,
                  style: const TextStyle(color: _kMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 3),
            Text(tarih.isNotEmpty ? _formatTarih(tarih) : '',
                style: const TextStyle(color: _kMuted, fontSize: 10)),
          ],
        )),

        // Tutar
        if (tutar.isNotEmpty)
          Text('$tutar ₺',
              style: const TextStyle(color: _kAccent, fontSize: 13,
                  fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Text(_statusLabel(status),
              style: TextStyle(color: color, fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ─── SİPARİŞLER (WebView) ────────────────────────────────────────────────────
class _SiparislerTab extends StatefulWidget {
  final int storeId;
  const _SiparislerTab({required this.storeId});
  @override
  State<_SiparislerTab> createState() => _SiparislerTabState();
}

class _SiparislerTabState extends State<_SiparislerTab> {
  late final WebViewController _ctrl;
  bool _loading = false;

  static bool _isPdf(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') ||
        (lower.contains('/receipts/') && lower.contains('.pdf'));
  }

  static bool _isReceipt(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/receipts/') &&
        (lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
         lower.endsWith('.png') || lower.endsWith('.webp'));
  }

  @override
  void initState() {
    super.initState();
    final url = 'https://reyhanli.hataysepetim.com.tr/panel/siparisler.php'
        '?app=1&store_id=${widget.storeId}';
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF020617))
      ..addJavaScriptChannel(
        'FlutterDekont',
        onMessageReceived: (msg) {
          String fileUrl = msg.message;
          // Eğer URL göreceli ise (host içermiyorsa) base domain'i ekle
          if (fileUrl.startsWith('/')) {
            fileUrl = 'https://reyhanli.hataysepetim.com.tr$fileUrl';
          }
          setState(() => _loading = false);
          if (_isPdf(fileUrl)) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => _DosyaGoruntuleScreen(
                baslik: 'Dekont (PDF)', isPdf: true, orijinalUrl: fileUrl),
            ));
          } else {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => _DosyaGoruntuleScreen(
                baslik: 'Dekont', isPdf: false, orijinalUrl: fileUrl),
            ));
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final reqUrl = request.url;
          if (_isPdf(reqUrl) || _isReceipt(reqUrl)) {
            setState(() => _loading = false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (url) {
          if (!_isPdf(url) && !_isReceipt(url)) {
            setState(() => _loading = true);
          }
        },
        onPageFinished: (url) {
          setState(() => _loading = false);
          _ctrl.runJavaScript(
            "(function(){"
            "function fix(){"
            "document.querySelectorAll('a[href]').forEach(function(a){"
            "var h=a.href||'';"
            "if((h.match(/\\.(pdf|jpg|jpeg|png|webp)\$/i)||h.indexOf('/receipts/')!==-1)&&!a.dataset.fi){"
            "a.dataset.fi='1';"
            "a.addEventListener('click',function(e){"
            "e.preventDefault();e.stopImmediatePropagation();"
            "FlutterDekont.postMessage(a.href);"
            "},true);}});"
            "}"
            "fix();"
            "new MutationObserver(fix).observe(document.body,{childList:true,subtree:true});"
            "})();"
          );
        },
        onWebResourceError: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      WebViewWidget(controller: _ctrl),
      if (_loading)
        const Center(child: CircularProgressIndicator(color: _kAccent)),
      Positioned(
        bottom: 16, right: 16,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: _kAccent,
          onPressed: () => _ctrl.reload(),
          child: const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
        ),
      ),
    ]);
  }
}

// ─── DOSYA GÖRÜNTÜLEME EKRANI ─────────────────────────────────────────────────
class _DosyaGoruntuleScreen extends StatefulWidget {
  final String baslik;
  final bool isPdf;
  final String orijinalUrl;
  const _DosyaGoruntuleScreen({
    required this.baslik,
    required this.isPdf,
    required this.orijinalUrl,
  });
  @override
  State<_DosyaGoruntuleScreen> createState() => _DosyaGoruntuleScreenState();
}

class _DosyaGoruntuleScreenState extends State<_DosyaGoruntuleScreen> {
  String? _localPath;
  bool _loading = true;
  bool _hata = false;
  String _hataMesaj = '';

  @override
  void initState() {
    super.initState();
    if (widget.isPdf) {
      _pdfIndir();
    }
  }

  Future<void> _pdfIndir() async {
    setState(() { _loading = true; _hata = false; });
    try {
      final res = await http.get(Uri.parse(widget.orijinalUrl))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('HTTP \${res.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'dekont_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes);
      if (mounted) setState(() { _localPath = file.path; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _hata = true;
        _hataMesaj = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1E),
        iconTheme: const IconThemeData(color: _kText),
        title: Row(children: [
          Icon(widget.isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
              color: _kAccent, size: 18),
          const SizedBox(width: 8),
          Text(widget.baslik,
              style: const TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined, color: _kMuted, size: 20),
            tooltip: 'Linki Kopyala',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.orijinalUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('\u2713 Dosya linki kopyaland\u0131'),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
          if (widget.isPdf && _hata)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kMuted, size: 20),
              onPressed: _pdfIndir,
            ),
        ],
      ),
      body: widget.isPdf ? _pdfBody() : _imageBody(),
    );
  }

  Widget _pdfBody() {
    if (_loading) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _kAccent),
        SizedBox(height: 16),
        Text('PDF indiriliyor...', style: TextStyle(color: _kMuted, fontSize: 13)),
      ]));
    }
    if (_hata || _localPath == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.picture_as_pdf, color: _kMuted, size: 64),
          const SizedBox(height: 16),
          const Text('PDF g\u00f6r\u00fcnt\u00fclenemedi',
              style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_hataMesaj.isNotEmpty ? _hataMesaj : 'Bilinmeyen hata',
              style: const TextStyle(color: _kMuted, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pdfIndir,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 16),
            label: const Text('Tekrar Dene',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: _kAccent),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.orijinalUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('\u2713 Link kopyaland\u0131'),
                behavior: SnackBarBehavior.floating,
              ));
            },
            icon: const Icon(Icons.copy, color: _kMuted, size: 14),
            label: const Text('PDF Linkini Kopyala', style: TextStyle(color: _kMuted)),
          ),
        ]),
      ));
    }
    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      backgroundColor: Colors.black,
      onError: (e) => setState(() { _hata = true; _hataMesaj = e.toString(); }),
      onPageError: (page, e) => setState(() { _hata = true; _hataMesaj = 'Sayfa \$page: \$e'; }),
    );
  }

  Widget _imageBody() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Image.network(
          widget.orijinalUrl,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator(color: _kAccent));
          },
          errorBuilder: (_, __, ___) => const Column(
            mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.broken_image_outlined, color: _kMuted, size: 64),
              SizedBox(height: 12),
              Text('G\u00f6rsel y\u00fcklenemedi', style: TextStyle(color: _kMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
// ─── ÜRÜNLER ──────────────────────────────────────────────────────────────────

class _UrunlerTab extends StatefulWidget {
  final int storeId, userId;
  const _UrunlerTab({required this.storeId, required this.userId});
  @override State<_UrunlerTab> createState() => _UrunlerTabState();
}

class _UrunlerTabState extends State<_UrunlerTab> {
  List<dynamic> _products = [];
  bool   _loading = true;
  String _search  = '';
  final  _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await KurumsalApiService.getUrunler(widget.storeId);
    if (mounted) setState(() { _products = data; _loading = false; });
  }

  List<dynamic> get _filtered => _search.isEmpty
      ? _products
      : _products.where((p) =>
          (p['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('Ürün Ekle',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        onPressed: () async {
          await showModalBottomSheet(context: context,
              isScrollControlled: true, backgroundColor: Colors.transparent,
              builder: (_) => _UrunEkleSheet(storeId: widget.storeId, userId: widget.userId));
          _load();
        },
      ),
      body: Column(children: [
        Container(
          color: const Color(0xFF0A0F1E),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: _kText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ürün ara…',
              hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: _kMuted, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: _kMuted, size: 18),
                      onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
              filled: true, fillColor: _kCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kAccent, width: 1.5)),
            ),
          ),
        ),
        if (!_loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('${_filtered.length} ürün',
                  style: const TextStyle(color: _kMuted, fontSize: 12)),
              const Spacer(),
              GestureDetector(onTap: _load,
                  child: const Icon(Icons.refresh_rounded, color: _kMuted, size: 18)),
            ]),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kAccent))
              : RefreshIndicator(
                  color: _kAccent, backgroundColor: _kCard, onRefresh: _load,
                  child: _filtered.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Center(child: Text('Ürün bulunamadı',
                              style: TextStyle(color: _kMuted))),
                        ])
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, crossAxisSpacing: 12,
                            mainAxisSpacing: 12, childAspectRatio: 0.52,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _ProductCard(
                            product: _filtered[i],
                            storeId: widget.storeId,
                            onRefresh: _load,
                          ),
                        ),
                ),
        ),
      ]),
    );
  }
}

// ─── ÜRÜN KARTI ───────────────────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final int storeId;
  final VoidCallback onRefresh;
  const _ProductCard({required this.product, required this.storeId, required this.onRefresh});
  @override State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  late int  _stock;
  late bool _hasSizes;
  bool _stockLoading  = false;
  bool _toggleLoading = false;

  @override
  void initState() {
    super.initState();
    _stock    = int.tryParse('${widget.product['stock']}') ?? 0;
    final hs  = widget.product['has_size'];
    _hasSizes = hs == 1 || hs == true || hs == '1';
  }

  Color  get _stockColor  => _stock == 0 ? _kDanger : _stock <= 5 ? const Color(0xFFF9A825) : _kSuccess;
  String get _stockLabel  => _stock == 0 ? 'Tükendi' : _stock <= 5 ? 'Az Stok' : 'Aktif';

  Future<void> _changeStock(int delta) async {
    setState(() => _stockLoading = true);
    final r = await KurumsalApiService.stokGuncelle(
      productId: int.tryParse('${widget.product['id']}') ?? 0,
      storeId: widget.storeId, delta: delta,
    );
    if (mounted) setState(() {
      if (r['status'] == 'success') _stock = int.tryParse('${r['new_stock']}') ?? _stock;
      _stockLoading = false;
    });
  }

  Future<void> _toggleHasSizes(bool val) async {
    setState(() => _toggleLoading = true);
    final ok = await KurumsalApiService.hasSizeToggle(
      productId: int.tryParse('${widget.product['id']}') ?? 0,
      storeId: widget.storeId, hasSizeValue: val ? 1 : 0,
    );
    if (mounted) setState(() {
      if (ok) _hasSizes = val;
      _toggleLoading = false;
    });
  }

  void _duzenle() {
    showModalBottomSheet(context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UrunDuzenleSheet(
            storeId: widget.storeId, product: widget.product))
        .then((_) => widget.onRefresh());
  }

  void _sil() {
    final name = widget.product['name']?.toString() ?? '';
    showDialog(context: context, builder: (_) => _DarkDialog(
      title: 'Ürünü Sil',
      content: '"$name" silinecek. Geri alınamaz!',
      actions: [
        _DarkDialogBtn('Vazgeç', onTap: () => Navigator.pop(context)),
        _DarkDialogBtn('Sil', danger: true, onTap: () async {
          Navigator.pop(context);
          final ok = await KurumsalApiService.urunSil(
            productId: int.tryParse('${widget.product['id']}') ?? 0,
            storeId: widget.storeId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? '✓ Ürün silindi' : 'Silme başarısız'),
              backgroundColor: ok ? _kSuccess : _kDanger,
              behavior: SnackBarBehavior.floating,
            ));
            if (ok) widget.onRefresh();
          }
        }),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl        = widget.product['image_url']?.toString() ?? '';
    final name          = widget.product['name']?.toString() ?? '';
    final price         = widget.product['price'];
    final oldPrice      = widget.product['old_price'];
    final hasVideo      = (widget.product['video_url'] ?? '').toString().isNotEmpty;
    final sizeList      = (widget.product['size_list'] as List?) ?? [];
    final storeCategory = widget.product['store_category']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        // Görsel
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          child: Stack(children: [
            imgUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: imgUrl, width: double.infinity, height: 110,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _NoImg(height: 110),
                    errorWidget: (_, __, ___) => const _NoImg(height: 110))
                : const _NoImg(height: 110),
            Positioned(top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _stockColor, borderRadius: BorderRadius.circular(20)),
                child: Text(_stockLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              )),
            if (hasVideo)
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.purple.shade800, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_circle_rounded, color: Colors.white, size: 10),
                    SizedBox(width: 3),
                    Text('Video', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ]),
                )),
          ]),
        ),

        // Body
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(name, style: const TextStyle(color: _kText, fontSize: 11,
                fontWeight: FontWeight.w700, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),

            Row(children: [
              Text('$price ₺', style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w800)),
              if (oldPrice != null && '$oldPrice' != '0' && '$oldPrice' != '0.0' && '$oldPrice' != 'null') ...[
                const SizedBox(width: 4),
                Text('$oldPrice ₺', style: const TextStyle(color: _kMuted, fontSize: 10,
                    decoration: TextDecoration.lineThrough)),
              ],
            ]),

            // Beden Toggle
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Beden', style: TextStyle(color: _kMuted, fontSize: 9)),
              _toggleLoading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5))
                  : Transform.scale(scale: 0.65,
                      child: Switch(value: _hasSizes, onChanged: _toggleHasSizes,
                          activeColor: _kAccent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
            ]),

            // Beden Chip'leri
            if (_hasSizes && storeCategory == 'giyim' && sizeList.isNotEmpty)
              SizedBox(height: 20, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sizeList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 3),
                itemBuilder: (_, i) {
                  final sz  = sizeList[i] as Map;
                  final lbl = sz['label']?.toString() ?? '';
                  final stk = (sz['stock'] as num?)?.toInt() ?? 0;
                  final out = stk <= 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: out ? const Color(0xFF1A0000) : _kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: out ? const Color(0xFF500000) : _kAccent.withOpacity(0.4)),
                    ),
                    child: Text(out ? lbl : '$lbl($stk)',
                        style: TextStyle(color: out ? _kMuted : _kAccent,
                            fontSize: 9, fontWeight: FontWeight.w700)),
                  );
                },
              )),

            // Stok +/-
            Row(children: [
              _StokBtn(icon: Icons.remove, onTap: () => _changeStock(-1), loading: _stockLoading),
              Expanded(child: Center(child: _stockLoading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5))
                  : Text('$_stock', style: const TextStyle(color: _kText,
                      fontWeight: FontWeight.w800, fontSize: 13)))),
              _StokBtn(icon: Icons.add, onTap: () => _changeStock(1), loading: _stockLoading),
            ]),

            Row(children: [
              Expanded(child: _SmBtn('Düzenle', const Color(0xFF1E293B), _kBlue, _duzenle)),
              const SizedBox(width: 6),
              Expanded(child: _SmBtn('Sil', const Color(0xFF1C0000), _kDanger, _sil)),
            ]),
          ]),
        )),
      ]),
    );
  }
}

// ─── ÜRÜN EKLE SHEET ─────────────────────────────────────────────────────────
class _UrunEkleSheet extends StatefulWidget {
  final int storeId, userId;
  const _UrunEkleSheet({required this.storeId, required this.userId});
  @override State<_UrunEkleSheet> createState() => _UrunEkleSheetState();
}

class _UrunEkleSheetState extends State<_UrunEkleSheet> {
  final _adCtrl    = TextEditingController();
  final _fiyatCtrl = TextEditingController();
  final _eskiCtrl  = TextEditingController();
  final _stokCtrl  = TextEditingController(text: '0');
  final _descCtrl  = TextEditingController();
  final _boyutCtrl = TextEditingController();

  File? _img;
  File? _img2;
  File? _img3;
  File? _video;
  bool  _sending      = false;
  bool  _cloneLoading = false;
  Map<String, dynamic>? _clonedFrom;

  @override void dispose() {
    _adCtrl.dispose(); _fiyatCtrl.dispose(); _eskiCtrl.dispose();
    _stokCtrl.dispose(); _descCtrl.dispose(); _boyutCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImg(int slot) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (f == null) return;
    setState(() {
      if (slot == 1) _img  = File(f.path);
      if (slot == 2) _img2 = File(f.path);
      if (slot == 3) _img3 = File(f.path);
    });
  }

  Future<void> _pickVideo() async {
    final f = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (f == null) return;
    final size = await File(f.path).length();
    if (size > 50 * 1024 * 1024) {
      if (mounted) _snack('Video 50MB sınırını aşıyor', _kDanger);
      return;
    }
    setState(() => _video = File(f.path));
  }

  Future<void> _klonla() async {
    setState(() => _cloneLoading = true);
    final p = await KurumsalApiService.getSonUrun(widget.storeId);
    if (!mounted) return;
    setState(() => _cloneLoading = false);
    if (p == null) { _snack('Klonlanacak ürün bulunamadı', _kDanger); return; }
    setState(() {
      _clonedFrom = p;
      _adCtrl.text    = p['name']?.toString() ?? '';
      _descCtrl.text  = p['description']?.toString() ?? '';
      _fiyatCtrl.text = '${p['price'] ?? ''}';
      _stokCtrl.text  = '${p['stock'] ?? '0'}';
      _boyutCtrl.text = p['sizes']?.toString() ?? '';
      final op = p['old_price'];
      _eskiCtrl.text  = (op != null && '$op' != '0' && '$op' != '0.0') ? '$op' : '';
    });
    _snack('✓ Son ürün klonlandı: ${p['name']}', _kSuccess);
  }

  Future<void> _send({bool saveAndNew = false}) async {
    if (_adCtrl.text.trim().isEmpty) { _snack('Ürün adı zorunlu', _kDanger); return; }
    final price = double.tryParse(_fiyatCtrl.text.replaceAll(',', '.'));
    if (price == null || price <= 0) { _snack('Geçerli fiyat girin', _kDanger); return; }
    final oldPrice = double.tryParse(_eskiCtrl.text.replaceAll(',', '.'));
    if (oldPrice != null && oldPrice <= price) {
      _snack('Eski fiyat, yeni fiyattan büyük olmalı', _kDanger); return;
    }

    setState(() => _sending = true);
    final r = await KurumsalApiService.urunEkle(
      storeId:     widget.storeId,
      userId:      widget.userId,
      name:        _adCtrl.text.trim(),
      price:       price,
      stock:       int.tryParse(_stokCtrl.text) ?? 0,
      description: _descCtrl.text.trim(),
      oldPrice:    oldPrice,
      sizes:       _boyutCtrl.text.trim(),
      image:       _img,
      image2:      _img2,
      image3:      _img3,
      video:       _video,
      saveAndNew:  saveAndNew,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (r['status'] == 'success') {
      if (saveAndNew) {
        // Formu sıfırla, sayfayı kapat
        _adCtrl.clear(); _descCtrl.clear(); _fiyatCtrl.clear();
        _eskiCtrl.clear(); _stokCtrl.text = '0'; _boyutCtrl.clear();
        setState(() { _img = _img2 = _img3 = _video = _clonedFrom = null; });
        _snack('✓ Ürün eklendi! Yeni ürün ekleyebilirsiniz.', _kSuccess);
      } else {
        Navigator.pop(context);
        _snack('✓ Ürün eklendi', _kSuccess);
      }
    } else {
      _snack(r['message']?.toString() ?? 'Hata oluştu', _kDanger);
    }
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) => _ProductFormSheet(
    title: 'Yeni Ürün Ekle',
    adCtrl: _adCtrl, fiyatCtrl: _fiyatCtrl, eskiCtrl: _eskiCtrl,
    stokCtrl: _stokCtrl, descCtrl: _descCtrl,
    isGiyim: false,
    sizeRows: const [],
    img: _img, img2: _img2, img3: _img3,
    video: _video,
    sending: _sending,
    cloneLoading: _cloneLoading,
    clonedFrom: _clonedFrom,
    onPickImg:   (slot) => _pickImg(slot),
    onPickVideo: _pickVideo,
    onKlonla:    _klonla,
    onSubmit:    () => _send(),
    onSubmitAndNew: () => _send(saveAndNew: true),
  );
}

// ─── ÜRÜN DÜZENLE SHEET ──────────────────────────────────────────────────────
class _UrunDuzenleSheet extends StatefulWidget {
  final int storeId;
  final Map<String, dynamic> product;
  final String storeCategory;
  const _UrunDuzenleSheet({required this.storeId, required this.product, this.storeCategory = ''});
  @override State<_UrunDuzenleSheet> createState() => _UrunDuzenleSheetState();
}

class _UrunDuzenleSheetState extends State<_UrunDuzenleSheet> {
  late final TextEditingController _adCtrl, _fiyatCtrl, _eskiCtrl, _stokCtrl, _descCtrl;
  // Beden satırları: [{'name': 'S', 'stock': '10'}, ...]
  List<Map<String, TextEditingController>> _sizeRows = [];
  File? _img, _img2, _img3, _video;
  bool  _sending     = false;
  bool  _removeVideo = false; // mevcut videoyu sil

  bool get _isGiyim => widget.storeCategory == 'giyim' ||
      (widget.product['store_category']?.toString() ?? '') == 'giyim';

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _adCtrl    = TextEditingController(text: p['name']?.toString() ?? '');
    _fiyatCtrl = TextEditingController(text: '${p['price'] ?? ''}');
    _eskiCtrl  = TextEditingController(
        text: (p['old_price'] != null && '${p['old_price']}' != '0' && '${p['old_price']}' != '0.0')
            ? '${p['old_price']}' : '');
    _stokCtrl  = TextEditingController(text: '${p['stock'] ?? 0}');
    _descCtrl  = TextEditingController(text: p['description']?.toString() ?? '');

    // Mevcut bedenleri parse et: "S:10,M:5,L:3"
    final sizesRaw = p['sizes']?.toString() ?? '';
    if (sizesRaw.isNotEmpty && sizesRaw.contains(':')) {
      for (final part in sizesRaw.split(',')) {
        final kv = part.split(':');
        _sizeRows.add({
          'name':  TextEditingController(text: kv[0].trim()),
          'stock': TextEditingController(text: kv.length > 1 ? kv[1].trim() : '0'),
        });
      }
    } else if (sizesRaw.isNotEmpty) {
      // Sadece isim varsa stoksuz ekle
      for (final s in sizesRaw.split(',')) {
        if (s.trim().isNotEmpty) {
          _sizeRows.add({
            'name':  TextEditingController(text: s.trim()),
            'stock': TextEditingController(text: '0'),
          });
        }
      }
    }
  }

  @override void dispose() {
    _adCtrl.dispose(); _fiyatCtrl.dispose(); _eskiCtrl.dispose();
    _stokCtrl.dispose(); _descCtrl.dispose();
    for (final row in _sizeRows) {
      row['name']!.dispose();
      row['stock']!.dispose();
    }
    super.dispose();
  }

  void _addSizeRow() {
    setState(() => _sizeRows.add({
      'name':  TextEditingController(),
      'stock': TextEditingController(text: '0'),
    }));
  }

  void _removeSizeRow(int i) {
    final row = _sizeRows.removeAt(i);
    row['name']!.dispose();
    row['stock']!.dispose();
    _syncTotalStock();
    setState(() {});
  }

  void _syncTotalStock() {
    int total = 0;
    for (final row in _sizeRows) {
      total += int.tryParse(row['stock']!.text) ?? 0;
    }
    if (total > 0) _stokCtrl.text = '$total';
  }

  String _buildSizesString() {
    final parts = <String>[];
    for (final row in _sizeRows) {
      final name = row['name']!.text.trim();
      final stock = row['stock']!.text.trim();
      if (name.isNotEmpty) parts.add('$name:$stock');
    }
    return parts.join(',');
  }

  Future<void> _pickImg(int slot) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (f == null) return;
    setState(() {
      if (slot == 1) _img  = File(f.path);
      if (slot == 2) _img2 = File(f.path);
      if (slot == 3) _img3 = File(f.path);
    });
  }

  Future<void> _pickVideo() async {
    final f = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (f == null) return;
    final size = await File(f.path).length();
    if (size > 50 * 1024 * 1024) {
      if (mounted) _snack('Video 50MB sınırını aşıyor', _kDanger);
      return;
    }
    setState(() { _video = File(f.path); _removeVideo = false; });
  }

  Future<void> _send() async {
    if (_adCtrl.text.trim().isEmpty) { _snack('Ürün adı zorunlu', _kDanger); return; }
    final price = double.tryParse(_fiyatCtrl.text.replaceAll(',', '.'));
    if (price == null || price <= 0) { _snack('Geçerli fiyat girin', _kDanger); return; }
    final oldPrice = double.tryParse(_eskiCtrl.text.replaceAll(',', '.'));
    if (oldPrice != null && oldPrice <= price) {
      _snack('Eski fiyat, yeni fiyattan büyük olmalı', _kDanger); return;
    }

    final sizes = _isGiyim ? _buildSizesString() : '';

    setState(() => _sending = true);
    final r = await KurumsalApiService.urunDuzenle(
      productId:   int.tryParse('${widget.product['id']}') ?? 0,
      storeId:     widget.storeId,
      name:        _adCtrl.text.trim(),
      price:       price,
      stock:       int.tryParse(_stokCtrl.text) ?? 0,
      description: _descCtrl.text.trim(),
      oldPrice:    oldPrice,
      sizes:       sizes,
      image:       _img,
      image2:      _img2,
      image3:      _img3,
      video:       _video,
      removeVideo: _removeVideo,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (r['status'] == 'success') {
      Navigator.pop(context);
      _snack('✓ Ürün güncellendi', _kSuccess);
    } else {
      _snack(r['message']?.toString() ?? 'Hata oluştu', _kDanger);
    }
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) => _ProductFormSheet(
    title: 'Ürünü Düzenle',
    adCtrl: _adCtrl, fiyatCtrl: _fiyatCtrl, eskiCtrl: _eskiCtrl,
    stokCtrl: _stokCtrl, descCtrl: _descCtrl,
    isGiyim: _isGiyim,
    sizeRows: _sizeRows,
    onAddSize: _addSizeRow,
    onRemoveSize: _removeSizeRow,
    onSizeChanged: _syncTotalStock,
    img: _img, img2: _img2, img3: _img3,
    video: _video,
    removeVideo: _removeVideo,
    onRemoveVideo: () => setState(() { _removeVideo = true; _video = null; }),
    existingImgUrl:   widget.product['image_url']?.toString(),
    existingImg2Url:  widget.product['image2_url']?.toString(),
    existingImg3Url:  widget.product['image3_url']?.toString(),
    existingVideoUrl: _removeVideo ? null : widget.product['video_url']?.toString(),
    sending: _sending,
    onPickImg:   (slot) => _pickImg(slot),
    onPickVideo: _pickVideo,
    onSubmit:    _send,
  );
}

// ─── ORTAK FORM SHEET ─────────────────────────────────────────────────────────
class _ProductFormSheet extends StatelessWidget {
  final String title;
  final TextEditingController adCtrl, fiyatCtrl, eskiCtrl, stokCtrl, descCtrl;
  final File? img, img2, img3, video;
  final String? existingImgUrl, existingImg2Url, existingImg3Url, existingVideoUrl;
  final bool sending, cloneLoading, isGiyim, removeVideo;
  final Map<String, dynamic>? clonedFrom;
  final List<Map<String, TextEditingController>> sizeRows;
  final VoidCallback? onAddSize, onSubmitAndNew, onKlonla, onRemoveVideo;
  final void Function(int)? onRemoveSize;
  final VoidCallback? onSizeChanged;
  final void Function(int slot) onPickImg;
  final VoidCallback onPickVideo;
  final VoidCallback onSubmit;

  const _ProductFormSheet({
    required this.title,
    required this.adCtrl, required this.fiyatCtrl, required this.eskiCtrl,
    required this.stokCtrl, required this.descCtrl,
    this.img, this.img2, this.img3, this.video,
    this.existingImgUrl, this.existingImg2Url, this.existingImg3Url, this.existingVideoUrl,
    required this.sending,
    this.cloneLoading = false,
    this.isGiyim = false,
    this.removeVideo = false,
    this.clonedFrom,
    this.sizeRows = const [],
    this.onAddSize,
    this.onRemoveSize,
    this.onSizeChanged,
    this.onRemoveVideo,
    required this.onPickImg,
    required this.onPickVideo,
    required this.onSubmit,
    this.onSubmitAndNew,
    this.onKlonla,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Drag handle
        Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(children: [
            Expanded(child: Text(title,
                style: const TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.w800))),
            if (onKlonla != null)
              GestureDetector(
                onTap: cloneLoading ? null : onKlonla,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: _kCard, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: cloneLoading
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.copy_rounded, color: _kAccent, size: 13),
                          SizedBox(width: 4),
                          Text('Klonla', style: TextStyle(color: _kAccent, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                        ]),
                ),
              ),
            IconButton(icon: const Icon(Icons.close, color: _kMuted),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        // Clone notification
        if (clonedFrom != null)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kSuccess.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kSuccess.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: _kSuccess, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '✨ Klonlandı: ${clonedFrom!['name']}',
                style: const TextStyle(color: _kSuccess, fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          ),
        const SizedBox(height: 8),
        const Divider(color: _kBorder, height: 1),
        // Form body
        Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [

          // ── 3'lü GÖRSEL GRID ──────────────────────────────────────────────
          const _SectionLabel(icon: Icons.photo_library_rounded, text: 'Ürün Görselleri (Maks 3)'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ImgSlot(
              label: 'Ana Görsel *', newFile: img,
              existingUrl: existingImgUrl, onTap: () => onPickImg(1),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ImgSlot(
              label: '2. Görsel', newFile: img2,
              existingUrl: existingImg2Url, onTap: () => onPickImg(2),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ImgSlot(
              label: '3. Görsel', newFile: img3,
              existingUrl: existingImg3Url, onTap: () => onPickImg(3),
            )),
          ]),
          const SizedBox(height: 18),

          // ── TEMEL BİLGİLER ────────────────────────────────────────────────
          const _SectionLabel(icon: Icons.info_outline_rounded, text: 'Ürün Bilgileri'),
          const SizedBox(height: 10),
          _DField(ctrl: adCtrl, label: 'Ürün Adı *', hint: 'Örn: Pamuklu Tişört'),
          _DField(ctrl: descCtrl, label: 'Açıklama',
              hint: 'Ürün özellikleri, kumaş bilgisi vb. detayları yazın...', maxLines: 3),

          // ── FİYAT ─────────────────────────────────────────────────────────
          const _SectionLabel(icon: Icons.sell_rounded, text: 'Fiyat'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DField(ctrl: fiyatCtrl, label: 'Fiyat (₺) *',
                hint: '100.00',
                keyboard: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(child: _DField(ctrl: eskiCtrl, label: 'Eski Fiyat (₺)',
                hint: '150.00',
                keyboard: const TextInputType.numberWithOptions(decimal: true))),
          ]),

          // ── STOK & BEDEN ──────────────────────────────────────────────────
          const _SectionLabel(icon: Icons.inventory_2_rounded, text: 'Stok & Beden'),
          const SizedBox(height: 10),

          // Giyim kategorisi → beden yönetimi
          if (isGiyim) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Beden & Stok Yönetimi',
                    style: TextStyle(color: _kText, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Her beden için adet girin — toplam stok otomatik hesaplanır',
                    style: TextStyle(color: _kMuted, fontSize: 10)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF59E0B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFF59E0B).withOpacity(0.35)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 15),
                    SizedBox(width: 7),
                    Expanded(child: Text(
                      'Beden düzenlemesinden sonra mutlaka "Güncelle" butonuna basın.',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                ...List.generate(sizeRows.length, (i) {
                  final row = sizeRows[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(flex: 2, child: _DField(
                        ctrl: row['name']!, label: 'Beden', hint: 'S, M, L...',
                        onChanged: (_) => onSizeChanged?.call(),
                      )),
                      const SizedBox(width: 8),
                      Expanded(flex: 1, child: _DField(
                        ctrl: row['stock']!, label: 'Adet', hint: '0',
                        keyboard: TextInputType.number,
                        onChanged: (_) => onSizeChanged?.call(),
                      )),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onRemoveSize?.call(i),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: _kDanger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kDanger.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.close_rounded, color: _kDanger, size: 16),
                        ),
                      ),
                    ]),
                  );
                }),
                GestureDetector(
                  onTap: onAddSize,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kAccent.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_rounded, color: _kAccent, size: 16),
                      SizedBox(width: 6),
                      Text('Yeni Beden Ekle',
                          style: TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],

          // Toplam stok
          _DField(ctrl: stokCtrl, label: isGiyim ? 'Toplam Stok (otomatik)' : 'Toplam Stok',
              hint: '50', keyboard: TextInputType.number),
          const SizedBox(height: 18),

          // ── VİDEO ─────────────────────────────────────────────────────────
          const _SectionLabel(icon: Icons.videocam_rounded, text: 'Ürün Videosu (İsteğe Bağlı)'),
          const SizedBox(height: 8),

          // Mevcut video varsa göster + kaldır butonu
          if (existingVideoUrl != null && existingVideoUrl!.isNotEmpty && !removeVideo)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPurple.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.videocam_rounded, color: _kPurple, size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mevcut video mevcut', style: TextStyle(color: _kText, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('Kaldırmak veya yenisiyle değiştirmek için aşağıyı kullanın',
                      style: TextStyle(color: _kMuted, fontSize: 10)),
                ])),
                GestureDetector(
                  onTap: onRemoveVideo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kDanger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kDanger.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.delete_outline_rounded, color: _kDanger, size: 14),
                      SizedBox(width: 4),
                      Text('Kaldır', style: TextStyle(color: _kDanger, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ),

          if (removeVideo)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kDanger.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kDanger.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: _kDanger, size: 14),
                SizedBox(width: 6),
                Text('Video kaydedildiğinde silinecek', style: TextStyle(color: _kDanger, fontSize: 11)),
              ]),
            ),

          GestureDetector(
            onTap: onPickVideo,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: video != null ? _kPurple : _kBorder,
                  width: video != null ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  video != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                  color: video != null ? _kPurple : _kMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    video != null
                        ? video!.path.split('/').last
                        : 'Yeni video seç (MP4, MOV, AVI vb.)',
                    style: TextStyle(
                      color: video != null ? _kPurple : _kMuted,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text('Maksimum 50MB • Tüm video formatları desteklenir',
                      style: TextStyle(color: _kMuted, fontSize: 10)),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // ── KAYDET BUTONLARI ──────────────────────────────────────────────
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: sending ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                disabledBackgroundColor: _kAccent.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: sending
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.save_rounded, color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(onSubmitAndNew != null ? 'Ürünü Kaydet' : 'Güncelle',
                          style: const TextStyle(color: Colors.black, fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ]),
            ),
          ),
          if (onSubmitAndNew != null) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 48,
              child: OutlinedButton(
                onPressed: sending ? null : onSubmitAndNew,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAccent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle_outline_rounded, color: _kAccent, size: 16),
                  const SizedBox(width: 8),
                  const Text('⚡ Kaydet ve Yeni Ekle',
                      style: TextStyle(color: _kAccent, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ])),
      ]),
    );
  }
}

// ─── MAĞAZAMI GÖR BUTONU ─────────────────────────────────────────────────────
class _MagazamiGorBtn extends StatefulWidget {
  final int storeId;
  final String username;
  const _MagazamiGorBtn({required this.storeId, required this.username});
  @override
  State<_MagazamiGorBtn> createState() => _MagazamiGorBtnState();
}

class _MagazamiGorBtnState extends State<_MagazamiGorBtn> {
  bool _loading = false;

  Future<void> _git() async {
    setState(() => _loading = true);
    try {
      final magaza = await pub_api.ApiService.getMagazaById(widget.storeId);
      if (!mounted) return;
      if (magaza == null) {
        _snack('Mağaza bilgisi bulunamadı');
        return;
      }
      final slug = magaza['slug']?.toString() ?? '${widget.storeId}';
      final ad   = magaza['name']?.toString()
          ?? magaza['ad']?.toString()
          ?? widget.username;
      Color renk = _kAccent;
      try {
        final renkStr = magaza['renk']?.toString() ?? magaza['color']?.toString() ?? '';
        if (renkStr.isNotEmpty) {
          renk = Color(int.parse(renkStr.replaceAll('#', '0xFF')));
        }
      } catch (_) {}

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UrunlerScreen(
            storeId:    widget.storeId,
            magazaSlug: slug,
            magazaAdi:  ad,
            renk:       renk,
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack('Bağlantı hatası');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
        backgroundColor: _kDanger,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _loading ? null : _git,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: _kSuccess.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kSuccess.withOpacity(0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _loading
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: _kSuccess, strokeWidth: 2))
            : const Icon(Icons.storefront_rounded, color: _kSuccess, size: 16),
        const SizedBox(width: 8),
        const Text('Mağazamı Gör',
            style: TextStyle(color: _kSuccess, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios_rounded, color: _kSuccess, size: 10),
      ]),
    ),
  );
}

// ─── GÖRSEL SLOT ─────────────────────────────────────────────────────────────
class _ImgSlot extends StatelessWidget {
  final String label;
  final File? newFile;
  final String? existingUrl;
  final VoidCallback onTap;
  const _ImgSlot({required this.label, this.newFile, this.existingUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasNew      = newFile != null;
    final hasExisting = existingUrl != null && existingUrl!.isNotEmpty;
    final hasAny      = hasNew || hasExisting;

    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: _kCard, borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasAny ? _kAccent : _kBorder,
                width: hasAny ? 2 : 1,
                style: hasAny ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: hasNew
                  ? Image.file(newFile!, fit: BoxFit.cover, width: double.infinity)
                  : hasExisting
                      ? Stack(fit: StackFit.expand, children: [
                          CachedNetworkImage(imageUrl: existingUrl!, fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5)),
                              errorWidget: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined, color: _kMuted)),
                          Positioned(bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              color: Colors.black54,
                              child: const Text('Değiştir',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            )),
                        ])
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 28, color: _kMuted),
                          SizedBox(height: 4),
                          Text('Ekle', style: TextStyle(color: _kMuted, fontSize: 11)),
                        ]),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _kMuted, fontSize: 10,
            fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── SECTION LABEL ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: _kAccent, size: 14),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(color: _kAccent, fontSize: 12,
        fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// YARDIMCI WİDGET'LAR
// ═══════════════════════════════════════════════════════════════════════════════

class _BentoCard extends StatelessWidget {
  final Widget child; final Color? borderTop;
  const _BentoCard({required this.child, this.borderTop});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14),
        border: Border(
          top:    BorderSide(color: borderTop ?? _kBorder, width: borderTop != null ? 2 : 1),
          left:   const BorderSide(color: _kBorder),
          right:  const BorderSide(color: _kBorder),
          bottom: const BorderSide(color: _kBorder),
        )),
    child: child,
  );
}

class _BentoContent extends StatelessWidget {
  final String label, value, desc;
  final Color? valueColor;
  final String? badge, btnLabel;
  final VoidCallback? onBtnTap;
  const _BentoContent({required this.label, required this.value, required this.desc,
      this.valueColor, this.badge, this.btnLabel, this.onBtnTap});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        Flexible(child: Text(label, style: const TextStyle(color: _kMuted, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 0.5))),
        if (badge != null) ...[
          const SizedBox(width: 5),
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: _kDanger, borderRadius: BorderRadius.circular(4)),
            child: Text(badge!, style: const TextStyle(color: Colors.white,
                fontSize: 8, fontWeight: FontWeight.w800))),
        ],
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: valueColor ?? _kText,
            fontSize: 22, fontWeight: FontWeight.w800)),
        Text(desc, style: const TextStyle(color: _kMuted, fontSize: 10, height: 1.2)),
      ]),
      if (btnLabel != null)
        GestureDetector(onTap: onBtnTap,
          child: Container(width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(7)),
            child: Text(btnLabel!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800))))
      else const SizedBox(),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16), const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ])));
}

class _BottomNav extends StatelessWidget {
  final int aktif; final int siparisBadge; final Function(int) onTap;
  const _BottomNav({required this.aktif, required this.siparisBadge, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Color(0xFF0A0F1E),
        border: Border(top: BorderSide(color: _kBorder))),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _NavI(Icons.dashboard_rounded,    'Dashboard',  0, aktif, 0,            onTap),
        _NavI(Icons.receipt_long_rounded, 'Siparişler', 1, aktif, siparisBadge, onTap),
        _NavI(Icons.inventory_2_rounded,  'Ürünler',    2, aktif, 0,            onTap),
      ]),
    )),
  );
}

class _NavI extends StatelessWidget {
  final IconData icon; final String label; final int index, aktif, badge; final Function(int) onTap;
  const _NavI(this.icon, this.label, this.index, this.aktif, this.badge, this.onTap);
  @override
  Widget build(BuildContext context) {
    final on = index == aktif;
    return GestureDetector(onTap: () => onTap(index),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: on ? _kAccent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, color: on ? _kAccent : _kMuted, size: 21),
            if (badge > 0) Positioned(
              top: -4, right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _kDanger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: on ? _kAccent : _kMuted,
              fontSize: 10, fontWeight: FontWeight.w600)),
        ])));
  }
}

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11,
        fontWeight: FontWeight.w800, letterSpacing: 0.5)));
}

class _StatusChip extends StatelessWidget {
  final String label, value, aktif; final Function(String) onTap;
  const _StatusChip(this.label, this.value, this.aktif, this.onTap);
  @override
  Widget build(BuildContext context) {
    final sel = value == aktif;
    return GestureDetector(onTap: () => onTap(value),
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _kAccent.withOpacity(0.15) : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _kAccent : _kBorder)),
        child: Text(label, style: TextStyle(color: sel ? _kAccent : _kMuted,
            fontSize: 12, fontWeight: FontWeight.w600))));
  }
}

class _DeliveryBadge extends StatelessWidget {
  final String type; final double fee;
  const _DeliveryBadge({required this.type, required this.fee});
  @override
  Widget build(BuildContext context) {
    final isReturn = type == 'returnable';
    final color = isReturn ? Colors.purple : const Color(0xFFFF6000);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isReturn ? Icons.rotate_left_rounded : Icons.local_shipping_rounded,
            color: color, size: 13),
        const SizedBox(width: 5),
        Text((isReturn ? 'İadeli' : 'Standart') + (fee > 0 ? ' ($fee ₺)' : ''),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]));
  }
}

class _ProductRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProductRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final imgUrl  = item['image_url']?.toString() ?? '';
    final hasImg  = imgUrl.isNotEmpty;
    final hasSizes = (item['sizes'] ?? '').toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        // Ürün görseli
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: hasImg
              ? CachedNetworkImage(
                  imageUrl: imgUrl,
                  width: 64, height: 64,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const _NoImg(height: 64, width: 64),
                  errorWidget: (_, __, ___) => const _NoImg(height: 64, width: 64),
                )
              : const _NoImg(height: 64, width: 64),
        ),
        const SizedBox(width: 12),
        // Ürün bilgileri
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['product_name']?.toString() ?? '',
              style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(children: [
              Text(
                '${item['price']} ₺',
                style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Text('  ×  ', style: TextStyle(color: _kMuted, fontSize: 12)),
              Text(
                '${item['quantity']}',
                style: const TextStyle(color: _kMuted, fontSize: 12),
              ),
            ]),
            if (hasSizes) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: _kAccent, borderRadius: BorderRadius.circular(6)),
                child: Text(item['sizes']?.toString() ?? '',
                    style: const TextStyle(
                        color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        )),
        // Adet rozeti
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text('${item['quantity']}x',
              style: const TextStyle(
                  color: _kAccent, fontSize: 14, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _NoImg extends StatelessWidget {
  final double height; final double? width;
  const _NoImg({required this.height, this.width});
  @override
  Widget build(BuildContext context) => Container(
    width: width ?? double.infinity, height: height, color: _kBg,
    child: const Center(child: Icon(Icons.image_not_supported_outlined, color: _kMuted, size: 22)));
}

class _StokBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool loading;
  const _StokBtn({required this.icon, required this.onTap, required this.loading});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(width: 30, height: 30,
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder)),
      child: Icon(icon, color: _kText, size: 15)));
}

Widget _SmBtn(String label, Color bg, Color fg, VoidCallback onTap) =>
    GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)))));

class _DarkDialog extends StatelessWidget {
  final String title, content; final List<Widget> actions;
  const _DarkDialog({required this.title, required this.content, required this.actions});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _kCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title, style: const TextStyle(color: _kText, fontWeight: FontWeight.w800)),
    content: Text(content, style: const TextStyle(color: _kMuted)),
    actions: actions);
}

class _DarkDialogBtn extends StatelessWidget {
  final String label; final bool danger; final VoidCallback onTap;
  const _DarkDialogBtn(this.label, {required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => TextButton(onPressed: onTap,
    child: Text(label, style: TextStyle(color: danger ? _kDanger : _kMuted,
        fontWeight: FontWeight.w700)));
}

class _DField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final String? hint;
  final TextInputType? keyboard; final int maxLines;
  final void Function(String)? onChanged;
  const _DField({required this.ctrl, required this.label, this.hint,
      this.keyboard, this.maxLines = 1, this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl, keyboardType: keyboard, maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: _kText, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: _kMuted, fontSize: 12),
        hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
        filled: true, fillColor: _kCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kAccent, width: 1.5)),
      )));
}
