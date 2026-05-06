import 'package:flutter/material.dart';

class PhaseAssetIcon extends StatelessWidget {
  final String phaseKey;
  final IconData fallbackIcon;
  final double size;
  final Color fallbackColor;
  final bool completed;
  final double opacity;

  const PhaseAssetIcon({
    super.key,
    required this.phaseKey,
    required this.fallbackIcon,
    required this.size,
    required this.fallbackColor,
    this.completed = false,
    this.opacity = 1,
  });

  static String? assetFor(String phaseKey) {
    if (phaseKey == 'vegetative') {
      return 'assets/images/phases/vegetative.png';
    }
    if (phaseKey.startsWith('generative_')) {
      return 'assets/images/phases/generative.png';
    }
    if (phaseKey == 'pre_harvest') {
      return 'assets/images/phases/pre_harvest.png';
    }
    if (phaseKey == 'harvest') {
      return 'assets/images/phases/harvest.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(phaseKey);
    final icon = asset == null
        ? Icon(fallbackIcon, color: fallbackColor, size: size * 0.58)
        : Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            opacity: AlwaysStoppedAnimation(opacity),
            errorBuilder: (_, __, ___) =>
                Icon(fallbackIcon, color: fallbackColor, size: size * 0.58),
          );

    if (!completed) return icon;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: icon),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(45),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: size * 0.32,
                color: fallbackColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
