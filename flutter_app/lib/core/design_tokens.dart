import 'package:flutter/material.dart';

/// Kovunela's initial visual tokens, shared by Android, iOS and web.
///
/// Colors are provisional until formal contrast and accessibility review.
abstract final class KovunelaColors {
  static const primary = Color(0xFF0F766E);
  static const secondary = Color(0xFF14B8A6);
  static const mint = Color(0xFFA7F3D0);
  static const warmSurface = Color(0xFFF8FAF8);
  static const background = Color(0xFFF1F5F9);
  static const onLight = Color(0xFF143A35);
  static const mutedOnLight = Color(0xFF4B615D);
}

abstract final class KovunelaSpacing {
  static const tiny = 4.0;
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const extraLarge = 32.0;
}

abstract final class KovunelaRadii {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
}

/// Viewport classes, not operating-system or device-type assumptions.
abstract final class KovunelaBreakpoints {
  static const compactMax = 600.0;
  static const expandedMin = 1024.0;

  static bool isCompact(double width) => width < compactMax;
  static bool isExpanded(double width) => width >= expandedMin;
}
