import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:road_helperr/models/user_location.dart';
import 'package:road_helperr/services/firebase_help_request_service.dart';
import 'package:road_helperr/services/notification_service.dart';
import 'package:road_helperr/services/api_service.dart';
import 'package:road_helperr/ui/screens/chat_screen.dart';
import 'package:road_helperr/ui/widgets/user_rating_dialog.dart';
import 'package:road_helperr/ui/widgets/user_ratings_bottom_sheet.dart';

class UserDetailsBottomSheet extends StatefulWidget {
  final UserLocation user;
  final LatLng currentUserLocation;

  const UserDetailsBottomSheet({
    super.key,
    required this.user,
    required this.currentUserLocation,
  });

  static Future<void> show(
    BuildContext context,
    UserLocation user,
    LatLng currentUserLocation,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserDetailsBottomSheet(
        user: user,
        currentUserLocation: currentUserLocation,
      ),
    );
  }

  @override
  State<UserDetailsBottomSheet> createState() => _UserDetailsBottomSheetState();
}

class _UserDetailsBottomSheetState extends State<UserDetailsBottomSheet> {
  bool _isLoading = false;
  bool _isSendingRequest = false;
  Map<String, dynamic>? _userData;
  bool _isGoogleUser = false;

  @override
  void initState() {
    super.initState();
    _checkUserType();
    _fetchUserData();
  }

  void _checkUserType() {
    _isGoogleUser = FirebaseAuth.instance.currentUser != null;
  }

