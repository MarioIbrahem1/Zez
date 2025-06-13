import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';

import 'package:road_helperr/models/user_location.dart';
import 'package:road_helperr/services/firebase_help_request_service.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/profile_screen.dart';
import 'package:road_helperr/ui/widgets/user_details_bottom_sheet.dart';
import '../../../utils/app_colors.dart';
import '../ai_welcome_screen.dart';
import 'home_screen.dart';
import 'notification_screen.dart';
import 'package:road_helperr/services/notification_service.dart';
import 'dart:async';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';
import 'package:road_helperr/utils/auth_type_helper.dart';

// Import new components
import 'map_screen_components/map_controller.dart';
import 'map_screen_components/map_navigation.dart';
import 'map_screen_components/place_details_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = "map";
  const MapScreen({super.key});
  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  // Map controller
  late GoogleMapController mapController;

  // State variables - Default location will be updated with real location
  LatLng _currentLocation = const LatLng(30.0444,
      31.2357); // Temporary default, will be replaced with real location
  bool _isLoading = true;
  int _selectedIndex = 1;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Nearest place data
  Map<String, dynamic>? _nearestPlace;
  Map<String, dynamic>? _selectedPlace;
  double? _nearestPlaceDistance;
  String? _nearestPlaceTravelTime;
  bool _showPlaceInfo = false;

  // Route data
  Map<String, dynamic>? _routeData;
  bool _isShowingRoute = false;

  // Timers
  Timer? _locationUpdateTimer;
  Timer? _usersUpdateTimer;

  // Map controller instance
  late MapController _mapController;

  // Flag to track if this is initial load from navigation
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();

    // Initialize map controller with callbacks
    _mapController = MapController(
      onLoadingChanged: (isLoading) {
        if (mounted) {
          setState(() {
            _isLoading = isLoading;
          });
        }
      },
      onMarkersChanged: (markers) {
        if (mounted) {
          setState(() {
            _markers = markers;
          });
        }
      },
      onPolylinesChanged: (polylines) {
        if (mounted) {
          setState(() {
            _polylines = polylines;
          });
        }
      },
      onLocationChanged: (location) {
        if (mounted) {
          setState(() {
            _currentLocation = location;
          });
        }
      },
      onError: (title, message) {
        if (mounted) {
          NotificationService.showError(
            context: context,
            title: title,
            message: message,
          );
        }
      },
      onPlaceSelected: (details) {
        if (mounted) {
          setState(() {
            _selectedPlace = details;
            _showPlaceInfo = true;
          });
          PlaceDetailsBottomSheet.show(context, details);
        }
      },
      onNearestPlaceChanged: (place, distance, travelTime) {
        if (mounted) {
          setState(() {
            _nearestPlace = place;
            _nearestPlaceDistance = distance;
            _nearestPlaceTravelTime = travelTime;
            _showPlaceInfo = place != null;
          });
        }
      },
      onRouteChanged: (routeData) {
        if (mounted) {
          setState(() {
            _routeData = routeData;
            _isShowingRoute = routeData != null;
          });
        }
      },
      onUserSelected: (user) {
        if (mounted) {
          _showUserDetailsBottomSheet(user);
        }
      },
    );

    _initializeMap();
    _startLocationUpdates();
    _startUsersUpdates();

    // Check authentication type and show message for traditional users
    _checkAuthenticationAndShowMessage();
  }

  /// Check authentication type and show message for traditional users
  Future<void> _checkAuthenticationAndShowMessage() async {
    if (!_isInitialLoad) return;

    try {
      final isGoogleUser = await AuthTypeHelper.isGoogleSignIn();

      // Show message only for traditional users (not Google users)
      if (!isGoogleUser && mounted) {
        // Use a slight delay to ensure the screen is fully loaded
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            final lang = AppLocalizations.of(context);
            NotificationService.showError(
              context: context,
              title: lang?.helpRequest ?? 'Help Request',
              message: lang?.helpRequestServiceNotAvailable ??
                  'Help Requests Service not available for only Google Users',
            );

            // Mark that initial load message has been shown
            setState(() {
              _isInitialLoad = false;
            });
          }
        });
      } else {
        // Mark that initial load is complete for Google users
        setState(() {
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking authentication type: $e');
      setState(() {
        _isInitialLoad = false;
      });
    }
  }

  Future<void> _initializeMap() async {
    debugPrint('🗺️ Initializing map and getting real location...');
    await _mapController.initializeMap();

    // Force get current location to override default location
    await _forceUpdateCurrentLocation();
  }

  /// Force update current location to ensure we get the real user location
  Future<void> _forceUpdateCurrentLocation() async {
    try {
      debugPrint('🔄 Force updating current location...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services not enabled');
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return;
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      // Update current location
      LatLng newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLocation = newLocation;
        });
      }

      // Update map controller location
      _mapController.updateCurrentLocation(newLocation);

      debugPrint(
          '✅ Real location updated: ${position.latitude}, ${position.longitude}');
      debugPrint('📊 Location accuracy: ${position.accuracy} meters');

      // Move camera to real location
      try {
        await mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newLocation, zoom: 16.0),
          ),
        );
        debugPrint('📷 Camera moved to real location');
      } catch (e) {
        debugPrint('⚠️ Could not move camera: $e');
      }
    } catch (e) {
      debugPrint('❌ Error force updating location: $e');
    }
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _usersUpdateTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startLocationUpdates() {
    _mapController.startLocationUpdates();
  }

  void _startUsersUpdates() {
    _mapController.startUsersUpdates();
  }

  // Removed unused methods

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Obtener los argumentos
    final arguments = ModalRoute.of(context)?.settings.arguments;

    // التحقق مما إذا كانت الوسائط بالتنسيق الجديد (خريطة مع مرشحات وإحداثيات)
    if (arguments is Map<String, dynamic>) {
      // استخراج المرشحات
      final filters = arguments['filters'] as Map<String, bool>?;
      if (filters != null) {
        _mapController.setFilters(filters);
        // Reset initial load flag when filters are applied (user interaction)
        setState(() {
          _isInitialLoad = false;
        });
      }

      // استخراج الإحداثيات
      final latitude = arguments['latitude'] as double?;
      final longitude = arguments['longitude'] as double?;

      if (latitude != null && longitude != null) {
        // تحديث الموقع الحالي
        setState(() {
          _currentLocation = LatLng(latitude, longitude);
        });

        // تحديث الموقع في وحدة تحكم الخريطة
        _mapController.updateCurrentLocation(_currentLocation);

        // تحريك الكاميرا إلى الموقع الحالي عندما يكون متاحًا
        // سيتم تنفيذ هذا بعد إنشاء الخريطة
        Future.delayed(Duration.zero, () {
          try {
            mapController.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _currentLocation, zoom: 15.0),
              ),
            );
          } catch (e) {
            debugPrint('Error moving camera: $e');
          }
        });
      }
    }
    // Compatibilidad con el formato antiguo (solo filtros)
    else if (arguments is Map<String, bool>) {
      _mapController.setFilters(arguments);
      // Reset initial load flag when filters are applied (user interaction)
      setState(() {
        _isInitialLoad = false;
      });
    }
  }

  // Methods now handled by the MapController class

  // ----------   BUILD UI  ----------
  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final isTablet = constraints.maxWidth > 600;
        final isDesktop = constraints.maxWidth > 1200;
        double titleSize = size.width *
            (isDesktop
                ? 0.02
                : isTablet
                    ? 0.03
                    : 0.04);
        double iconSize = size.width *
            (isDesktop
                ? 0.02
                : isTablet
                    ? 0.025
                    : 0.03);
        double navBarHeight = size.height *
            (isDesktop
                ? 0.08
                : isTablet
                    ? 0.07
                    : 0.06);

        return platform == TargetPlatform.iOS ||
                platform == TargetPlatform.macOS
            ? _buildCupertinoLayout(context, size, constraints, titleSize,
                iconSize, navBarHeight, isDesktop)
            : _buildMaterialLayout(context, size, constraints, titleSize,
                iconSize, navBarHeight, isDesktop);
      },
    );
  }

  Widget _buildMaterialLayout(
    BuildContext context,
    Size size,
    BoxConstraints constraints,
    double titleSize,
    double iconSize,
    double navBarHeight,
    bool isDesktop,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Map Screen',
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: iconSize * 1.2,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        toolbarHeight: navBarHeight,
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF01122A),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : AppColors.getBackgroundColor(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, size, constraints, titleSize, isDesktop),
      bottomNavigationBar: _buildMaterialNavBar(
        context,
        iconSize,
        navBarHeight,
        isDesktop,
      ),
    );
  }

  Widget _buildCupertinoLayout(
    BuildContext context,
    Size size,
    BoxConstraints constraints,
    double titleSize,
    double iconSize,
    double navBarHeight,
    bool isDesktop,
  ) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Map Screen',
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
          ).copyWith(
            fontFamily: ArabicFontHelper.isArabic(context)
                ? ArabicFontHelper.getCairoFont(context)
                : '.SF Pro Text',
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.back,
            size: iconSize * 1.2,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : AppColors.getBackgroundColor(context),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : AppColors.getBackgroundColor(context),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildBody(
                      context, size, constraints, titleSize, isDesktop),
            ),
            _buildCupertinoNavBar(
              context,
              iconSize,
              navBarHeight,
              isDesktop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Size size,
    BoxConstraints constraints,
    double titleSize,
    bool isDesktop,
  ) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _currentLocation,
            zoom: 15.0,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: true,
          onCameraMove: (CameraPosition position) {
            _mapController.onCameraMove(position);
          },
        ),

        // Place info card (for nearest or selected place)
        if (_showPlaceInfo && (_nearestPlace != null || _selectedPlace != null))
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildNearestPlaceCard(context),
          ),
      ],
    );
  }

  // Build place info card (for nearest or selected place)
  Widget _buildNearestPlaceCard(BuildContext context) {
    final lang = AppLocalizations.of(context);

    // Use selected place if available, otherwise use nearest place
    final place = _selectedPlace ?? _nearestPlace;
    if (place == null) return const SizedBox.shrink();

    final name =
        place['name'] as String? ?? (lang?.unknownPlace ?? 'Unknown Place');

    // Format distance with localized units
    final distance = place['distance'] != null &&
            place['distance']['text'] != null
        ? place['distance']['text'] as String
        : _nearestPlaceDistance != null
            ? (_nearestPlaceDistance! < 1000
                ? '${_nearestPlaceDistance!.toInt()} ${lang?.meters ?? 'm'}'
                : '${(_nearestPlaceDistance! / 1000).toStringAsFixed(1)} ${lang?.kilometers ?? 'km'}')
            : (lang?.distanceUnknown ?? 'Distance unknown');

    // Get travel time with localized fallback
    final travelTime =
        place['duration'] != null && place['duration']['text'] != null
            ? place['duration']['text'] as String
            : _nearestPlaceTravelTime ?? (lang?.timeUnknown ?? 'Time unknown');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.getCardColor(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang?.nearestPlace ?? 'Nearest Place',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getLabelTextField(context)
                              .withOpacity(0.7),
                        ),
                      ),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getLabelTextField(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        distance,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    if (travelTime.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            travelTime,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // First row of buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showNearestPlaceDetails,
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: Text(lang?.details ?? 'Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getBackgroundColor(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isShowingRoute
                        ? _clearRoute
                        : _showRouteToNearestPlace,
                    icon: Icon(_isShowingRoute ? Icons.close : Icons.map,
                        size: 16),
                    label: Text(_isShowingRoute
                        ? (lang?.hideRoute ?? 'Hide Route')
                        : (lang?.showRoute ?? 'Show Route')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isShowingRoute ? Colors.red.shade700 : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Second row of buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAlternativeRoutes,
                    icon: const Icon(Icons.alt_route, size: 16),
                    label:
                        Text(lang?.alternativeRoutes ?? 'Alternative Routes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToNearestPlace,
                    icon: const Icon(Icons.directions, size: 16),
                    label: Text(lang?.navigation ?? 'Navigation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
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

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    _mapController.setMapController(controller);

    // Initialize help request service for Google users only
    final isGoogleUser = await AuthTypeHelper.isGoogleSignIn();
    if (isGoogleUser) {
      FirebaseHelpRequestService();
    }
  }

  // Show user details bottom sheet
  void _showUserDetailsBottomSheet(UserLocation user) {
    UserDetailsBottomSheet.show(context, user, _currentLocation);
  }

  Widget _buildMaterialNavBar(
    BuildContext context,
    double iconSize,
    double navBarHeight,
    bool isDesktop,
  ) {
    return MapNavigation.buildMaterialNavBar(
      context: context,
      iconSize: iconSize,
      navBarHeight: navBarHeight,
      isDesktop: isDesktop,
      selectedIndex: _selectedIndex,
      onTap: (index) => _handleNavigation(context, index),
    );
  }

  Widget _buildCupertinoNavBar(
    BuildContext context,
    double iconSize,
    double navBarHeight,
    bool isDesktop,
  ) {
    return MapNavigation.buildCupertinoNavBar(
      context: context,
      iconSize: iconSize,
      navBarHeight: navBarHeight,
      isDesktop: isDesktop,
      selectedIndex: _selectedIndex,
      onTap: (index) => _handleNavigation(context, index),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  // Navigate to the selected place using external Google Maps
  Future<void> _navigateToNearestPlace() async {
    // Use selected place if available, otherwise use nearest place
    final place = _selectedPlace ?? _nearestPlace;
    if (place != null) {
      await _mapController.getDirectionsToNearestPlace();
    } else if (mounted) {
      NotificationService.showValidationError(
        context,
        'No place found. Please try again with a different filter.',
      );
    }
  }

  // Show place details
  void _showNearestPlaceDetails() {
    // Use selected place if available, otherwise use nearest place
    final place = _selectedPlace ?? _nearestPlace;
    if (place != null) {
      PlaceDetailsBottomSheet.show(context, place);
    }
  }

  // Show route to the selected place on the map
  Future<void> _showRouteToNearestPlace() async {
    // Use selected place if available, otherwise use nearest place
    final place = _selectedPlace ?? _nearestPlace;
    if (place != null) {
      final success = await _mapController.showRouteToNearestPlace();
      if (!success && mounted) {
        NotificationService.showValidationError(
          context,
          'Could not show route. Please try again.',
        );
      }
    } else if (mounted) {
      NotificationService.showValidationError(
        context,
        'No place found. Please try again with a different filter.',
      );
    }
  }

  // Clear the route from the map
  void _clearRoute() {
    _mapController.clearRoute();
  }

  // Show alternative routes to the selected place
  Future<void> _showAlternativeRoutes() async {
    // Use selected place if available, otherwise use nearest place
    final place = _selectedPlace ?? _nearestPlace;
    if (place != null) {
      final success = await _mapController.showAlternativeRoutes();
      if (!success && mounted) {
        NotificationService.showValidationError(
          context,
          'Could not show alternative routes. Please try again.',
        );
      }
    } else if (mounted) {
      NotificationService.showValidationError(
        context,
        'No place found. Please try again with a different filter.',
      );
    }
  }
}
