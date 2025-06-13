import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:road_helperr/providers/settings_provider.dart';
import 'package:road_helperr/ui/screens/ai_welcome_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/map_screen.dart';

import '../../../utils/theme_switch.dart';
import '../about_screen.dart';
import 'home_screen.dart';
import 'notification_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:road_helperr/ui/screens/signin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:road_helperr/services/profile_service.dart';
import 'package:road_helperr/services/firebase_user_location_service.dart';

import 'package:road_helperr/models/profile_data.dart';
import 'package:road_helperr/ui/widgets/profile_image.dart';
import 'package:road_helperr/utils/auth_type_helper.dart';
import 'package:road_helperr/services/auth_service.dart';
import '../edit_profile_screen.dart';
import '../sos_emergency_contacts_screen.dart';
import '../sos_settings_screen.dart';
// import '../help_request_test_screen.dart'; // Uncomment if you need Help Request Test

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class ProfileScreen extends StatefulWidget {
  static const String routeName = "profscreen";
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = "";
  String email = "";
  String selectedLanguage = "English";
  String currentTheme = "System";
  ProfileData? _profileData;
  bool isLoading = true;
  bool _isLocationTrackingEnabled = true; // حالة الـ tracking
  bool _isGoogleSignIn = false; // نوع المصادقة
  static const int _selectedIndex = 4;

  final ProfileService _profileService = ProfileService();
  final FirebaseUserLocationService _firebaseService =
      FirebaseUserLocationService();

  @override
  void initState() {
    super.initState();
    // Load user data first, then fetch profile image
    _loadUserData().then((_) {
      if (mounted) {
        _fetchProfileImage();
        _loadLocationTrackingState(); // تحميل حالة الـ tracking
        _loadAuthType(); // تحميل نوع المصادقة

        // إضافة تأخير قصير ثم إعادة تحميل صورة البروفايل مرة أخرى
        // هذا يساعد في حالة مستخدمي Google حيث قد تكون الصورة غير متاحة فورًا
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _fetchProfileImage();
          }
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('logged_in_email');
      final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

      if (userEmail != null && userEmail.isNotEmpty) {
        email = userEmail;

        // First check if we have cached profile data
        bool loadedFromCache = false;
        final hasFreshCache = await ProfileData.hasFreshCachedData();

        if (hasFreshCache) {
          final cachedData = await ProfileData.loadFromCache();
          if (cachedData != null && cachedData.email == userEmail) {
            debugPrint('Using cached profile data for $userEmail');
            if (mounted) {
              setState(() {
                _profileData = cachedData;
                name = cachedData.name;
                email = cachedData.email;

                // Profile data loaded from cache

                isLoading = false;
              });
            }
            loadedFromCache = true;
          }
        }

        // If we couldn't load from cache, load from API
        if (!loadedFromCache) {
          ProfileData profileData;

          // استخدام API موحد لجميع المستخدمين (Google والعاديين)
          debugPrint(
              'Loading profile data for $userEmail (Google: $isGoogleSignIn)');
          profileData = await _profileService.getProfileData(userEmail);

          if (mounted) {
            setState(() {
              _profileData = profileData;
              name = profileData.name;
              email = profileData.email;
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          Navigator.pushReplacementNamed(context, SignInScreen.routeName);
        }
      }
    } catch (e) {
      debugPrint('Critical error in _loadUserData: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        // تحديد رسالة الخطأ بناءً على نوع المستخدم
        final prefs = await SharedPreferences.getInstance();
        final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

        String errorMessage;
        if (isGoogleSignIn) {
          errorMessage =
              'فشل في تحميل بيانات مستخدم Google. يرجى المحاولة مرة أخرى.';
        } else {
          errorMessage =
              'فشل في تحميل بيانات الملف الشخصي. يرجى المحاولة مرة أخرى.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'إعادة المحاولة',
                textColor: Colors.white,
                onPressed: () {
                  _loadUserData();
                },
              ),
            ),
          );
        }
      }
    }
  }

  // تحميل حالة الـ tracking من SharedPreferences
  Future<void> _loadLocationTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('location_tracking_enabled') ?? true;

      if (mounted) {
        setState(() {
          _isLocationTrackingEnabled = isEnabled;
        });
      }

      debugPrint('📍 Location tracking state loaded: $isEnabled');
    } catch (e) {
      debugPrint('❌ Error loading location tracking state: $e');
    }
  }

  // تحميل نوع المصادقة من SharedPreferences
  Future<void> _loadAuthType() async {
    try {
      final isGoogle = await AuthTypeHelper.isGoogleSignIn();

      if (mounted) {
        setState(() {
          _isGoogleSignIn = isGoogle;
        });
      }

      debugPrint('🔐 Auth type loaded: ${isGoogle ? 'Google' : 'Traditional'}');
    } catch (e) {
      debugPrint('❌ Error loading auth type: $e');
    }
  }

  // تحديث حالة الـ tracking
  Future<void> _updateLocationTrackingState(bool enabled) async {
    try {
      setState(() {
        _isLocationTrackingEnabled = enabled;
      });

      // حفظ الحالة في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_tracking_enabled', enabled);

      if (enabled) {
        // تشغيل الـ tracking
        debugPrint('🟢 Location tracking enabled');
        await _firebaseService.updateAvailabilityForHelp(true);

        // عرض رسالة نجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم تفعيل تتبع الموقع. أنت الآن مرئي للمستخدمين الآخرين.'
                  : 'Location tracking enabled. You are now visible to other users.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // إيقاف الـ tracking
        debugPrint('🔴 Location tracking disabled');
        await _firebaseService.updateAvailabilityForHelp(false);

        // إيقاف الـ tracking التلقائي
        _firebaseService.stopLocationTracking();

        // تحديث حالة المستخدم إلى offline
        await _firebaseService.setUserOffline();

        // عرض رسالة نجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم إيقاف تتبع الموقع. أنت الآن مخفي عن المستخدمين الآخرين.'
                  : 'Location tracking disabled. You are now hidden from other users.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      debugPrint('✅ Location tracking state updated: $enabled');
    } catch (e) {
      debugPrint('❌ Error updating location tracking state: $e');

      // إعادة الحالة السابقة في حالة الخطأ
      setState(() {
        _isLocationTrackingEnabled = !enabled;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'ar'
                ? 'خطأ في تحديث تتبع الموقع: $e'
                : 'Error updating location tracking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchProfileImage() async {
    try {
      // Make sure we have a valid email before trying to fetch the image
      if (email.isEmpty) {
        debugPrint('Email is empty, trying to get it from SharedPreferences');
        final prefs = await SharedPreferences.getInstance();
        final userEmail = prefs.getString('logged_in_email');
        if (userEmail != null && userEmail.isNotEmpty) {
          email = userEmail;
          debugPrint('Retrieved email from SharedPreferences: $email');
        } else {
          debugPrint('Could not retrieve email from SharedPreferences');
          return; // Exit if we still don't have an email
        }
      }

      debugPrint('🔍 Fetching profile image from API for: $email');

      // Clear image cache before fetching to ensure we get the latest image
      imageCache.clear();
      imageCache.clearLiveImages();

      // Get profile image directly from API (no cache)
      String imageUrl = await _profileService.getProfileImage(email);
      debugPrint('📥 Fetched profile image URL from API: $imageUrl');

      // If we couldn't get a URL from the API, show a message
      if (imageUrl.isEmpty) {
        debugPrint('❌ Empty image URL returned from API');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Could not load profile image. Please try again later.')),
          );
        }
        return;
      }

      if (mounted) {
        // Validate the URL format
        if (!imageUrl.startsWith('http')) {
          debugPrint('🔧 Fixing image URL format: $imageUrl');
          // Try to fix the URL
          if (imageUrl.startsWith('/')) {
            imageUrl = 'http://81.10.91.96:8132$imageUrl';
          } else {
            imageUrl = 'http://81.10.91.96:8132/$imageUrl';
          }
          debugPrint('✅ Fixed image URL: $imageUrl');
        }

        // Add cache-busting parameter for display
        final cleanUrl = _cleanCacheBustingParams(imageUrl);
        final finalUrl = _addCacheBustingParam(cleanUrl);

        debugPrint('🧹 Clean URL: $cleanUrl');
        debugPrint('🔗 Final URL for display: $finalUrl');

        // Update the state with the new image URL
        setState(() {
          if (_profileData != null) {
            _profileData = ProfileData(
              name: _profileData!.name,
              email: _profileData!.email,
              phone: _profileData!.phone,
              address: _profileData!.address,
              profileImage:
                  finalUrl, // Use final URL with cache busting for display
              carModel: _profileData!.carModel,
              carColor: _profileData!.carColor,
              plateNumber: _profileData!.plateNumber,
            );
          } else {
            _profileData = ProfileData(
              name: name,
              email: email,
              profileImage:
                  finalUrl, // Use final URL with cache busting for display
            );
          }

          // Profile image loaded successfully
        });

        debugPrint('✅ Profile image loaded successfully');
      }
    } catch (e) {
      debugPrint('❌ Error in _fetchProfileImage: $e');
      // Show error in UI for debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile image: $e')),
        );
      }
    }
  }

  void _logout(BuildContext context) {
    // Store context values before async operations
    final lang = AppLocalizations.of(context);
    final logoutText = lang?.logout ?? 'Logging out...';
    final errorText = lang?.error ?? 'Error';

    // Show loading indicator before async operations
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(logoutText)),
    );

    // Execute logout in a separate function to avoid context issues
    _executeLogout().then((_) {
      // Success - navigate to sign-in screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, SignInScreen.routeName);
      }
    }).catchError((e) {
      debugPrint('Logout error: $e');

      // Show error and navigate anyway
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorText: $e')),
        );

        // Navigate to sign-in screen even if there was an error
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, SignInScreen.routeName);
          }
        });
      }
    });
  }

  // Separate async function to handle the actual logout process
  Future<void> _executeLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

    if (isGoogleSignIn) {
      // Handle Google Sign In logout
      try {
        GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        // We don't use disconnect() as it causes the PlatformException
      } catch (googleError) {
        debugPrint('Google Sign Out error (non-critical): $googleError');
        // Continue with logout even if Google sign out fails
      }
    }

    // استخدام AuthService للـ logout الكامل بدلاً من manual clearing
    try {
      final authService = AuthService();
      await authService.logout();
      debugPrint('✅ ProfileScreen: Complete logout via AuthService');
    } catch (authError) {
      debugPrint('❌ ProfileScreen: AuthService logout error: $authError');

      // Fallback manual clearing if AuthService fails
      await prefs.remove('logged_in_email');
      await prefs.remove('is_google_sign_in');
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.setBool('is_logged_in', false);
    }

    // Clear cached profile data
    await ProfileData.clearCache();
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          email: email,
          initialData: _profileData,
        ),
      ),
    );
    if (result != null && result is ProfileData) {
      setState(() {
        _profileData = result;
        name = result.name;
        email = result.email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final lang = AppLocalizations.of(context);

    // Update selectedLanguage based on the current locale
    selectedLanguage =
        settingsProvider.currentLocale == 'en' ? "English" : "العربية";

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF01122A),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(top: 25.0, left: 10),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          centerTitle: true,
          title: Padding(
            padding: const EdgeInsets.only(top: 25.0),
            child: Text(
              lang?.profile ?? 'Profile',
              style: ArabicFontHelper.getCairoTextStyle(
                context,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFF86A5D9)
                        : const Color(0xFF1F3551),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                Positioned(
                  top: 120,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildProfileImage(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 230),
                  child: Column(
                    children: [
                      const SizedBox(height: 25),
                      Text(
                        name,
                        style: ArabicFontHelper.getAlmaraiTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black
                                  : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email,
                        style: ArabicFontHelper.getAlmaraiTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black.withOpacity(0.7)
                                  : Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 35),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildListTile(
                                icon: Icons.edit_outlined,
                                title:
                                    AppLocalizations.of(context)?.editProfile ??
                                        "Edit Profile",
                                onTap: _navigateToEditProfile,
                              ),
                              const SizedBox(height: 5),
                              _buildListTile(
                                icon: Icons.emergency,
                                title: lang?.emergencyContactInformation ??
                                    "Emergency Contacts",
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                      SOSEmergencyContactsScreen.routeName);
                                },
                              ),
                              const SizedBox(height: 5),
                              _buildListTile(
                                icon: Icons.settings_applications,
                                title: lang?.sosSettings ?? "SOS Settings",
                                onTap: () {
                                  Navigator.of(context)
                                      .pushNamed(SOSSettingsScreen.routeName);
                                },
                              ),
                              const SizedBox(height: 5),
                              _buildLanguageSelector(),
                              const SizedBox(height: 5),
                              _buildThemeSelector(),
                              // إظهار تبديل تتبع الموقع فقط لمستخدمي Google
                              if (_isGoogleSignIn) ...[
                                const SizedBox(height: 5),
                                _buildLocationTrackingSwitch(),
                              ],
                              const SizedBox(height: 5),
                              _buildListTile(
                                icon: Icons.help_outline,
                                title:
                                    AppLocalizations.of(context)?.faq ?? "FAQ",
                                onTap: () {
                                  Navigator.of(context).pushNamed('faqscreen');
                                },
                              ),
                              const SizedBox(height: 5),
                              _buildListTile(
                                icon: Icons.privacy_tip_outlined,
                                title: AppLocalizations.of(context)
                                        ?.privacyPolicyTitle ??
                                    "Privacy Policy",
                                onTap: () {
                                  Navigator.of(context)
                                      .pushNamed('privacypolicyscreen');
                                },
                              ),
                              const SizedBox(height: 5),
                              _buildListTile(
                                icon: Icons.info_outline,
                                title: AppLocalizations.of(context)?.about ??
                                    "About",
                                onTap: () {
                                  Navigator.of(context)
                                      .pushNamed(AboutScreen.routeName);
                                },
                              ),
                              // إظهار زر اختبار Help Request فقط في وضع التطوير ولمستخدمي Google
                              // TODO: Uncomment this section if you need to test Help Request system again
                              /*
                              if (kDebugMode && _isGoogleSignIn) ...[
                                const SizedBox(height: 5),
                                _buildListTile(
                                  icon: Icons.bug_report,
                                  title: "Help Request Test",
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const HelpRequestTestScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                              */
                              const SizedBox(height: 5),
                              _buildListTile(
                                icon: Icons.logout,
                                title: AppLocalizations.of(context)?.logout ??
                                    "Logout",
                                onTap: () => _logout(context),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(bottom: 0),
        child: CurvedNavigationBar(
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF01122A),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F3551)
              : const Color(0xFF023A87),
          buttonBackgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F3551)
              : const Color(0xFF023A87),
          animationDuration: const Duration(milliseconds: 300),
          height: 45,
          index: _selectedIndex,
          items: const [
            Icon(Icons.home_outlined, size: 18, color: Colors.white),
            Icon(Icons.location_on_outlined, size: 18, color: Colors.white),
            Icon(Icons.textsms_outlined, size: 18, color: Colors.white),
            Icon(Icons.notifications_outlined, size: 18, color: Colors.white),
            Icon(Icons.person_2_outlined, size: 18, color: Colors.white),
          ],
          onTap: (index) => _handleNavigation(context, index),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white),
      title: Text(
        title,
        style: ArabicFontHelper.getTajawalTextStyle(
          context,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white,
        ),
      ),
      trailing: trailing ??
          Icon(Icons.arrow_forward_ios,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              size: 16),
      onTap: onTap,
    );
  }

  Widget _buildLanguageSelector() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final lang = AppLocalizations.of(context);

    return _buildListTile(
      icon: Icons.language,
      title: lang?.language ?? "Language",
      trailing: PopupMenuButton<String>(
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLanguage,
              style: ArabicFontHelper.getTajawalTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              size: 16,
            ),
          ],
        ),
        color: const Color(0xFF1F3551),
        onSelected: (String value) {
          setState(() {
            selectedLanguage = value;
            // Change the app locale using the SettingsProvider
            if (value == "English") {
              settingsProvider.changeLocale('en');
            } else {
              settingsProvider.changeLocale('ar');
            }
          });
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: "English",
            child: Text(
              lang?.english ?? 'English',
              style: ArabicFontHelper.getTajawalTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: "العربية",
            child: Text(
              lang?.arabic ?? 'العربية',
              style: ArabicFontHelper.getTajawalTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      onTap: () {},
    );
  }

  Widget _buildThemeSelector() {
    final lang = AppLocalizations.of(context);
    return _buildListTile(
      icon: Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoIcons.paintbrush
          : Icons.palette_outlined,
      title: lang?.darkMode ?? "Theme",
      trailing: const ThemeSwitch(),
      onTap: () {},
    );
  }

  Widget _buildLocationTrackingSwitch() {
    return _buildListTile(
      icon: _isLocationTrackingEnabled ? Icons.location_on : Icons.location_off,
      title: Localizations.localeOf(context).languageCode == 'ar'
          ? "تتبع الموقع"
          : "Location Tracking",
      trailing: Switch(
        value: _isLocationTrackingEnabled,
        onChanged: (bool value) {
          _updateLocationTrackingState(value);
        },
        activeColor: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFF023A87)
            : const Color(0xFF5B88C9),
        activeTrackColor: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFF023A87).withOpacity(0.3)
            : const Color(0xFF5B88C9).withOpacity(0.3),
        inactiveThumbColor: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[400]
            : Colors.grey[600],
        inactiveTrackColor: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[300]
            : Colors.grey[700],
      ),
      onTap: () {
        _updateLocationTrackingState(!_isLocationTrackingEnabled);
      },
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // إذا كان لدينا صورة بروفايل في _profileData، نعرضها مباشرة
        if (_profileData != null &&
            _profileData!.profileImage != null &&
            _profileData!.profileImage!.isNotEmpty &&
            _profileData!.profileImage!.startsWith('http'))
          CircleAvatar(
            radius: 65,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFF86A5D9)
                : Colors.white,
            backgroundImage: NetworkImage(
              // إضافة معلمة لمنع التخزين المؤقت
              () {
                final cleanUrl =
                    _cleanCacheBustingParams(_profileData!.profileImage!);
                final finalUrl = _addCacheBustingParam(cleanUrl);
                debugPrint('🖼️ Loading profile image from: $finalUrl');
                debugPrint('🔧 Original URL: ${_profileData!.profileImage!}');
                debugPrint('🧹 Clean URL: $cleanUrl');
                return finalUrl;
              }(),
            ),
            onBackgroundImageError: (exception, stackTrace) {
              debugPrint('Error loading profile image: $exception');
              // في حالة حدوث خطأ، نستخدم ProfileImageWidget
              debugPrint(
                  '❌ Error loading profile image, using ProfileImageWidget');
            },
          )
        else
          ProfileImageWidget(
            email: email,
            size: 130,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFF86A5D9)
                : Colors.white,
            iconColor: Colors.white,
            onTap: () {
              // Allow manual retry on tap if there's an error
              _fetchProfileImage();
            },
          ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? const Color(0xFF023A87)
                  : const Color(0xFF1F3551),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
              onPressed: _pickAndUploadImage,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      // Show a dialog to choose between camera and gallery
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(Localizations.localeOf(context).languageCode == 'ar'
                ? 'اختر مصدر الصورة'
                : 'Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'الكاميرا'
                          : 'Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'المعرض'
                          : 'Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) {
        return; // User canceled the dialog
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80, // Reduce image quality to improve upload speed
        maxWidth: 800, // Limit image width to reduce file size
      );

      if (image != null) {
        setState(() {
          isLoading = true;
        });

        final File imageFile = File(image.path);
        debugPrint('Selected image path: ${image.path}');
        debugPrint('Image file size: ${await imageFile.length()} bytes');

        // Check if email is available
        if (email.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final userEmail = prefs.getString('logged_in_email');
          if (userEmail != null && userEmail.isNotEmpty) {
            email = userEmail;
            debugPrint('Retrieved email from SharedPreferences: $email');
          } else {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('User email not found. Please log in again.')),
              );
            }
            return;
          }
        }

        // Show uploading progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading image...')),
          );
        }

        // Upload the image
        final String imageUrl =
            await _profileService.uploadProfileImage(email, imageFile);
        debugPrint('Uploaded image URL: $imageUrl');

        if (mounted) {
          if (imageUrl.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Failed to upload image. Please try again.')),
            );
            setState(() {
              isLoading = false;
            });
            return;
          }

          // Clear image cache
          imageCache.clear();
          imageCache.clearLiveImages();

          // Clean the image URL before storing it
          final cleanImageUrl = _cleanCacheBustingParams(imageUrl);

          debugPrint(
              '🔄 Storing clean image URL in ProfileData: $cleanImageUrl');
          debugPrint('🔧 Original uploaded URL: $imageUrl');

          // Image uploaded successfully

          setState(() {
            if (_profileData != null) {
              _profileData = ProfileData(
                name: _profileData!.name,
                email: _profileData!.email,
                phone: _profileData!.phone,
                address: _profileData!.address,
                profileImage: cleanImageUrl, // Store clean URL
                carModel: _profileData!.carModel,
                carColor: _profileData!.carColor,
                plateNumber: _profileData!.plateNumber,
              );
            } else {
              _profileData = ProfileData(
                name: name,
                email: email,
                profileImage: cleanImageUrl, // Store clean URL
              );
            }

            // Image uploaded and updated successfully
            isLoading = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated successfully')),
          );

          // Force refresh of the profile image widget
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _fetchProfileImage();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _pickAndUploadImage: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }

    // No need to fetch the image again, the ProfileImageWidget will handle it
  }

  void _handleNavigation(BuildContext context, int index) {
    if (index != _selectedIndex) {
      final routes = [
        HomeScreen.routeName,
        MapScreen.routeName,
        AiWelcomeScreen.routeName,
        NotificationScreen.routeName,
        ProfileScreen.routeName,
      ];
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }

  // Helper method to clean cache busting parameters from URL
  String _cleanCacheBustingParams(String url) {
    String cleanUrl = url;

    // Remove all existing cache busting parameters more thoroughly
    // Handle multiple t= parameters
    while (cleanUrl.contains('?t=') || cleanUrl.contains('&t=')) {
      if (cleanUrl.contains('?t=')) {
        final parts = cleanUrl.split('?t=');
        cleanUrl = parts[0];
        // If there are more parameters after t=, we need to handle them
        if (parts.length > 1 && parts[1].contains('&')) {
          final afterT = parts[1].split('&');
          if (afterT.length > 1) {
            // Reconstruct URL with remaining parameters
            cleanUrl += '?${afterT.skip(1).join('&')}';
          }
        }
      }
      if (cleanUrl.contains('&t=')) {
        final parts = cleanUrl.split('&t=');
        cleanUrl = parts[0];
        // If there are more parameters after t=, we need to handle them
        if (parts.length > 1 && parts[1].contains('&')) {
          final afterT = parts[1].split('&');
          if (afterT.length > 1) {
            // Reconstruct URL with remaining parameters
            cleanUrl += '&${afterT.skip(1).join('&')}';
          }
        }
      }
    }

    return cleanUrl;
  }

  // Helper method to add cache busting parameter to URL
  String _addCacheBustingParam(String url) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (!url.contains('?')) {
      return '$url?t=$timestamp';
    } else {
      return '$url&t=$timestamp';
    }
  }
}
