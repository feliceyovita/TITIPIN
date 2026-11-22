import 'package:flutter/material.dart';

const _selectedColor = Color(0xFF506D54);
const _selectedBackground = Color(0xFFE1ECE1);
const _inactiveColor = Color(0xFF687C95);
const _addColor = Color(0xFF759A7E);

class CatalogBottomNavigation extends StatelessWidget {
  const CatalogBottomNavigation({
    super.key,
    required this.showingSaved,
    this.showingMyItems = false,
    required this.onHome,
    required this.onSaved,
    required this.onAdd,
    required this.onMyItems,
    required this.onProfile,
  });

  final bool showingSaved;
  final bool showingMyItems;
  final VoidCallback onHome;
  final VoidCallback onSaved;
  final VoidCallback onAdd;
  final VoidCallback onMyItems;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFD9E6F2))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.home_outlined,
                    label: 'Beranda',
                    selected: !showingSaved && !showingMyItems,
                    onTap: onHome,
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.favorite_border,
                    label: 'Simpan',
                    selected: showingSaved && !showingMyItems,
                    onTap: onSaved,
                  ),
                ),
                Expanded(
                  child: Center(
                    heightFactor: 1,
                    child: IconButton(
                      onPressed: onAdd,
                      tooltip: 'Unggah Barang',
                      style: IconButton.styleFrom(
                        backgroundColor: _addColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.square(48),
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.add, size: 28),
                    ),
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'Barang Saya',
                    selected: showingMyItems,
                    onTap: onMyItems,
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    onTap: onProfile,
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
    final color = selected ? _selectedColor : _inactiveColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? _selectedBackground : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 23, color: color),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
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
