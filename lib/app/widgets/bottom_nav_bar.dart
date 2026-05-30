import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8, // 2 is very tight; 6–8 tends to feel better
      child: SizedBox(
        height: kBottomNavigationBarHeight,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
              activeColor: cs.primary,
            ),
            _NavItem(
              icon: Icons.list,
              label: 'Ledger',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
              activeColor: cs.primary,
            ),

            const SizedBox(width: 64),

            _NavItem(
              icon: Icons.account_balance,
              label: 'Accounts',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
              activeColor: cs.primary,
            ),
            _NavItem(
              icon: Icons.autorenew,
              label: 'Subscriptions',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
              activeColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final iconColor = selected
        ? activeColor
        : cs.onSurface.withValues(alpha: 0.55);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias, // ensures ripple is clipped
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: iconColor),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2,
                  width: selected ? 24 : 0,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
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
