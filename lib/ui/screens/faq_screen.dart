import 'package:flutter/material.dart';
import 'package:road_helperr/ui/screens/constants.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class FaqScreen extends StatefulWidget {
  static const String routeName = "faqscreen";

  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
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
                lang.frequentlyAskedQuestions,
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
                  _buildFaqSection(
                    title: lang.faqAuthenticationTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqTraditionalVsGoogleTitle,
                        answer: lang.faqTraditionalVsGoogleAnswer,
                      ),
                      FaqItem(
                        question: lang.faqOtpProcessTitle,
                        answer: lang.faqOtpProcessAnswer,
                      ),
                      FaqItem(
                        question: lang.faqSessionManagementTitle,
                        answer: lang.faqSessionManagementAnswer,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  _buildFaqSection(
                    title: lang.faqProfileManagementTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqEditProfileTitle,
                        answer: lang.faqEditProfileAnswer,
                      ),
                      FaqItem(
                        question: lang.faqLicenseUploadTitle,
                        answer: lang.faqLicenseUploadAnswer,
                      ),
                      FaqItem(
                        question: lang.faqProfileImageTitle,
                        answer: lang.faqProfileImageAnswer,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  _buildFaqSection(
                    title: lang.faqEmergencyFeaturesTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqSosFunctionalityTitle,
                        answer: lang.faqSosFunctionalityAnswer,
                      ),
                      FaqItem(
                        question: lang.faqAccessibilityServiceTitle,
                        answer: lang.faqAccessibilityServiceAnswer,
                      ),
                      FaqItem(
                        question: lang.faqEmergencyContactsTitle,
                        answer: lang.faqEmergencyContactsAnswer,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  _buildFaqSection(
                    title: lang.faqHelpRequestsTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqHelpRequestSystemTitle,
                        answer: lang.faqHelpRequestSystemAnswer,
                      ),
                      FaqItem(
                        question: lang.faqHelpRequestFlowTitle,
                        answer: lang.faqHelpRequestFlowAnswer,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  _buildFaqSection(
                    title: lang.faqMapLocationTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqLocationTrackingTitle,
                        answer: lang.faqLocationTrackingAnswer,
                      ),
                      FaqItem(
                        question: lang.faqNearbyServicesTitle,
                        answer: lang.faqNearbyServicesAnswer,
                      ),
                      FaqItem(
                        question: lang.faqUserVisibilityTitle,
                        answer: lang.faqUserVisibilityAnswer,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  _buildFaqSection(
                    title: lang.faqNotificationsTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqPushNotificationsTitle,
                        answer: lang.faqPushNotificationsAnswer,
                      ),
                      FaqItem(
                        question: lang.faqNotificationTypesTitle,
                        answer: lang.faqNotificationTypesAnswer,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  _buildFaqSection(
                    title: lang.faqAiAssistantTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqChatbotTitle,
                        answer: lang.faqChatbotAnswer,
                      ),
                      FaqItem(
                        question: lang.faqImageAnalysisTitle,
                        answer: lang.faqImageAnalysisAnswer,
                      ),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  _buildFaqSection(
                    title: lang.faqSystemFeaturesTitle,
                    faqs: [
                      FaqItem(
                        question: lang.faqAppVersionTitle,
                        answer: lang.faqAppVersionAnswer,
                      ),
                      FaqItem(
                        question: lang.faqDataPersistenceTitle,
                        answer: lang.faqDataPersistenceAnswer,
                      ),
                      FaqItem(
                        question: lang.faqLanguageSwitchingTitle,
                        answer: lang.faqLanguageSwitchingAnswer,
                      ),
                      FaqItem(
                        question: lang.faqDarkModeTitle,
                        answer: lang.faqDarkModeAnswer,
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

  Widget _buildFaqSection({
    required String title,
    required List<FaqItem> faqs,
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
        ...faqs.map((faq) => _buildFaqExpansionTile(faq, isDarkMode)),
      ],
    );
  }

  Widget _buildFaqExpansionTile(FaqItem faq, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? unselectedBackground.withOpacity(0.3)
            : lightSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? unselectedBackground.withOpacity(0.5)
              : lightSecondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            iconColor: isDarkMode ? selectedIconBackground : lightPrimary,
            collapsedIconColor:
                isDarkMode ? selectedIconBackground : lightPrimary,
          ),
        ),
        child: ExpansionTile(
          title: Text(
            faq.question,
            style: ArabicFontHelper.getTajawalTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : lightPrimary,
              height: 1.5, // line-height: 150%
              letterSpacing: -0.35, // letter-spacing: -2.2% of 16px
            ).copyWith(
              fontFamily: ArabicFontHelper.isArabic(context)
                  ? ArabicFontHelper.getTajawalFont(context)
                  : 'Roboto',
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                faq.answer,
                style: ArabicFontHelper.getTajawalTextStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDarkMode
                      ? Colors.white70
                      : lightPrimary.withOpacity(0.8),
                  height: 1.5,
                ).copyWith(
                  fontFamily: ArabicFontHelper.isArabic(context)
                      ? ArabicFontHelper.getTajawalFont(context)
                      : 'Roboto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaqItem {
  final String question;
  final String answer;

  FaqItem({
    required this.question,
    required this.answer,
  });
}
