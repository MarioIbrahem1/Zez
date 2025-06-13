import 'package:flutter/material.dart';
import 'package:road_helperr/ui/screens/constants.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  static const String routeName = "privacypolicyscreen";

  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final Color lightPrimary = const Color(0xFF023A87);
  final Color lightSecondary = const Color(0xFF86A5D9);
  final Color lightBackground = const Color(0xFFFDFEFF);

  // User's preferred color scheme
  final Color selectedGradientStart = const Color(0xFF01122A);
  final Color selectedGradientEnd = const Color(0xFF033E90);
  final Color unselectedBackground = const Color(0xFF1F3551);
  final Color selectedIconBackground = const Color(0xFF5B88C9);

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.primaryBlue : lightBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [selectedGradientStart, selectedGradientEnd]
                        : [lightPrimary, lightSecondary],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              title: Text(
                lang.privacyPolicy,
                style: ArabicFontHelper.getCairoTextStyle(
                  context,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ).copyWith(
                  fontFamily: ArabicFontHelper.isArabic(context)
                      ? ArabicFontHelper.getCairoFont(context)
                      : 'Roboto',
                  shadows: isDarkMode
                      ? null
                      : [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withOpacity(0.3),
                          )
                        ],
                ),
              ),
            ),
            backgroundColor: isDarkMode ? selectedGradientStart : lightPrimary,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last Updated
                  _buildLastUpdated(lang, isDarkMode),
                  const SizedBox(height: 20),

                  // Introduction
                  _buildIntroduction(lang, isDarkMode),
                  const SizedBox(height: 24),

                  // Data Collection Section
                  _buildSection(
                    title: lang.privacyDataCollectionTitle,
                    content: [
                      _buildSubSection(
                        title: lang.privacyPersonalInfoTitle,
                        content: lang.privacyPersonalInfoContent,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSubSection(
                        title: lang.privacyLocationDataTitle,
                        content: lang.privacyLocationDataContent,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSubSection(
                        title: lang.privacyEmergencyContactsTitle,
                        content: lang.privacyEmergencyContactsContent,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Data Storage Section
                  _buildSection(
                    title: lang.privacyDataStorageTitle,
                    content: [
                      _buildSubSection(
                        title: lang.privacyLocalStorageTitle,
                        content: lang.privacyLocalStorageContent,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSubSection(
                        title: lang.privacyCloudStorageTitle,
                        content: lang.privacyCloudStorageContent,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Third-Party Services Section
                  _buildSection(
                    title: lang.privacyThirdPartyTitle,
                    content: [
                      _buildSubSection(
                        title: lang.privacyGoogleServicesTitle,
                        content: lang.privacyGoogleServicesContent,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSubSection(
                        title: lang.privacyNotificationServicesTitle,
                        content: lang.privacyNotificationServicesContent,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSubSection(
                        title: lang.privacySmsServicesTitle,
                        content: lang.privacySmsServicesContent,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Data Usage Section
                  _buildSection(
                    title: lang.privacyDataUsageTitle,
                    content: [
                      _buildContentText(
                        lang.privacyDataUsageContent,
                        isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // User Rights Section
                  _buildSection(
                    title: lang.privacyUserRightsTitle,
                    content: [
                      _buildSubSection(
                        title: lang.privacyDataControlTitle,
                        content: lang.privacyDataControlContent,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSubSection(
                        title: lang.privacyAccessRightsTitle,
                        content: lang.privacyAccessRightsContent,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Authentication Methods Section
                  _buildSection(
                    title: lang.privacyAuthMethodsTitle,
                    content: [
                      _buildSubSection(
                        title: lang.privacyTraditionalAuthTitle,
                        content: lang.privacyTraditionalAuthContent,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSubSection(
                        title: lang.privacyGoogleAuthTitle,
                        content: lang.privacyGoogleAuthContent,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Data Retention Section
                  _buildSection(
                    title: lang.privacyDataRetentionTitle,
                    content: [
                      _buildSubSection(
                        title: lang.privacyRetentionPolicyTitle,
                        content: lang.privacyRetentionPolicyContent,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Security Measures Section
                  _buildSection(
                    title: lang.privacySecurityMeasuresTitle,
                    content: [
                      _buildContentText(
                        lang.privacySecurityContent,
                        isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Children's Privacy Section
                  _buildSection(
                    title: lang.privacyChildrenTitle,
                    content: [
                      _buildContentText(
                        lang.privacyChildrenContent,
                        isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Policy Changes Section
                  _buildSection(
                    title: lang.privacyChangesTitle,
                    content: [
                      _buildContentText(
                        lang.privacyChangesContent,
                        isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Contact Information Section
                  _buildSection(
                    title: lang.privacyContactTitle,
                    content: [
                      _buildContentText(
                        lang.privacyContactContent,
                        isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),

                  // Consent Section
                  _buildSection(
                    title: lang.privacyConsentTitle,
                    content: [
                      _buildContentText(
                        lang.privacyConsentContent,
                        isDarkMode,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(AppLocalizations lang, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? unselectedBackground.withOpacity(0.3)
            : lightSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode
              ? selectedIconBackground.withOpacity(0.3)
              : lightSecondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        lang.privacyLastUpdated,
        style: ArabicFontHelper.getTajawalTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white70 : lightPrimary.withOpacity(0.8),
        ).copyWith(
          fontFamily: ArabicFontHelper.isArabic(context)
              ? ArabicFontHelper.getTajawalFont(context)
              : 'Roboto',
        ),
      ),
    );
  }

  Widget _buildIntroduction(AppLocalizations lang, bool isDarkMode) {
    return Text(
      lang.privacyIntroduction,
      style: ArabicFontHelper.getTajawalTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: isDarkMode ? Colors.white : lightPrimary,
        height: 1.6,
      ).copyWith(
        fontFamily: ArabicFontHelper.isArabic(context)
            ? ArabicFontHelper.getTajawalFont(context)
            : 'Roboto',
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> content,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : lightPrimary,
          ).copyWith(
            fontFamily: ArabicFontHelper.isArabic(context)
                ? ArabicFontHelper.getCairoFont(context)
                : 'Roboto',
          ),
        ),
        const SizedBox(height: 12),
        ...content,
      ],
    );
  }

  Widget _buildSubSection({
    required String title,
    required String content,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? unselectedBackground.withOpacity(0.2)
            : lightSecondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? unselectedBackground.withOpacity(0.4)
              : lightSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ArabicFontHelper.getTajawalTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? selectedIconBackground : lightPrimary,
            ).copyWith(
              fontFamily: ArabicFontHelper.isArabic(context)
                  ? ArabicFontHelper.getTajawalFont(context)
                  : 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: ArabicFontHelper.getTajawalTextStyle(
              context,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : lightPrimary.withOpacity(0.8),
              height: 1.5,
            ).copyWith(
              fontFamily: ArabicFontHelper.isArabic(context)
                  ? ArabicFontHelper.getTajawalFont(context)
                  : 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentText(String content, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? unselectedBackground.withOpacity(0.2)
            : lightSecondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? unselectedBackground.withOpacity(0.4)
              : lightSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        content,
        style: ArabicFontHelper.getTajawalTextStyle(
          context,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: isDarkMode
              ? Colors.white.withOpacity(0.9)
              : lightPrimary.withOpacity(0.8),
          height: 1.5,
        ).copyWith(
          fontFamily: ArabicFontHelper.isArabic(context)
              ? ArabicFontHelper.getTajawalFont(context)
              : 'Roboto',
        ),
      ),
    );
  }
}
