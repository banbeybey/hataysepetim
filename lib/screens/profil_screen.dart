import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/kullanici_provider.dart';
import '../providers/kurumsal_provider.dart';
import '../services/api_service.dart';
import 'giris_screen.dart';
import 'bildirimler_screen.dart';
import 'gizlilik_politikasi_screen.dart';
import 'siparislerim_screen.dart';
import 'kurumsal_giris_screen.dart';
import 'kurumsal_panel_screen.dart';

// ─── Renk Paleti ────────────────────────────────────────────────────────────
const _turuncu1 = Color(0xFFFF4500);
const _turuncu2 = Color(0xFFFF8C00);
const _arkaplan = Color(0xFFF2F3F7);
const _kart     = Colors.white;

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kullanici = context.watch<KullaniciProvider>();
    if (!kullanici.girisYapildi) return const _GirisYapScreen();
    return const _ProfilIcerigi();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANA PROFİL EKRANI
// ═══════════════════════════════════════════════════════════════════════════

class _ProfilIcerigi extends StatelessWidget {
  const _ProfilIcerigi();

  @override
  Widget build(BuildContext context) {
    final k = context.watch<KullaniciProvider>();
    final kurumsal = context.watch<KurumsalProvider>();
    final ad = k.kullanici?['full_name'] ?? '';
    final tel = k.kullanici?['phone'] ?? '';
    final adres = k.kullanici?['address'] ?? '';
    final initials = _initials(ad);
    // Kurumsal giriş varsa o mağazanın logosu, yoksa null
    final logoUrl = kurumsal.girisYapildi ? kurumsal.logoUrl : null;

    return Scaffold(
      backgroundColor: _arkaplan,
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: false,
            backgroundColor: const Color(0xFF0F3460),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => _cikisOnay(context),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(color: Colors.black),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Logo — tam arka plan, blur yok
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Hafif karartma — yazılar okunabilsin
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                    // Profil içeriği — sol altta
                    Positioned(
                      left: 24, right: 24, bottom: 28,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar dairesi
                          Container(
                            width: 76, height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_turuncu1, _turuncu2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _turuncu1.withOpacity(0.5),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                              border: Border.all(color: Colors.white.withOpacity(0.25), width: 2.5),
                            ),
                            child: logoUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: logoUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Center(
                                        child: Text(initials,
                                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(initials,
                                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(ad,
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 20,
                                    fontWeight: FontWeight.w900, letterSpacing: 0.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _InfoChip(icon: Icons.phone_outlined, text: tel),
                                    if (adres.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      _InfoChip(icon: Icons.location_on_outlined, text: adres, maxWidth: 100),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Hızlı Eylemler (chip row) ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                children: [
                  _HizliButon(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Siparişlerim',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiparislerimScreen(
                          phone: context.read<KullaniciProvider>().kullanici?['phone'] ?? '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HizliButon(
                    icon: Icons.edit_outlined,
                    label: 'Düzenle',
                    onTap: () => _bilgiDuzenleSheet(context),
                  ),
                  const SizedBox(width: 12),
                  _HizliButon(
                    icon: Icons.lock_outline,
                    label: 'Şifre',
                    onTap: () => _sifreDegistirSheet(context),
                  ),
                ],
              ),
            ),
          ),

          // ── Hesap Bölümü ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _SectionHeader('Hesap'),
            ),
          ),
          SliverToBoxAdapter(
            child: _MenuGrubu(
              children: [
                _MenuSatiri(
                  icon: Icons.shopping_bag_outlined,
                  iconRenk: _turuncu1,
                  baslik: 'Siparişlerim',
                  altyazi: 'Geçmiş ve aktif siparişler',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SiparislerimScreen(
                        phone: context.read<KullaniciProvider>().kullanici?['phone'] ?? '',
                      ),
                    ),
                  ),
                ),
                _MenuAyirici(),
                _MenuSatiri(
                  icon: Icons.person_outline,
                  iconRenk: const Color(0xFF0EA5E9),
                  baslik: 'Bilgileri Düzenle',
                  altyazi: 'Ad, telefon, adres',
                  onTap: () => _bilgiDuzenleSheet(context),
                ),
                _MenuAyirici(),
                _MenuSatiri(
                  icon: Icons.lock_outline,
                  iconRenk: const Color(0xFF8B5CF6),
                  baslik: 'Şifre Değiştir',
                  altyazi: 'Hesap güvenliği',
                  onTap: () => _sifreDegistirSheet(context),
                ),
              ],
            ),
          ),

          // ── Kurumsal Bölüm ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _SectionHeader('Kurumsal'),
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer<KurumsalProvider>(
              builder: (ctx, kurumsal, _) => _MenuGrubu(
                children: [
                  _MenuSatiri(
                    icon: Icons.storefront_rounded,
                    iconRenk: const Color(0xFF5B5BD6),
                    baslik: kurumsal.girisYapildi ? 'Mağaza Paneli' : 'Kurumsal Giriş',
                    altyazi: kurumsal.girisYapildi
                        ? '${kurumsal.username ?? ""} olarak giriş yapıldı'
                        : 'Mağaza sahipleri için',
                    onTap: () {
                      if (kurumsal.girisYapildi) {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const KurumsalPanelScreen()));
                      } else {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const KurumsalGirisScreen()));
                      }
                    },
                    rozet: kurumsal.girisYapildi
                        ? _Rozet(metin: 'Aktif', renk: Colors.green)
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // ── Diğer Bölüm ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _SectionHeader('Diğer'),
            ),
          ),
          SliverToBoxAdapter(
            child: _MenuGrubu(
              children: [
                _MenuSatiri(
                  icon: Icons.help_outline,
                  iconRenk: const Color(0xFF10B981),
                  baslik: 'Yardım & Destek',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DestekScreen())),
                ),
                _MenuAyirici(),
                _MenuSatiri(
                  icon: Icons.info_outline,
                  iconRenk: const Color(0xFFF59E0B),
                  baslik: 'Hakkımızda',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _HakkindaScreen())),
                ),
                _MenuAyirici(),
                _MenuSatiri(
                  icon: Icons.shield_outlined,
                  iconRenk: const Color(0xFF6B7280),
                  baslik: 'Gizlilik Politikası',
                  altyazi: 'Veri kullanımı',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GizlilikPolitikasiScreen())),
                ),
              ],
            ),
          ),

          // ── Çıkış Butonu ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: GestureDetector(
                onTap: () => _cikisOnay(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  String _initials(String ad) {
    final parts = ad.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _cikisOnay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFFECEC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
            ),
            const SizedBox(height: 16),
            const Text('Çıkış Yap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('İptal', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<KullaniciProvider>().cikisYap();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _bilgiDuzenleSheet(BuildContext context) {
    final k = context.read<KullaniciProvider>();
    final adCtrl = TextEditingController(text: k.kullanici?['full_name'] ?? '');
    final adresCtrl = TextEditingController(text: k.kullanici?['address'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DuzenleSheet(
        baslik: 'Bilgileri Düzenle',
        icon: Icons.person_outline,
        iconRenk: const Color(0xFF0EA5E9),
        children: [
          _SheetAlan(ctrl: adCtrl, label: 'Ad Soyad', icon: Icons.person_outline),
          const SizedBox(height: 14),
          _SheetAlan(ctrl: adresCtrl, label: 'Adres', icon: Icons.location_on_outlined, maxLines: 2),
        ],
        onKaydet: (setState, yukleniyor) async {
          final ad = adCtrl.text.trim();
          if (ad.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ad Soyad boş olamaz'), behavior: SnackBarBehavior.floating),
            );
            return;
          }
          setState(() => yukleniyor = true);
          final sonuc = await ApiService.profilGuncelle(
            fullName: ad,
            address: adresCtrl.text.trim(),
          );
          if (sonuc['success'] == true) {
            await k.kullaniciBilgisiGuncelle({
              'id': k.kullanici?['id'],
              'full_name': ad,
              'phone': k.kullanici?['phone'],
              'address': adresCtrl.text.trim(),
            });
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Bilgileriniz güncellendi'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(sonuc['message'] ?? 'Hata oluştu'), behavior: SnackBarBehavior.floating),
              );
            }
          }
          setState(() => yukleniyor = false);
        },
      ),
    );
  }

  void _sifreDegistirSheet(BuildContext context) {
    final eskiCtrl   = TextEditingController();
    final yeniCtrl   = TextEditingController();
    final tekrarCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DuzenleSheet(
        baslik: 'Şifre Değiştir',
        icon: Icons.lock_outline,
        iconRenk: const Color(0xFF8B5CF6),
        children: [
          _SheetAlan(ctrl: eskiCtrl,   label: 'Mevcut Şifre', icon: Icons.lock_outline,      gizle: true),
          const SizedBox(height: 14),
          _SheetAlan(ctrl: yeniCtrl,   label: 'Yeni Şifre',   icon: Icons.lock_open_outlined, gizle: true),
          const SizedBox(height: 14),
          _SheetAlan(ctrl: tekrarCtrl, label: 'Yeni Şifre (Tekrar)', icon: Icons.lock_open_outlined, gizle: true),
        ],
        onKaydet: (setState, yukleniyor) async {
          final eski   = eskiCtrl.text;
          final yeni   = yeniCtrl.text;
          final tekrar = tekrarCtrl.text;
          if (eski.isEmpty || yeni.isEmpty || tekrar.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tüm alanları doldurun'), behavior: SnackBarBehavior.floating),
            );
            return;
          }
          if (yeni.length < 6) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Yeni şifre en az 6 karakter olmalı'), behavior: SnackBarBehavior.floating),
            );
            return;
          }
          if (yeni != tekrar) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Yeni şifreler eşleşmiyor'), behavior: SnackBarBehavior.floating),
            );
            return;
          }
          setState(() => yukleniyor = true);
          final sonuc = await ApiService.sifreGuncelle(eskiSifre: eski, yeniSifre: yeni);
          if (sonuc['success'] == true) {
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Şifreniz güncellendi'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(sonuc['message'] ?? 'Hata oluştu'), behavior: SnackBarBehavior.floating),
              );
            }
          }
          setState(() => yukleniyor = false);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// YARDIMCI WİDGET'LAR
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String baslik;
  const _SectionHeader(this.baslik);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        baslik.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _MenuGrubu extends StatelessWidget {
  final List<Widget> children;
  const _MenuGrubu({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _kart,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuAyirici extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 60, endIndent: 16, thickness: 0.5);
  }
}

