import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:road_helperr/ui/screens/ai_welcome_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/map_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/profile_screen.dart';
import 'package:road_helperr/utils/app_colors.dart';
import 'package:road_helperr/utils/text_strings.dart';
import 'notification_screen.dart';
import 'package:road_helperr/services/notification_service.dart';
import 'package:road_helperr/services/places_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:road_helperr/ui/widgets/profile_image.dart';
import 'package:road_helperr/services/accessibility_checker.dart';
import 'package:road_helperr/services/accessibility_service.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';
import 'package:road_helperr/ui/widgets/sos_permission_status_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const String routeName = "home";

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // static const int _selectedIndex = 0; // تم إزالته لأنه غير مستخدم
  int pressCount = 0;

  final Map<String, bool> serviceStates = {
    TextStrings.homeGas: false,
    TextStrings.homePolice: false,
    TextStrings.homeFire: false,
    TextStrings.homeHospital: false,
    TextStrings.homeMaintenance: false,
    TextStrings.homeWinch: false,
  };
  double? currentLatitude;
  double? currentLongitude;

  int selectedServicesCount = 0;
  String location = "Fetching location...";
  String userEmail = ""; // متغير لتخزين البريد الإلكتروني للمستخدم

  // Accessibility Service variables
  final AccessibilityChecker _accessibilityChecker = AccessibilityChecker();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getUserEmail(); // استدعاء دالة للحصول على البريد الإلكتروني للمستخدم
    _ensureLocationTrackingStarted(); // التأكد من بدء تتبع الموقع
    _checkAccessibilityService(); // التحقق من خدمة الطوارئ
  }

  // التأكد من بدء تتبع الموقع للمستخدم المسجل (Google users only)
  Future<void> _ensureLocationTrackingStarted() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Google users can use location tracking
        debugPrint(
            'تم التأكد من بدء تتبع الموقع في HomeScreen للمستخدم Google');
      } else {
        // Traditional users - location tracking not available
        debugPrint('تتبع الموقع غير متاح للمستخدمين التقليديين');
      }
    } catch (e) {
      debugPrint('خطأ في التأكد من تتبع الموقع: $e');
    }
  }

  // دالة للحصول على البريد الإلكتروني للمستخدم من التخزين المحلي
  Future<void> _getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('logged_in_email');
      debugPrint('🔍 User email from SharedPreferences: $email');
      if (email != null && email.isNotEmpty) {
        setState(() {
          userEmail = email;
        });
        debugPrint('✅ User email set: $userEmail');
      } else {
        debugPrint('❌ No user email found in SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Error getting user email: $e');
    }
  }

  // التحقق من خدمة الطوارئ (Accessibility Service)
  Future<void> _checkAccessibilityService() async {
    try {
      debugPrint('🔍 HomeScreen: Starting accessibility service check...');

      // التحقق من حالة الجلسة أولاً
      final sessionShown =
          await _accessibilityChecker.isSessionNotificationShown();
      debugPrint('🔍 HomeScreen: Session notification shown: $sessionShown');

      // التحقق من حالة الخدمة أولاً
      final isEnabled =
          await AccessibilityService.isAccessibilityServiceEnabled();
      debugPrint('🔍 HomeScreen: Accessibility service enabled: $isEnabled');

      if (!isEnabled) {
        // إعادة تعيين حالة التذكير لضمان ظهور التنبيه
        await _accessibilityChecker.resetReminderState();
        debugPrint('🔄 HomeScreen: Reset reminder state');

        final shouldShow = await _accessibilityChecker.shouldShowReminder();
        debugPrint('🔍 HomeScreen: Should show reminder: $shouldShow');

        if (shouldShow && mounted) {
          // تسجيل أن التنبيه تم عرضه في هذه الجلسة
          await _accessibilityChecker.markSessionNotificationShown();
          debugPrint('📢 HomeScreen: Marked session notification as shown');

          // إظهار الـ dialog بدلاً من الـ widget المدمج
          _showAccessibilityDialog();
          debugPrint('📢 HomeScreen: Showing accessibility dialog');
        } else {
          debugPrint(
              '🔇 HomeScreen: Not showing dialog - shouldShow: $shouldShow, mounted: $mounted');
        }
      } else {
        debugPrint(
            '✅ HomeScreen: Accessibility service is enabled, no dialog needed');
      }
    } catch (e) {
      debugPrint('❌ HomeScreen: Error checking accessibility service: $e');
    }
  }

  // إظهار dialog للـ accessibility service
  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _buildAccessibilityDialog();
      },
    );
  }

  // بناء dialog جميل للـ accessibility service
  Widget _buildAccessibilityDialog() {
    final lang = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F3551)
                  : const Color(0xFF86A5D9),
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF01122A)
                  : const Color(0xFF023A87),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة وعنوان
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    lang?.enableSOSEmergencyService ??
                        'Enable SOS Emergency Service',
                    style: ArabicFontHelper.getCairoTextStyle(
                      context,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // الرسالة الرئيسية
            Text(
              lang?.enableAccessibilityServiceSOS ??
                  'Enable accessibility service to use SOS power button trigger',
              style: ArabicFontHelper.getTajawalTextStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // التعليمات
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lang?.followTheseSteps ?? 'Follow these steps:',
                        style: ArabicFontHelper.getTajawalTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionStep(
                      '1',
                      lang?.androidSettingsAccessibility ??
                          'Go to Android Settings → Accessibility'),
                  _buildInstructionStep(
                      '2',
                      lang?.findInstalledAppsSection ??
                          'Find "Installed Apps" section'),
                  _buildInstructionStep(
                      '3', lang?.selectRoadHelper ?? 'Select "Road Helper"'),
                  _buildInstructionStep(
                      '4', lang?.toggleServiceOn ?? 'Toggle the service ON'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // الأزرار
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _accessibilityChecker.markUserDismissed();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                    child: Text(
                      lang?.dismiss ?? 'Dismiss',
                      style: ArabicFontHelper.getTajawalTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await AccessibilityService.openAccessibilitySettings();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang?.afterEnablingServiceReturn ??
                                'After enabling the service, return to the app'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      lang?.openSettings ?? 'Open Settings',
                      style: ArabicFontHelper.getTajawalTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // بناء خطوة من التعليمات
  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: ArabicFontHelper.getTajawalTextStyle(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void toggleFilter(String key, bool value) {
    setState(() {
      serviceStates[key] = value;
    });
    debugPrint("Filter changed: $key -> $value");
  }

  Future<void> getFilteredServices() async {
    // جمع الفلاتر المختارة من الخدمة
    List<String> selectedKeys = serviceStates.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    debugPrint("Selected filters: $selectedKeys");

    if (selectedKeys.isEmpty) {
      NotificationService.showValidationError(
        context,
        'Please select at least one service!',
      );
      return;
    }

    // استخدام الدالة الجديدة للحصول على نوع المكان والكلمات المفتاحية
    List<Map<String, dynamic>> selectedFilters = selectedKeys
        .map((key) => PlacesService.getPlaceTypeAndKeyword(key))
        .toList();

    debugPrint('🔍 Selected filters with keywords: $selectedFilters');

    // الحصول على الموقع الحالي الفعلي
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // تحديث الموقع الحالي
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
        debugPrint(
            '📍 Current location updated: $currentLatitude, $currentLongitude');
      });

      // تحديث عنوان الموقع (يمكن إضافة هذه الوظيفة لاحقًا إذا لزم الأمر)
    } catch (e) {
      debugPrint('❌ Error getting current location: $e');
      if (currentLatitude == null || currentLongitude == null) {
        if (mounted) {
          NotificationService.showValidationError(
            context,
            'Location not available. Please try again.',
          );
        }
        return;
      }
    }

    // زيادة نصف قطر البحث للحصول على نتائج أكثر
    const double searchRadius = 10000; // 10 كيلومتر بدلاً من 5

    Set<Marker> allMarkers = {};

    // معالجة كل نوع فلتر على حدة للحصول على نتائج أفضل
    for (var filter in selectedFilters) {
      final type = filter['type'] as String;
      final keyword = filter['keyword'] as String;

      debugPrint('🔍 Fetching places for type: $type, keyword: $keyword');

      try {
        // استخدام الميزات الجديدة في PlacesService
        final places = await PlacesService.searchNearbyPlaces(
          latitude: currentLatitude!,
          longitude: currentLongitude!,
          radius: searchRadius,
          types: [type],
          keyword: keyword,
          fetchAllPages: true, // الحصول على جميع الصفحات
        );

        debugPrint(
            '✅ Found ${places.length} places for type: $type, keyword: $keyword');

        // إضافة العلامات للنتائج
        for (var place in places) {
          try {
            final lat =
                (place['geometry']['location']['lat'] as num).toDouble();
            final lng =
                (place['geometry']['location']['lng'] as num).toDouble();
            final name = place['name'] as String? ?? 'Unknown Place';
            final placeId =
                place['place_id'] as String? ?? DateTime.now().toString();
            final vicinity = place['vicinity'] as String? ?? '';

            allMarkers.add(
              Marker(
                markerId: MarkerId(placeId),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: vicinity,
                ),
              ),
            );
          } catch (e) {
            debugPrint('Error processing place: $e');
            continue;
          }
        }
      } catch (e) {
        debugPrint('Error fetching places for type $type: $e');
      }
    }

    debugPrint('📊 Total markers: ${allMarkers.length}');

    // يمكن استخدام العلامات هنا إذا لزم الأمر
    // setState(() {
    //   // تحديث العلامات على الخريطة
    // });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          location = "${place.locality}, ${place.country}";
        });
      }
    } catch (e) {
      setState(() {
        location = "Location not available";
      });
    }
  }

  void _showWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        var lang = AppLocalizations.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(lang.warning),
          content: Text(lang.pleaseSelectBetween1To3Services),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(lang.ok),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToMap(BuildContext context) async {
    Map<String, bool> activeFilters = {};
    if (serviceStates[TextStrings.homeHospital] ?? false) {
      activeFilters['Hospital'] = true;
    }
    if (serviceStates[TextStrings.homePolice] ?? false) {
      activeFilters['Police'] = true;
    }
    if (serviceStates[TextStrings.homeMaintenance] ?? false) {
      activeFilters['Maintenance center'] = true;
    }
    if (serviceStates[TextStrings.homeWinch] ?? false) {
      activeFilters['Winch'] = true;
    }
    if (serviceStates[TextStrings.homeGas] ?? false) {
      activeFilters['Gas Station'] = true;
    }
    if (serviceStates[TextStrings.homeFire] ?? false) {
      activeFilters['Fire Station'] = true;
    }

    if (activeFilters.isEmpty) {
      final lang = AppLocalizations.of(context);
      NotificationService.showValidationError(
        context,
        lang?.pleaseSelectAtLeastOneService ??
            'Please select at least one service!',
      );
      return;
    }

    // التأكد من تحديث الموقع الحالي قبل الانتقال إلى الخريطة
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // تحديث الموقع الحالي
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });

      if (mounted) {
        Navigator.pushNamed(
          this.context,
          MapScreen.routeName,
          arguments: {
            'filters': activeFilters,
            'latitude': currentLatitude,
            'longitude': currentLongitude,
          },
        );
      }
    } catch (e) {
      // في حالة فشل الحصول على الموقع الحالي
      if (currentLatitude != null && currentLongitude != null) {
        if (mounted) {
          // استخدام آخر موقع معروف إذا كان متاحًا
          Navigator.pushNamed(
            this.context,
            MapScreen.routeName,
            arguments: {
              'filters': activeFilters,
              'latitude': currentLatitude,
              'longitude': currentLongitude,
            },
          );
        }
      } else {
        if (mounted) {
          final lang = AppLocalizations.of(this.context);
          NotificationService.showValidationError(
            this.context,
            lang?.fetchingLocation ??
                'Location not available. Please try again.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = MediaQuery.of(context).size;
              final isTablet = constraints.maxWidth > 600;
              final isDesktop = constraints.maxWidth > 1200;

              double titleSize = size.width *
                  (isDesktop
                      ? 0.03
                      : isTablet
                          ? 0.04
                          : 0.055);
              double iconSize = size.width *
                  (isDesktop
                      ? 0.03
                      : isTablet
                          ? 0.04
                          : 0.05);
              double padding = size.width *
                  (isDesktop
                      ? 0.02
                      : isTablet
                          ? 0.03
                          : 0.04);

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : null,
                  image: DecorationImage(
                    image: AssetImage(
                        Theme.of(context).brightness == Brightness.light
                            ? "assets/images/homeLight.png"
                            : "assets/images/home background.png"),
                    fit: Theme.of(context).brightness == Brightness.light
                        ? BoxFit.none
                        : BoxFit.cover,
                    alignment: Theme.of(context).brightness == Brightness.light
                        ? const Alignment(0.9, -0.9)
                        : Alignment.center,
                    scale: Theme.of(context).brightness == Brightness.light
                        ? 1.2
                        : 1.0,
                  ),
                ),
                child: _buildScaffold(
                    context, constraints, size, titleSize, iconSize, padding),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, BoxConstraints constraints,
      Size size, double titleSize, double iconSize, double padding) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return _buildCupertinoScaffold(
          context, constraints, size, titleSize, iconSize, padding);
    } else {
      return _buildMaterialScaffold(
          context, constraints, size, titleSize, iconSize, padding);
    }
  }

  Widget _buildMaterialScaffold(
      BuildContext context,
      BoxConstraints constraints,
      Size size,
      double titleSize,
      double iconSize,
      double padding) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.location_on_outlined,
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFF0F4797)
                : Colors.white,
            size: iconSize * 1.2,
          ),
          onPressed: () {},
        ),
        title: Text(
          location,
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFF0F4797)
                : Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: userEmail.isNotEmpty
                ? Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: ProfileImageWidget(
                      email: userEmail,
                      size: 46, // 50 - 4 (border width) = 46
                      backgroundColor: const Color(0xFF86A5D9),
                      iconColor: const Color(0xFF0F4797),
                      onTap: () {
                        Navigator.pushNamed(context, ProfileScreen.routeName);
                      },
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/Ellipse 42.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: _buildBody(
            context, constraints, size, titleSize, iconSize, padding),
      ),
      bottomNavigationBar: _buildBottomNavBar(context, iconSize),
    );
  }

  Widget _buildCupertinoScaffold(
      BuildContext context,
      BoxConstraints constraints,
      Size size,
      double titleSize,
      double iconSize,
      double padding) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.location,
            color: Colors.white,
            size: iconSize * 1.2,
          ),
          onPressed: () {},
        ),
        middle: Text(
          location,
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ).copyWith(
            fontFamily: ArabicFontHelper.isArabic(context)
                ? ArabicFontHelper.getCairoFont(context)
                : '.SF Pro Text',
          ),
        ),
        trailing: Padding(
          padding: EdgeInsets.all(padding),
          child: userEmail.isNotEmpty
              ? Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: ProfileImageWidget(
                    email: userEmail,
                    size: 46, // 50 - 4 (border width) = 46
                    backgroundColor: const Color(0xFF86A5D9),
                    iconColor: const Color(0xFF0F4797),
                    onTap: () {
                      Navigator.pushNamed(context, ProfileScreen.routeName);
                    },
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/Ellipse 42.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildBody(
                  context, constraints, size, titleSize, iconSize, padding),
              _buildBottomNavBar(context, iconSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BoxConstraints constraints, Size size,
      double titleSize, double iconSize, double padding) {
    final platform = Theme.of(context).platform;
    final isIOS =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final lang = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang?.getYouBackOnTrack ?? TextStrings.homeGetYouBack,
            style: ArabicFontHelper.getCairoTextStyle(
              context,
              fontSize: titleSize * 1.2,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.light
                  ? const Color(0xFF0F4797)
                  : Colors.white,
            ).copyWith(
              fontFamily: ArabicFontHelper.isArabic(context)
                  ? ArabicFontHelper.getCairoFont(context)
                  : (isIOS ? '.SF Pro Text' : null),
            ),
          ),
          SizedBox(height: size.height * 0.02),

          // SOS Permission Status Widget
          SOSPermissionStatusWidget(
            onPermissionsChanged: () {
              // Refresh any SOS-related state if needed
              setState(() {});
            },
          ),
          SizedBox(height: size.height * 0.02),

          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F3551)
                  : const Color(0xFF86A5D9),
              borderRadius: BorderRadius.circular(isIOS ? 10 : 15),
            ),
            child: Column(
              children: [
                _buildServiceGrid(constraints, iconSize, titleSize, padding),
                SizedBox(height: size.height * 0.02),
                _buildGetServiceButton(context, size, titleSize),
              ],
            ),
          ),
          SizedBox(height: size.height * 0.03),
        ],
      ),
    );
  }

  Widget _buildServiceGrid(BoxConstraints constraints, double iconSize,
      double titleSize, double padding) {
    final isDesktop = constraints.maxWidth > 1200;
    final isTablet = constraints.maxWidth > 600;

    return GridView.count(
      crossAxisCount: isDesktop
          ? 4
          : isTablet
              ? 3
              : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 138 / 142, // نسبة العرض إلى الارتفاع حسب التصميم
      children: serviceStates.entries.map((entry) {
        return ServiceCard(
          title: entry.key,
          iconPath: getServiceIconPath(entry.key),
          isSelected: entry.value,
          iconSize: 54, // حجم الأيقونة الثابت 54x54
          fontSize: 16, // حجم الخط الثابت 16px
          onToggle: (value) {
            setState(() {
              if (value) {
                if (selectedServicesCount < 3) {
                  serviceStates[entry.key] = value;
                  selectedServicesCount++;
                } else {
                  _showWarningDialog(context);
                }
              } else {
                serviceStates[entry.key] = value;
                selectedServicesCount--;
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildGetServiceButton(
      BuildContext context, Size size, double titleSize) {
    final platform = Theme.of(context).platform;
    final isIOS =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final lang = AppLocalizations.of(context);

    if (isIOS) {
      return Center(
        child: SizedBox(
          width: size.width * 0.6, // 60% من عرض الشاشة
          height: size.height * 0.055,
          child: CupertinoButton(
            color: const Color(0xFF023A87),
            borderRadius: BorderRadius.circular(25),
            onPressed: () => _navigateToMap(context),
            child: Text(
              lang?.getYourServices ?? TextStrings.homeGetYourService,
              style: ArabicFontHelper.getTajawalTextStyle(
                context,
                fontSize: titleSize * 0.9,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ).copyWith(
                fontFamily: ArabicFontHelper.isArabic(context)
                    ? ArabicFontHelper.getTajawalFont(context)
                    : '.SF Pro Text',
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: size.width * 0.6, // 60% من عرض الشاشة
        height: size.height * 0.055,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF023A87),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          onPressed: () => _navigateToMap(context),
          child: Text(
            lang?.getYourServices ?? TextStrings.homeGetYourService,
            style: ArabicFontHelper.getTajawalTextStyle(
              context,
              fontSize: titleSize * 0.9,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, double iconSize) {
    final platform = Theme.of(context).platform;
    final isIOS =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isIOS) {
      return CupertinoTabBar(
        backgroundColor: AppColors.getBackgroundColor(context),
        activeColor: Colors.white,
        inactiveColor: Colors.white.withOpacity(0.6),
        height: iconSize * 3,
        items: [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home, size: iconSize),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.location, size: iconSize),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble, size: iconSize),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bell, size: iconSize),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person, size: iconSize),
            label: 'Profile',
          ),
        ],
        onTap: (index) => _handleNavigation(context, index),
      );
    }

    return Container(
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
        index: 0,
        letIndexChange: (index) => true,
        items: const [
          Icon(Icons.home_outlined, size: 18, color: Colors.white),
          Icon(Icons.location_on_outlined, size: 18, color: Colors.white),
          Icon(Icons.textsms_outlined, size: 18, color: Colors.white),
          Icon(Icons.notifications_outlined, size: 18, color: Colors.white),
          Icon(Icons.person_2_outlined, size: 18, color: Colors.white),
        ],
        onTap: (index) => _handleNavigation(context, index),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    final routes = [
      HomeScreen.routeName,
      MapScreen.routeName,
      AiWelcomeScreen.routeName,
      NotificationScreen.routeName,
      ProfileScreen.routeName,
    ];
    if (index < routes.length) {
      Navigator.pushNamed(context, routes[index]);
    }
  }

  String getServiceIconPath(String title) {
    switch (title) {
      case TextStrings.homeGas:
        return 'assets/home_icon/gas_station.png';
      case TextStrings.homePolice:
        return 'assets/home_icon/Police.png';
      case TextStrings.homeFire:
        return 'assets/home_icon/Fire_extinguisher.png';
      case TextStrings.homeHospital:
        return 'assets/home_icon/Hospital.png';
      case TextStrings.homeMaintenance:
        return 'assets/home_icon/Maintenance_center.png';
      case TextStrings.homeWinch:
        return 'assets/home_icon/Winch.png';
      default:
        return 'assets/home_icon/gas_station.png'; // fallback
    }
  }
}

class ServiceCard extends StatelessWidget {
  final String title;
  final String iconPath;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final double iconSize;
  final double fontSize;

  const ServiceCard({
    super.key,
    required this.title,
    required this.iconPath,
    required this.isSelected,
    required this.onToggle,
    required this.iconSize,
    required this.fontSize,
  });

  String _getTranslatedTitle(BuildContext context, String title) {
    final lang = AppLocalizations.of(context);

    if (lang == null) return title;

    switch (title) {
      case TextStrings.homeGas:
        return lang.gasStation;
      case TextStrings.homePolice:
        return lang.policeDepartment;
      case TextStrings.homeFire:
        return lang.fireExtinguisher;
      case TextStrings.homeHospital:
        return lang.hospital;
      case TextStrings.homeMaintenance:
        return lang.maintenanceCenter;
      case TextStrings.homeWinch:
        return lang.winch;
      default:
        return title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isIOS =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    // Get translated title
    final translatedTitle = _getTranslatedTitle(context, title);

    return Container(
      width: 138,
      height: 142,
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment(0.2007, -1.0), // 146.41 degrees equivalent
                end: Alignment(0.9457, 1.0),
                colors: [
                  Color(0xFF01122A), // #01122A at 20.07%
                  Color(0xFF033E90), // #033E90 at 94.57%
                ],
                stops: [0.2007, 0.9457],
              )
            : null,
        color: isSelected ? null : const Color(0xFFB7BCC2), // رمادي للغير مختار
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: الأيقونة على الشمال والسويتش على اليمين
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // الأيقونة مع خلفية دائرية
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF5B88C9) // #5B88C9 للمختار
                        : const Color(0xFF1F3551), // #1F3551 لغير المختار
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        iconPath,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Error loading icon: $iconPath - $error');
                          return const Icon(
                            Icons.image_not_supported,
                            color: Colors.white,
                            size: 28,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // السويتش على اليمين
                Transform.scale(
                  scale: 0.8,
                  child: isIOS
                      ? CupertinoSwitch(
                          value: isSelected,
                          onChanged: onToggle,
                          activeColor: const Color(0xFF033E90), // أزرق ثابت
                          trackColor: const Color(0xFF808080), // رمادي ثابت
                        )
                      : Switch(
                          value: isSelected,
                          onChanged: onToggle,
                          activeColor: Colors.white, // الدائرة بيضاء
                          activeTrackColor:
                              const Color(0xFF033E90), // المسار أزرق
                          inactiveThumbColor: Colors.white, // الدائرة بيضاء
                          inactiveTrackColor:
                              const Color(0xFF808080), // المسار رمادي
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          splashRadius: 0.0,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // النص تحت الأيقونة على الشمال
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  translatedTitle,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ArabicFontHelper.getTajawalTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white // أبيض للمختار
                        : const Color(0xFF494444), // رمادي داكن للغير مختار
                    height: 1.5, // line-height: 150%
                    letterSpacing: -0.35, // letter-spacing: -2.2% من 16px
                  ).copyWith(
                    fontFamily: ArabicFontHelper.isArabic(context)
                        ? ArabicFontHelper.getTajawalFont(context)
                        : 'Roboto',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
