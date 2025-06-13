import 'package:flutter/material.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class EditTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final double iconSize;
  final TextInputType keyboardType;
  final bool obscureText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool enabled;

  const EditTextField({
    super.key,
    required this.label,
    required this.icon,
    this.iconSize = 20,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.controller,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? Colors.black87 : Colors.white;
    final borderColor = isLight ? Colors.black87 : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        style: ArabicFontHelper.getAlmaraiTextStyle(
          context,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          prefixIcon: Icon(
            icon,
            size: iconSize,
            color: textColor,
          ),
          labelText: label,
          labelStyle: ArabicFontHelper.getAlmaraiTextStyle(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          errorStyle: const TextStyle(color: Colors.red),
          filled: true,
          fillColor: isLight ? Colors.transparent : Colors.transparent,
        ),
      ),
    );
  }
}
