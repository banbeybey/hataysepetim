import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';
import 'magazalar_screen.dart';

const _yeniKategoriler = [
  'hediye-paketi-cicekcilik',
  'kasap-tavukculuk',
  'kucuk-ev-aletleri-elektronik',
  'alisverismerkezleri',
  'mobil-teknik-servis',
];

// ══════════════════════════════════════════════════════════════════════════════
// PAYLAŞIMLI ANİMASYON CONTROLLER — InheritedWidget
//
// Tüm _MagazaRozeti ve _YeniKategoriBadge widget'ları aynı 2 controller'ı
// paylaşır. 20 kart × 2 rozet = 40 controller yerine sadece 2 controller
// tick atar. Kart giriş controller'ları da parent'ta — her kart ayrı açmaz.
// ══════════════════════════════════════════════════════════════════════════════
class _RozetAnimations extends InheritedWidget {
  final Animation<double> float; // badgeFloat — 2.5s reverse
  final Animation<double> glow;  // newBadgeGlow + Shift — 3s repeat

  const _RozetAnimations({
    required this.float,
    required this.glow,
    required super.child,
  });

  static _RozetAnimations of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RozetAnimations>()!;

  @override
  bool updateShouldNotify(_RozetAnimations old) => false; // referans değişmez
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class KategorilerScreen extends StatefulWidget {
  const KategorilerScreen({super.key});
  @override
  State<KategorilerScreen> createState() => _KategorilerScreenState();
}

class _KategorilerScreenState extends State<KategorilerScreen>
    with TickerProviderStateMixin {
  List<dynamic> _kategoriler = [];
  bool _yukleniyor = true;

  late final AnimationController _headerCtrl;

  // Sadece 2 controller tüm rozet animasyonları için
  late final AnimationController _floatCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _yukle();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final data = await ApiService.getKategoriler();
      if (mounted) {
        setState(() {
          _kategoriler = data;
          _yukleniyor = false;
        });
        _headerCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RozetAnimations(
      float: _floatCtrl,
      glow: _glowCtrl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: RefreshIndicator(
          color: const Color(0xFFFF8C00),
          onRefresh: _yukle,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(controller: _headerCtrl),
              ),
              if (_yukleniyor)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _KategoriKart(
                        kategori: _kategoriler[i],
                        index: i,
                      ),
                      childCount: _kategoriler.length,
                      addRepaintBoundaries: true,
                      addAutomaticKeepAlives: false,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.74,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final AnimationController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 28,
          bottom: 36,
        ),
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFF4500), Color(0xFFFF8C00), Color(0xFFFFAA00)],
                  ).createShader(bounds),
                  child: const Text(
                    'HATAYSEPETIM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF2BDC6B), Color(0xFF00FA9A), Color(0xFF2BDC6B)],
                  ).createShader(bounds),
                  child: const Text(
                    'REYHANLI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'KATEGORİLER',
                    style: TextStyle(
                      color: Color(0xFF86868B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}





// ══════════════════════════════════════════════════════════════════════════════
// KATEGORİ KARTI
// ══════════════════════════════════════════════════════════════════════════════
class _KategoriKart extends StatefulWidget {
  final Map<String, dynamic> kategori;
  final int index;
  const _KategoriKart({required this.kategori, required this.index});
  @override
  State<_KategoriKart> createState() => _KategoriKartState();
}

class _KategoriKartState extends State<_KategoriKart>
    with SingleTickerProviderStateMixin {
  // Sadece giriş animasyonu — biter, stop edilir
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 60 + widget.index * 70), () {
      if (mounted) {
        // Animasyon bitince controller'ı durdur — CPU tasarrufu
        _entryCtrl.forward().then((_) {
          if (mounted) _entryCtrl.stop();
        });
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Color get _renk {
    try {
      return Color(int.parse(
        (widget.kategori['renk']?.toString() ?? '#FF8C00')
            .replaceAll('#', '0xFF'),
      ));
    } catch (_) {
      return const Color(0xFFFF8C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = _renk;
    final gorselUrl = widget.kategori['gorsel_url']?.toString();
    final magazaSayisi =
        int.tryParse(widget.kategori['magaza_sayisi']?.toString() ?? '0') ??
            0;
    final isYeni =
        _yeniKategoriler.contains(widget.kategori['slug']?.toString());
    final isTeknik = widget.kategori['slug']?.toString() == 'mobil-teknik-servis';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            final slug = widget.kategori['slug']?.toString() ?? '';
            if (slug == 'mobil-teknik-servis') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const _TeknikServisScreen(),
                ),
              );
            } else {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, a, __) => MagazalarScreen(
                    kategoriSlug: widget.kategori['slug'],
                    kategoriAdi: widget.kategori['ad'],
                    renk: renk,
                  ),
                  transitionsBuilder: (_, a, __, child) =>
                      FadeTransition(opacity: a, child: child),
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            }
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: _pressed
                    ? [
                        BoxShadow(
                          color: renk.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: renk.withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  children: [

                    // ── ROZET SATIRI — kartın tepesi
                    // RepaintBoundary: rozet animasyonları sadece bu küçük
                    // alanı yeniden çizer, kartın görsel + metin kısımlarına
                    // dokunmaz
                    if (magazaSayisi > 0 || isYeni)
                      RepaintBoundary(
                        child: Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                          child: isTeknik
                              // TEKNİK SERVİS: 2 satır — overflow riski yok
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        if (magazaSayisi > 0)
                                          _MagazaRozeti(sayi: magazaSayisi),
                                        const Spacer(),
                                        if (isYeni)
                                          const _YeniKategoriBadge(),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    const Align(
                                      alignment: Alignment.centerRight,
                                      child: _TeknikServisBadge(),
                                    ),
                                  ],
                                )
                              // Normal kategoriler: tek satır
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (magazaSayisi > 0)
                                      _MagazaRozeti(sayi: magazaSayisi),
                                    const Spacer(),
                                    if (isYeni) const _YeniKategoriBadge(),
                                  ],
                                ),
                        ),
                      ),

                    // ── GÖRSEL (%70)
                    Expanded(
                      flex: 70,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (gorselUrl != null)
                            CachedNetworkImage(
                              imageUrl: gorselUrl,
                              fit: BoxFit.cover,
                              // Küçük kart (~160px) için 2× decode — büyük
                              // görselleri küçük boyutta tut, bellek ve GPU yükü azalır
                              memCacheWidth: 320,
                              placeholder: (_, __) => Container(
                                color: renk.withOpacity(0.12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: renk,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) =>
                                  _GradientBg(renk: renk),
                            )
                          else
                            _GradientBg(renk: renk),

                          // Statik karartma — repaint yok
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.65),
                                  ],
                                  stops: const [0.45, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── BEYAZ ALT ALAN (%30) — tamamen statik
                    Expanded(
                      flex: 30,
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.kategori['ad']?.toString() ?? '',
                              style: const TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 26,
                              height: 3,
                              decoration: BoxDecoration(
                                color: renk,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBg extends StatelessWidget {
  final Color renk;
  const _GradientBg({required this.renk});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [renk.withOpacity(0.8), renk.withOpacity(0.35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// MAĞAZA ROZETİ — StatelessWidget, kendi controller'ı YOK
// Paylaşımlı _floatCtrl'i InheritedWidget üzerinden alır
// ══════════════════════════════════════════════════════════════════════════════
class _MagazaRozeti extends StatelessWidget {
  final int sayi;
  const _MagazaRozeti({required this.sayi});

  @override
  Widget build(BuildContext context) {
    final anim = _RozetAnimations.of(context);

    return AnimatedBuilder(
      animation: anim.float,
      // child sabit → her frame rebuild edilmez, sadece Transform güncellenir
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🛍️', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            '$sayi MAĞAZA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
      builder: (_, child) {
        final v = anim.float.value;
        final offset = math.sin(v * math.pi) * 3.0;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8C00).withOpacity(0.4),
                  blurRadius: 8 + v * 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// YENİ KATEGORİ ROZETİ — StatelessWidget, kendi controller'ı YOK
// Paylaşımlı _glowCtrl'i InheritedWidget üzerinden alır
// ══════════════════════════════════════════════════════════════════════════════
class _YeniKategoriBadge extends StatelessWidget {
  const _YeniKategoriBadge();

  @override
  Widget build(BuildContext context) {
    final anim = _RozetAnimations.of(context);

    return AnimatedBuilder(
      animation: anim.glow,
      // Statik metin child — rebuild edilmez
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✦',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w900)),
          SizedBox(width: 3),
          Text('YENİ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                height: 1,
              )),
        ],
      ),
      builder: (_, child) {
        final t = anim.glow.value;
        final glow = (math.sin(t * math.pi * 2 * 1.5) + 1) / 2;
        final glowOpacity = 0.45 + glow * 0.40;
        final glowBlur = 8.0 + glow * 10.0;

        final rawStops = [
          (0.0 + t * 0.5) % 1.0,
          (0.33 + t * 0.5) % 1.0,
          (0.67 + t * 0.5) % 1.0,
          (1.0 + t * 0.5) % 1.0,
        ]..sort();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Color(0xFFa855f7),
                Color(0xFFec4899),
                Color(0xFFf97316),
                Color(0xFFa855f7),
              ],
              stops: rawStops,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              tileMode: TileMode.mirror,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFa855f7).withOpacity(glowOpacity),
                blurRadius: glowBlur,
              ),
              BoxShadow(
                color:
                    const Color(0xFFec4899).withOpacity(glowOpacity * 0.6),
                blurRadius: glowBlur * 1.3,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// TEKNİK SERVİS ROZET — mavi, statik (animasyon gerekmez)
// ══════════════════════════════════════════════════════════════════════════════
class _TeknikServisBadge extends StatelessWidget {
  const _TeknikServisBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔧', style: TextStyle(fontSize: 7)),
          SizedBox(width: 3),
          Text(
            'TEKNİK SERVİS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// TEKNİK SERVİS EKRANI — emirteknik.php WebView
// ══════════════════════════════════════════════════════════════════════════════
class _TeknikServisScreen extends StatefulWidget {
  const _TeknikServisScreen();
  @override
  State<_TeknikServisScreen> createState() => _TeknikServisScreenState();
}

class _TeknikServisScreenState extends State<_TeknikServisScreen> {
  WebViewController? _controller;
  bool _yukleniyor = true;

  static const _url = 'https://reyhanli.hataysepetim.com.tr/emirteknik.php';
  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  void _yukle() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
      ..setBackgroundColor(const Color(0xFF08090A))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _yukleniyor = true),
        onPageFinished: (_) {
          setState(() => _yukleniyor = false);
        },
        onWebResourceError: (_) => setState(() => _yukleniyor = false),
        onNavigationRequest: (req) => NavigationDecision.navigate,
      ))
      ..loadRequest(Uri.parse(_url));

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08090A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mobil Teknik Servis',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: _controller == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_yukleniyor)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  ),
              ],
            ),
    );
  }
}