  Future<void> _fetchUserData() async {
    if (widget.user.userId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // تحديد نوع المستخدم بناءً على userId format
      // مستخدمو Google لديهم userId عادي، المستخدمون العاديون لديهم userId يحتوي على _gmail_com
      final isGoogleUser = !widget.user.userId.contains('_gmail_com');

      debugPrint(
          '🔍 UserDetailsBottomSheet: Fetching data for user ${widget.user.userId}');
      debugPrint('🔍 UserDetailsBottomSheet: Is Google user: $isGoogleUser');
      debugPrint('🔍 UserDetailsBottomSheet: User email: ${widget.user.email}');

      Map<String, dynamic> userData = {};

      if (isGoogleUser && widget.user.email.isNotEmpty) {
        // مستخدمو Google يستخدموا فقط API واحد محدد: /api/datagoogle
        debugPrint(
            '🔍 UserDetailsBottomSheet: Google user detected - using ONLY datagoogle API');
        debugPrint(
            '🔍 UserDetailsBottomSheet: Fetching from http://81.10.91.96:8132/api/datagoogle');

        try {
          final response =
              await ApiService.getGoogleUserData(widget.user.email);

          if (response['success'] == true && response['data'] != null) {
            final apiData = response['data']['user'] ?? response['data'];
            debugPrint(
                '✅ UserDetailsBottomSheet: Google API data received from datagoogle: $apiData');

            userData = {
              'name':
                  '${apiData['firstName'] ?? ''} ${apiData['lastName'] ?? ''}'
                      .trim(),
              'carModel': apiData['car_model'] ?? 'Unknown',
              'carColor': apiData['car_color'] ?? 'Unknown',
              'plateNumber': apiData['car_number'] ?? 'Unknown',
              'phone': apiData['phone'],
              'email': apiData['email'],
            };

            debugPrint(
                '✅ UserDetailsBottomSheet: Successfully processed Google user data from datagoogle API');
          } else {
            debugPrint(
                '❌ UserDetailsBottomSheet: Failed to get Google user data from datagoogle API');
            // استخدام البيانات المتاحة من UserLocation كـ fallback
            userData = {
              'name': widget.user.userName,
              'carModel': widget.user.carModel ?? 'Unknown',
              'carColor': widget.user.carColor ?? 'Unknown',
              'plateNumber': widget.user.plateNumber ?? 'Unknown',
            };
          }
        } catch (e) {
          debugPrint(
              '❌ UserDetailsBottomSheet: Error fetching Google user data from datagoogle API: $e');
          // استخدام البيانات المتاحة من UserLocation كـ fallback
          userData = {
            'name': widget.user.userName,
            'carModel': widget.user.carModel ?? 'Unknown',
            'carColor': widget.user.carColor ?? 'Unknown',
            'plateNumber': widget.user.plateNumber ?? 'Unknown',
          };
        }
      } else {
        // مستخدم عادي - استخدام البيانات المتاحة من UserLocation
        debugPrint(
            '🔍 UserDetailsBottomSheet: Using traditional user data from UserLocation');
        userData = {
          'name': widget.user.userName,
          'carModel': widget.user.carModel ?? 'Unknown',
          'carColor': widget.user.carColor ?? 'Unknown',
          'plateNumber': widget.user.plateNumber ?? 'Unknown',
        };
      }

      debugPrint('📊 UserDetailsBottomSheet: Final user data: $userData');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _userData = userData;
        });
      }
    } catch (e) {
      debugPrint('❌ UserDetailsBottomSheet: Error in _fetchUserData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userData = {
            'name': widget.user.userName,
            'carModel': widget.user.carModel ?? 'Unknown',
            'carColor': widget.user.carColor ?? 'Unknown',
            'plateNumber': widget.user.plateNumber ?? 'Unknown',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user data: $e')),
        );
      }
    }
  }

  Future<void> _sendHelpRequest() async {
    if (_isSendingRequest) return;

    // Check if current user is Google authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Show message for traditional users
      if (mounted) {
        NotificationService.showError(
          context: context,
          title: "Feature Not Available",
          message:
              'Help request system is not available for your account right now. Please sign up with a Google account to access this feature.',
        );
      }
      return;
    }

    setState(() {
      _isSendingRequest = true;
    });

    try {
      // إظهار رسالة تحضيرية
      debugPrint(
          '📤 UserDetailsBottomSheet: Sending help request to ${widget.user.userName}...');

      final requestId = await FirebaseHelpRequestService().sendHelpRequest(
        receiverId: widget.user.userId,
        receiverName: widget.user.userName,
        senderLocation: widget.currentUserLocation,
        receiverLocation: widget.user.position,
        message: 'I need help with my car. Can you assist me?',
      );

      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });

        // Close the bottom sheet
        Navigator.of(context).pop();

        // Show detailed success message
        NotificationService.showSuccess(
          context: context,
          title: 'تم إرسال طلب المساعدة بنجاح ✅',
          message: 'تم إرسال طلب المساعدة إلى ${widget.user.userName} بنجاح.\n'
              'رقم الطلب: ${requestId.substring(0, 8)}...\n'
              'سيتم إشعارك عند الرد على طلبك.',
        );

        // إظهار SnackBar إضافي للتأكيد
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم إرسال طلب المساعدة بنجاح إلى ${widget.user.userName}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // بدء مراقبة التسليم
        _startDeliveryMonitoring(requestId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });

        // رسالة خطأ مفصلة
        String errorMessage = 'فشل في إرسال طلب المساعدة';
        if (e.toString().contains('timeout')) {
          errorMessage =
              'انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى.';
        } else if (e.toString().contains('User not authenticated')) {
          errorMessage = 'يرجى تسجيل الدخول مرة أخرى والمحاولة.';
        } else if (e.toString().contains('Failed to deliver notification')) {
          errorMessage =
              'تم حفظ الطلب ولكن فشل في إرسال الإشعار. سيتم إعادة المحاولة تلقائياً.';
        } else if (e.toString().contains('notification_failed')) {
          errorMessage =
              'تم إرسال طلب المساعدة بنجاح! قد يكون هناك تأخير في وصول الإشعار للمستخدم.';
        }

        NotificationService.showError(
          context: context,
          title: 'خطأ في الإرسال',
          message: errorMessage,
        );
      }
    }
  }

  /// بدء مراقبة تسليم الطلب
  void _startDeliveryMonitoring(String requestId) {
    // يمكن إضافة مراقبة إضافية هنا إذا لزم الأمر
    debugPrint(
        '🔍 UserDetailsBottomSheet: Started monitoring delivery for request: $requestId');
  }

  void _openChat() {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(otherUser: widget.user),
      ),
    );
  }

  void _showRatingDialog() async {
    final result = await UserRatingDialog.show(context, widget.user);
    if (result == true) {
      // Rating submitted successfully
      _fetchUserData(); // Refresh user data to show updated rating
    }
  }

  void _showRatings() {
    UserRatingsBottomSheet.show(context, widget.user);
  }

  Future<void> _createRouteToUser() async {
    Navigator.of(context).pop();

    // Get the MapController from context or through a callback
    // This is a placeholder - implement according to your app's structure
    // mapController.createRouteToUser(widget.user);

    NotificationService.showSuccess(
      context: context,
      title: 'Route Created',
      message: 'Route to ${widget.user.userName} has been created.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;
    final cardWidth = isDesktop ? 600.0 : size.width;

    return Container(
      width: cardWidth,
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? (size.width - cardWidth) / 2 : 0,
        vertical: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1F3551), // Dark blue background like Figma
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.star, color: Colors.amber),
                      onPressed: _showRatings,
                      tooltip: 'View Ratings',
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Colors.blue),
                      onPressed: _openChat,
                      tooltip: 'Chat',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_userData != null)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B88C9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // User Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        _buildFigmaInfoText(
                            'Name : ${_userData!['name'] ?? 'Unknown'}'),
                        const SizedBox(height: 6),
                        // Car Model
                        _buildFigmaInfoText(
                            'Car Model : ${_userData!['carModel'] ?? 'Unknown'}'),
                        const SizedBox(height: 6),
                        // Car Color
                        _buildFigmaInfoText(
                            'Car Color : ${_userData!['carColor'] ?? 'Unknown'}'),
                        const SizedBox(height: 6),
                        // Plate Number
                        _buildFigmaInfoText(
                            'Plate Number : ${_userData!['plateNumber'] ?? 'Unknown'}'),
                        const SizedBox(height: 12),
                        // Rating placeholder
                        Row(
                          children: List.generate(5, (index) {
                            return const Icon(
                              Icons.star_border,
                              color: Colors.amber,
                              size: 18,
                            );
                          }),
                        ),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildNavigateButton(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRateButton(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Send Help Request Button
                        SizedBox(
                          width: double.infinity,
                          child: _buildHelpRequestButton(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('No user data available'),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFigmaInfoText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.5,
        letterSpacing: -0.352,
        color: Colors.white,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _buildNavigateButton() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton.icon(
        onPressed: _createRouteToUser,
        icon: const Icon(Icons.directions, color: Colors.white, size: 18),
        label: const Text(
          'Navigate',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildRateButton() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton.icon(
        onPressed: _showRatingDialog,
        icon: const Icon(Icons.star, color: Colors.white, size: 18),
        label: const Text(
          'Rate',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpRequestButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: _isGoogleUser
            ? const LinearGradient(
                colors: [Color(0xFF01122A), Color(0xFF033E90)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed:
            _isGoogleUser && !_isSendingRequest ? _sendHelpRequest : null,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSendingRequest
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isGoogleUser
                    ? 'Send Help Request'
                    : 'Help Request (Google Account Required)',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w500,
                  fontSize: _isGoogleUser ? 16 : 14,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
