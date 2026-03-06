import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';
import 'urunler_screen.dart';

// Slug → store_id önbelleği (uygulama ömrünce geçerli)
final Map<String, int> _slugIdCache = {};

class MagazalarScreen extends StatefulWidget {
  final String kategoriSlug;
  final String kategoriAdi;
  final Color renk;

  const MagazalarScreen({
    super.key,
    required this.kategoriSlug,
    required this.kategoriAdi,
    required this.renk,
  });

  @override
  State<MagazalarScreen> createState() => _MagazalarScreenState();
}

class _MagazalarScreenState extends State<MagazalarScreen> {
  WebViewController? _controller;
  bool _yukleniyor = true;

  static const _baseHost = 'reyhanli.hataysepetim.com.tr';
  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  // Sayfa yüklenir yüklenmez inject edilecek CSS
  static const _hideCSS = '''
    (function() {
      var style = document.createElement('style');
      style.textContent = `
        .btn-admin-panel,
        .floating-stats,
        .leaves-container,
        .action-buttons-grid {
          display: none !important;
        }
        body {
          zoom: 1 !important;
          -moz-transform: none !important;
          transform: none !important;
        }
      `;
      document.head.appendChild(style);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final token = await ApiService.getToken();
    final url = 'https://$_baseHost/${widget.kategoriSlug}-magazalari';
    final uri = token != null
        ? Uri.parse('$url?token=${Uri.encodeComponent(token)}')
        : Uri.parse(url);

    final screenWidth =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
      ..setBackgroundColor(const Color(0xFF08090A))
      ..addJavaScriptChannel(
        'FlutterMagaza',
        onMessageReceived: (msg) async {
          final parts = msg.message.split('|');
          if (parts.length >= 2) {
            final slug      = parts[0];
            final storeName = parts[1];

            // Önbellekte varsa direkt kullan
            int storeId = _slugIdCache[slug] ?? 0;

            // Yoksa API'den çek — kategori mağazalarını getir, slug ile eşleştir
            if (storeId == 0) {
              try {
                final magazalar = await ApiService.getMagazalar(
                  category: widget.kategoriSlug,
                );
                for (final m in magazalar) {
                  final mSlug = m['slug']?.toString() ?? '';
                  final mId   = int.tryParse('${m['id']}') ?? 0;
                  if (mId > 0 && mSlug.isNotEmpty) {
                    _slugIdCache[mSlug] = mId;
                  }
                  if (mSlug == slug) storeId = mId;
                }
                // slug alanı yoksa name'den deneme (fallback)
                if (storeId == 0) {
                  for (final m in magazalar) {
                    final mId = int.tryParse('${m['id']}') ?? 0;
                    if (mId > 0) { storeId = mId; break; } // bulunamazsa ilkini al
                  }
                }
              } catch (_) {}
            }

            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UrunlerScreen(
                  magazaSlug: slug,
                  magazaAdi:  storeName,
                  renk:       widget.renk,
                  storeId:    storeId,
                ),
              ),
            );
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          setState(() => _yukleniyor = true);
          _controller?.runJavaScript(_hideCSS);
        },
        onPageFinished: (_) {
          _controller?.runJavaScript('''
            // CSS tekrar uygula
            (function() {
              var style = document.createElement('style');
              style.textContent = '.btn-admin-panel,.floating-stats,.leaves-container,.action-buttons-grid{display:none!important}body{zoom:1!important;transform:none!important}';
              document.head.appendChild(style);
            })();

            // Viewport zorla
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; document.head.appendChild(meta); }
            meta.content = 'width=${screenWidth.toInt()}, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

            // Yaprak animasyonunu durdur
            var zone = document.getElementById('leafZone');
            if (zone) zone.innerHTML = '';

            // Tüm store-card linklerine tıklama ekle
            document.querySelectorAll('a.store-card').forEach(function(card) {
              card.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                var href = card.getAttribute('href') || '';
                var slug = '';
                if (href.includes('/magaza/')) {
                  slug = href.split('/magaza/')[1].split('?')[0].split('#')[0];
                } else if (href.includes('store=')) {
                  slug = href.split('store=')[1].split('&')[0];
                }
                var nameEl = card.querySelector('.store-title');
                var storeName = nameEl ? nameEl.textContent.trim() : slug;
                if (slug) FlutterMagaza.postMessage(slug + '|' + storeName);
              }, true);
            });
          ''');
          setState(() => _yukleniyor = false);
        },
        onWebResourceError: (_) => setState(() => _yukleniyor = false),
        onNavigationRequest: (request) {
          final uri = Uri.parse(request.url);
          // Sadece mağazalar sayfasına izin ver
          if (uri.host == _baseHost && uri.path.contains('-magazalari')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(uri);

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08090A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.kategoriAdi,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _controller == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_yukleniyor)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
                  ),
              ],
            ),
    );
  }
}
