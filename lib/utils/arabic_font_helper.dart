import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Helper class for applying Arabic fonts conditionally based on app language
/// 
/// Arabic Font Hierarchy:
/// - Tajawal: General UI text (buttons, navigation, settings, form labels, body text)
/// - Cairo: Titles and headlines (AppBar titles, screen headers, section titles, dialog titles)
/// - Changa: Conversational UI (chat messages, AI interfaces, messaging screens)
/// - Almarai: Data and forms (profile info, license details, contact info, input fields)
class ArabicFontHelper {
  
  /// Check if the current app language is Arabic
  static bool isArabic(BuildContext context) {
    return AppLocalizations.of(context)?.localeName == 'ar';
  }

  /// Get Tajawal font family for general UI text
  /// Use for: Button labels, navigation menus, bottom navigation bar labels, 
  /// service category labels, form field labels, settings options, general body text
  static String? getTajawalFont(BuildContext context) {
    return isArabic(context) ? 'Tajawal' : null;
  }

  /// Get Cairo font family for titles and headlines
  /// Use for: AppBar titles, screen headers, section titles, emergency alert banners,
  /// dialog titles, card headers, page titles
  static String? getCairoFont(BuildContext context) {
    return isArabic(context) ? 'Cairo' : null;
  }

  /// Get Changa font family for conversational UI
  /// Use for: Chat messages, AI chatbot interfaces, conversational text, messaging screens
  static String? getChangaFont(BuildContext context) {
    return isArabic(context) ? 'Changa' : null;
  }

  /// Get Almarai font family for data and forms
  /// Use for: User profile information, license details, personal data forms,
  /// contact information, emergency contact details, input fields, data display
  static String? getAlmaraiFont(BuildContext context) {
    return isArabic(context) ? 'Almarai' : null;
  }

  // Pre-built TextStyle helpers for common use cases

  /// General UI text style with Tajawal font
  static TextStyle getTajawalTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: getTajawalFont(context),
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Title/headline text style with Cairo font
  static TextStyle getCairoTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: getCairoFont(context),
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Conversational UI text style with Changa font
  static TextStyle getChangaTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: getChangaFont(context),
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Data/forms text style with Almarai font
  static TextStyle getAlmaraiTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: getAlmaraiFont(context),
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Get appropriate font family based on text type
  static String? getFontByType(BuildContext context, ArabicFontType type) {
    switch (type) {
      case ArabicFontType.general:
        return getTajawalFont(context);
      case ArabicFontType.title:
        return getCairoFont(context);
      case ArabicFontType.conversation:
        return getChangaFont(context);
      case ArabicFontType.data:
        return getAlmaraiFont(context);
    }
  }

  /// Get TextStyle based on text type with common styling
  static TextStyle getTextStyleByType(
    BuildContext context,
    ArabicFontType type, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    switch (type) {
      case ArabicFontType.general:
        return getTajawalTextStyle(
          context,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );
      case ArabicFontType.title:
        return getCairoTextStyle(
          context,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );
      case ArabicFontType.conversation:
        return getChangaTextStyle(
          context,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );
      case ArabicFontType.data:
        return getAlmaraiTextStyle(
          context,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );
    }
  }
}

/// Enum for different Arabic font types
enum ArabicFontType {
  /// Tajawal - General UI text
  general,
  
  /// Cairo - Titles and headlines
  title,
  
  /// Changa - Conversational UI
  conversation,
  
  /// Almarai - Data and forms
  data,
}