class _Rozet extends StatelessWidget {
  final String metin;
  final Color renk;
  const _Rozet({required this.metin, required this.renk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        metin,
        style: TextStyle(color: renk, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _MenuSatiri extends StatelessWidget {
  final IconData icon;
  final Color iconRenk;
  final String baslik;
  final String? altyazi;
  final VoidCallback onTap;
  final Widget? rozet;

  const _MenuSatiri({
    required this.icon,
    required this.iconRenk,
    required this.baslik,
    required this.onTap,
    this.altyazi,
    this.rozet,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconRenk.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconRenk, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
                  if (altyazi != null)
                    Text(altyazi!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            if (rozet != null) ...[rozet!, const SizedBox(width: 8)],
            const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final double maxWidth;
  const _InfoChip({required this.icon, required this.text, this.maxWidth = 130});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 11),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HizliButon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HizliButon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kart,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_turuncu1, _turuncu2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(color: _turuncu1.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modern Bottom Sheet (Düzenle / Şifre) ────────────────────────────────────

class _DuzenleSheet extends StatefulWidget {
  final String baslik;
  final IconData icon;
  final Color iconRenk;
  final List<Widget> children;
  final Future<void> Function(StateSetter setState, bool yukleniyor) onKaydet;

  const _DuzenleSheet({
    required this.baslik,
    required this.icon,
    required this.iconRenk,
    required this.children,
    required this.onKaydet,
  });

  @override
  State<_DuzenleSheet> createState() => _DuzenleSheetState();
}

class _DuzenleSheetState extends State<_DuzenleSheet> {
  bool _yukleniyor = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tutma çubuğu
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Başlık
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: widget.iconRenk.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: widget.iconRenk, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  widget.baslik,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...widget.children,
            const SizedBox(height: 24),
            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _yukleniyor
                    ? null
                    : () => widget.onKaydet(setState, _yukleniyor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _turuncu2,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _yukleniyor
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kaydet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SheetAlan extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final bool gizle;
  const _SheetAlan({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.gizle = false,
  });

  @override
  State<_SheetAlan> createState() => _SheetAlanState();
}

class _SheetAlanState extends State<_SheetAlan> {
  late bool _gizleniyor;

  @override
  void initState() {
    super.initState();
    _gizleniyor = widget.gizle;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.ctrl,
      maxLines: widget.gizle ? 1 : widget.maxLines,
      obscureText: _gizleniyor,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, size: 20),
        suffixIcon: widget.gizle
            ? IconButton(
                icon: Icon(_gizleniyor ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _gizleniyor = !_gizleniyor),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _turuncu2, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GİRİŞ YAPILMAMIŞSA GÖSTER
// ═══════════════════════════════════════════════════════════════════════════

class _GirisYapScreen extends StatelessWidget {
  const _GirisYapScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaplan,
      appBar: AppBar(title: const Text('Hesabım')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),

          // Müşteri kartı
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_turuncu1, _turuncu2]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person_outline, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 18),
                const Text('Hesabınıza Giriş Yapın',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                  'Siparişlerinizi takip etmek ve hızlı alışveriş yapabilmek için giriş yapın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GirisScreen())),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: _turuncu1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Giriş Yap',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GirisScreen(kayitModu: true))),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: _turuncu2, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Kayıt Ol',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _turuncu2)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Kurumsal kart
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text('KURUMSAL', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: Colors.grey.shade400, letterSpacing: 1.4,
            )),
          ),
          Consumer<KurumsalProvider>(
            builder: (ctx, kurumsal, _) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (kurumsal.girisYapildi) {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const KurumsalPanelScreen()));
                  } else {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const KurumsalGirisScreen()));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF5B5BD6), Color(0xFF7C3AED)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            kurumsal.girisYapildi ? 'Mağaza Paneli' : 'Kurumsal Giriş',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            kurumsal.girisYapildi
                                ? '${kurumsal.username ?? ""} olarak giriş yapıldı'
                                : 'Mağaza sahipleri için',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// YARDIM & DESTEK (değişmedi — sadece kopyalandı)
// ═══════════════════════════════════════════════════════════════════════════

class _DestekScreen extends StatelessWidget {
  const _DestekScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaplan,
      appBar: AppBar(title: const Text('Yardım & Destek')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF4500).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.support_agent_rounded, color: Colors.white, size: 32),
                SizedBox(height: 10),
                Text('Size Nasıl Yardımcı Olabiliriz?',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Aşağıdaki kanallardan bize ulaşabilirsiniz.',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DestekKarti(icon: Icons.phone_rounded, renk: const Color(0xFF16a34a),
            baslik: 'Telefon', aciklama: 'Hafta içi 09:00 – 18:00', deger: '0551 344 52 95'),
          const SizedBox(height: 12),
          _DestekKarti(icon: Icons.language_rounded, renk: const Color(0xFF1d4ed8),
            baslik: 'Web Sitesi', aciklama: 'Online sipariş ve bilgi', deger: 'reyhanli.hataysepetim.com.tr'),
          const SizedBox(height: 12),
          _DestekKarti(icon: Icons.email_outlined, renk: const Color(0xFF7c3aed),
            baslik: 'E-posta', aciklama: 'En geç 24 saat içinde dönüş', deger: 'departman@hataysepetim.com.tr'),
          const SizedBox(height: 12),
          _DestekKarti(icon: Icons.location_on_rounded, renk: const Color(0xFFFF4500),
            baslik: 'Adres', aciklama: 'HataySepetim Reyhanlı Şubesi',
            deger: 'Yeni Mahalle, Şemsettin Mursaloğlu Cd.\n102. Sokak No:8, 31500 Reyhanlı/Hatay'),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('SIK SORULAN SORULAR',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1.2)),
          ),
          _SssKarti(
            soru: 'Siparişimi nasıl takip edebilirim?',
            cevap: 'Profil > Siparişlerim bölümünden tüm siparişlerinizi ve güncel durumlarını görebilirsiniz.',
          ),
          const SizedBox(height: 10),
          _SssKarti(
            soru: 'Havale dekontunu nasıl gönderirim?',
            cevap: 'Sipariş verdikten sonra açılan havale ekranından ya da Siparişlerim bölümünden gönderebilirsiniz.',
          ),
          const SizedBox(height: 10),
          _SssKarti(
            soru: 'Farklı mağazalardan aynı anda sipariş verebilir miyim?',
            cevap: 'Şu an için tek sepette yalnızca bir mağazadan sipariş verilebilmektedir.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DestekKarti extends StatelessWidget {
  final IconData icon; final Color renk;
  final String baslik, aciklama, deger;
  const _DestekKarti({required this.icon, required this.renk, required this.baslik, required this.aciklama, required this.deger});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: renk.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: renk, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(aciklama, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 2),
          Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.w700, fontSize: 13)),
        ])),
      ]),
    );
  }
}

