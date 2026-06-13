import 'package:flutter/material.dart';

class CommonTextStyles {
  final displayLarge = const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.4,
    fontFamily: 'NunitoSans',
  );

  final h1 = const TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.4,
    fontFamily: 'NunitoSans',
  );

  final h2 = const TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w800,
    height: 1.4,
    fontFamily: 'NunitoSans',
  );

  final h3 = const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    fontFamily: 'NunitoSans',
  );

  final title = const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: 'NunitoSans',
  );

  final subtitle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: 'NunitoSans',
  );

  final body = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    fontFamily: 'Inter',
  );

  final body2 = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    fontFamily: 'Inter',
  );

  final bodyBold = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.6,
    fontFamily: 'Inter',
  );

  final body2Bold = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.6,
    fontFamily: 'Inter',
  );

  final caption = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
    fontFamily: 'Inter',
  );

  final captionBold = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.3,
    fontFamily: 'Inter',
  );

  final captionSemiBold = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFamily: 'Inter',
  );

  final caption2 = const TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.3,
    fontFamily: 'Inter',
  );

  final caption2Bold = const TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.3,
    fontFamily: 'Inter',
  );

  final caption3 = const TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w400,
    height: 1.2,
    fontFamily: 'Inter',
  );

  final caption3Bold = const TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFamily: 'Inter',
  );

  final overline = const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 2.64,
    fontFamily: 'Inter',
  );

  final labelMedium = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    fontFamily: 'Inter',
  );

  final labelSmall = const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.3,
    fontFamily: 'Inter',
  );

  final buttonL = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.03,
    fontFamily: 'Inter',
  );

  final buttonM = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.03,
    fontFamily: 'Inter',
  );

  final buttonS = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: 0.48,
    fontFamily: 'Inter',
  );

  static final CommonTextStyles _instance = CommonTextStyles._();
  factory CommonTextStyles() => _instance;
  CommonTextStyles._();
}
