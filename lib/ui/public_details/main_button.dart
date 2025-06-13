import 'package:flutter/material.dart';
import 'package:road_helperr/utils/app_colors.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class MainButton extends StatelessWidget {
  final String textButton;
  final VoidCallback onPress;
  final bool isDisabled;

  const MainButton({
    super.key,
    required this.textButton,
    required this.onPress,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 250,
      height: 48,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPress,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? (isDarkMode
                  ? const Color(0xFF023A87).withOpacity(0.5)
                  : const Color(0xFF86A5D9).withOpacity(0.5))
              : (isDarkMode
                  ? const Color(0xFF023A87)
                  : const Color(0xFF86A5D9)),
          foregroundColor: isDisabled
              ? AppColors.getLabelTextField(context).withOpacity(0.7)
              : AppColors.getLabelTextField(context),
          disabledBackgroundColor: isDarkMode
              ? const Color(0xFF023A87).withOpacity(0.5)
              : const Color(0xFF86A5D9).withOpacity(0.5),
          disabledForegroundColor:
              AppColors.getLabelTextField(context).withOpacity(0.7),
        ),
        child: Text(
          textButton,
          style: ArabicFontHelper.getTajawalTextStyle(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDisabled ? Colors.grey.shade300 : Colors.white,
          ),
        ),
      ),
    );
  }
}
