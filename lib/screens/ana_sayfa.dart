import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sepet_provider.dart';
import '../providers/kullanici_provider.dart';
import 'kategoriler_screen.dart';
import 'sepet_screen.dart';
import 'profil_screen.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _aktifTab = 0;

  final List<Widget> _sayfalar = const [
    KategorilerScreen(),
    SepetScreen(),
    ProfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final sepet = context.watch<SepetProvider>();

    return Scaffold(
      body: IndexedStack(
        index: _aktifTab,
        children: _sayfalar,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -5))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TabItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Kategoriler',
                    index: 0,
                    aktif: _aktifTab,
                    onTap: _degistir),
                _SepetTabItem(
                    adet: sepet.toplamAdet,
                    aktif: _aktifTab == 1,
                    onTap: () => _degistir(1)),
                _TabItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Hesabım',
                    index: 2,
                    aktif: _aktifTab,
                    onTap: _degistir),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _degistir(int index) => setState(() => _aktifTab = index);
}

// ─── TAB WİDGET'LAR ───────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int aktif;
  final Function(int) onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.aktif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAktif = index == aktif;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isAktif
              ? const Color(0xFFFF8C00).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isAktif
                    ? const Color(0xFFFF8C00)
                    : const Color(0xFF86868B),
                size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isAktif
                      ? const Color(0xFFFF8C00)
                      : const Color(0xFF86868B),
                )),
          ],
        ),
      ),
    );
  }
}

class _SepetTabItem extends StatelessWidget {
  final int adet;
  final bool aktif;
  final VoidCallback onTap;

  const _SepetTabItem(
      {required this.adet, required this.aktif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: aktif
              ? const Color(0xFFFF8C00).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.shopping_bag_outlined,
                    color: aktif
                        ? const Color(0xFFFF8C00)
                        : const Color(0xFF86868B),
                    size: 24),
                if (adet > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      child: Text('$adet',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Sepetim',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: aktif
                      ? const Color(0xFFFF8C00)
                      : const Color(0xFF86868B),
                )),
          ],
        ),
      ),
    );
  }
}
