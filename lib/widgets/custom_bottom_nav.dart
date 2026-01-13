import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _glowController;
  late Animation<double> _slideAnimation;
  late Animation<double> _glowAnimation;
  int _previousIndex = 0;

  // Colors for each nav item
  final List<Color> _itemColors = [
    const Color(0xFFB388FF), // Purple for Home
    const Color(0xFF64B5F6), // Blue for Attendance
    const Color(0xFFFF8A80), // Coral/Peach for Statistics
  ];

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideAnimation = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(CustomBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _slideAnimation = Tween<double>(
        begin: _previousIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ));
      _slideController.reset();
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 16, left: 24, right: 24, top: 16),
      color: Colors.transparent,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F38), // Dark pill background
          borderRadius: BorderRadius.circular(35),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_slideController, _glowController]),
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.calendar_today_rounded,
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.insert_chart_rounded,
                  index: 2,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
  }) {
    final currentPosition = _slideAnimation.value;
    final distance = (currentPosition - index).abs();
    final isSelected = distance < 0.5;
    final color = _itemColors[index];

    // Calculate scale and opacity based on distance from selected position
    final scale = isSelected ? 1.0 + (0.2 * (1 - distance * 2).clamp(0.0, 1.0)) : 1.0;
    final glowIntensity = isSelected ? _glowAnimation.value : 0.0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 70,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow effect behind icon
                  if (isSelected)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: glowIntensity),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  // Icon
                  Icon(
                    icon,
                    color: isSelected ? color : const Color(0xFF5C6378),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
