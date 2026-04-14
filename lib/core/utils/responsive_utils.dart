import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  // Screen size properties
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  // Spacing constants based on screen width
  double get paddingSmall => screenWidth * 0.02;     // ~8 on 400w
  double get paddingMedium => screenWidth * 0.04;    // ~16 on 400w
  double get paddingLarge => screenWidth * 0.06;     // ~24 on 400w

  // Scaling factor for fonts (base width assumed to be 375.0)
  double scaleFactor(double size) {
    return size * (screenWidth / 375.0);
  }

  // Clamped font size constraints for extreme screen sizes
  double fontSize(double baseSize) {
    double scaled = scaleFactor(baseSize);
    return scaled.clamp(baseSize * 0.8, baseSize * 1.5);
  }
}