class _SssKarti extends StatefulWidget {
  final String soru, cevap;
  const _SssKarti({required this.soru, required this.cevap});
  @override State<_SssKarti> createState() => _SssKartiState();
}

class _SssKartiState extends State<_SssKarti> {
  bool _acik = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _acik = !_acik),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _acik ? const Color(0xFFFF8C00).withOpacity(0.4) : Colors.transparent),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.soru, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            Icon(_acik ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFFFF8C00)),
          ]),
          if (_acik) ...[
            const SizedBox(height: 10),
            Text(widget.cevap, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.6)),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HAKKIMIZDA (değişmedi)
// ═══════════════════════════════════════════════════════════════════════════

class _HakkindaScreen extends StatelessWidget {
  const _HakkindaScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaplan,
      appBar: AppBar(title: const Text('Hakkımızda')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFFFF4500).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Column(children: [
              Icon(Icons.storefront_rounded, color: Colors.white, size: 48),
              SizedBox(height: 12),
              Text('HataySepetim', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              SizedBox(height: 4),
              Text('Reyhanlı\'nın Yerel Alışveriş Platformu', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 20),
          _BilgiKarti(icon: Icons.info_outline, baslik: 'Biz Kimiz?',
            icerik: 'HataySepetim, Hatay\'ın yerel esnafını dijital dünya ile buluşturan modern bir pazar yeri platformudur.'),
          const SizedBox(height: 12),
          _BilgiKarti(icon: Icons.favorite_border_rounded, baslik: 'Misyonumuz',
            icerik: 'Her türlü ihtiyacınızı en hızlı şekilde kapınıza ulaştırırken yerel ekonomiyi desteklemektir.'),
          const SizedBox(height: 12),
          _BilgiKarti(icon: Icons.visibility_outlined, baslik: 'Vizyonumuz',
            icerik: 'HataySepetim olarak Hatay\'ın tüm ilçelerinde yerel esnafı güçlendiren lider platform olmayı hedefliyoruz.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(children: [
              _BilgiSatiri(Icons.tag_rounded, 'Versiyon', '1.0.0 (Build 1)'),
              const Divider(height: 20),
              _BilgiSatiri(Icons.phone_android_rounded, 'Platform', 'Android & iOS'),
              const Divider(height: 20),
              _BilgiSatiri(Icons.location_city_rounded, 'Şube', 'Reyhanlı, Hatay'),
              const Divider(height: 20),
              _BilgiSatiri(Icons.language_rounded, 'Web', 'reyhanli.hataysepetim.com.tr'),
            ]),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('© 2025 HataySepetim\nTüm hakları saklıdır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.6)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BilgiKarti extends StatelessWidget {
  final IconData icon; final String baslik, icerik;
  const _BilgiKarti({required this.icon, required this.baslik, required this.icerik});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFFF8C00).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFFFF8C00), size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          Text(icerik, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.6)),
        ])),
      ]),
    );
  }
}

class _BilgiSatiri extends StatelessWidget {
  final IconData icon; final String etiket, deger;
  const _BilgiSatiri(this.icon, this.etiket, this.deger);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFFFF8C00)),
      const SizedBox(width: 10),
      Text(etiket, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
      const Spacer(),
      Text(deger, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    ]);
  }
}
