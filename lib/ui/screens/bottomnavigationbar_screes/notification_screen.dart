import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:road_helperr/models/help_request.dart';
import 'package:road_helperr/models/notification_model.dart';

import 'package:road_helperr/services/notification_manager.dart';
import 'package:road_helperr/services/firebase_help_request_service.dart';
import 'package:road_helperr/ui/widgets/help_request_dialog.dart';
import 'package:road_helperr/ui/screens/ai_welcome_screen.dart';

import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/map_screen.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/profile_screen.dart';

import '../../../utils/app_colors.dart';
import 'home_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class NotificationScreen extends StatefulWidget {
  static const String routeName = "notification";

  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _selectedIndex = 3; // Removed const since we need to update it

  final NotificationManager _notificationManager = NotificationManager();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // تحميل الإشعارات
  Future<void> _loadNotifications() async {
    try {
      debugPrint('📱 NotificationScreen: Starting to load notifications...');

      // تحميل الإشعارات من NotificationManager
      final notifications = await _notificationManager.getAllNotifications();

      debugPrint(
          '📨 NotificationScreen: Loaded ${notifications.length} notifications');

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;

          // إضافة إشعار ترحيبي إذا لم توجد إشعارات
          if (_notifications.isEmpty) {
            _notifications = [
              NotificationModel(
                id: 'welcome_notification',
                title: 'مرحباً بك في Road Helper',
                body:
                    'نحن سعداء لانضمامك إلينا! يمكنك الآن طلب المساعدة من المستخدمين القريبين.',
                type: 'welcome',
                timestamp: DateTime.now(),
                isRead: false,
              ),
            ];
          }
        });
      }
    } catch (e) {
      debugPrint('❌ NotificationScreen: خطأ في تحميل الإشعارات: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // مسح جميع الإشعارات
  Future<void> _clearAllNotifications() async {
    try {
      await _notificationManager.clearAllNotifications();

      if (mounted) {
        setState(() {
          _notifications = [];
        });
      }
    } catch (e) {
      debugPrint('خطأ في مسح الإشعارات: $e');
    }
  }

  // حذف إشعار محدد
  Future<void> _removeNotification(String notificationId) async {
    try {
      await _notificationManager.removeNotification(notificationId);

      if (mounted) {
        setState(() {
          _notifications
              .removeWhere((notification) => notification.id == notificationId);
        });
      }
    } catch (e) {
      debugPrint('خطأ في حذف الإشعار: $e');
    }
  }

  // تعليم إشعار كمقروء
  Future<void> _markAsRead(NotificationModel notification) async {
    if (!notification.isRead) {
      try {
        await _notificationManager.markAsRead(notification.id);

        if (mounted) {
          setState(() {
            notification.isRead = true;
          });
        }
      } catch (e) {
        debugPrint('خطأ في تعليم الإشعار كمقروء: $e');
      }
    }
  }

  // عرض محتوى الإشعار
  Future<void> _showNotificationContent(NotificationModel notification) async {
    // تعليم الإشعار كمقروء
    await _markAsRead(notification);

    // عرض محتوى الإشعار حسب نوعه
    if (notification.type == 'help_request') {
      await _showHelpRequestDialog(notification);
    } else if (notification.type == 'update') {
      // معالجة إشعار التحديث - يمكن إضافة منطق التحديث هنا
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notification.title),
            content: Text(notification.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } else if (mounted) {
      // عرض محتوى الإشعارات الأخرى
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(notification.title),
          content: Text(notification.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  // عرض حوار طلب المساعدة
  Future<void> _showHelpRequestDialog(NotificationModel notification) async {
    try {
      if (notification.data == null) {
        debugPrint('لا توجد بيانات لطلب المساعدة');
        return;
      }

      debugPrint('بيانات الإشعار: ${notification.data}');

      // تحويل بيانات الإشعار إلى كائن HelpRequest
      try {
        final request = HelpRequest.fromJson(notification.data!);

        // عرض الحوار
        final result = await HelpRequestDialog.show(context, request);

        // إذا استجاب المستخدم للطلب، قم بحذف الإشعار
        if (result != null) {
          await _removeNotification(notification.id);
        }
      } catch (parseError) {
        debugPrint('خطأ في تحويل البيانات إلى HelpRequest: $parseError');

        // عرض حوار بديل مع البيانات المتاحة
        _showSimpleHelpRequestDialog(notification);
      }
    } catch (e) {
      debugPrint('خطأ في عرض حوار طلب المساعدة: $e');
    }
  }

  // عرض حوار بسيط لطلب المساعدة عند فشل التحويل
  Future<void> _showSimpleHelpRequestDialog(
      NotificationModel notification) async {
    final data = notification.data!;

    // البيانات قد تكون في data مباشرة أو في data['requestData']
    final requestData = data['requestData'] as Map<String, dynamic>? ?? data;

    final senderName = requestData['senderName'] ?? 'Unknown User';
    final senderPhone = requestData['senderPhone'] ?? 'N/A';
    final senderCarModel = requestData['senderCarModel'] ?? 'N/A';
    final senderCarColor = requestData['senderCarColor'] ?? 'N/A';
    final senderPlateNumber = requestData['senderPlateNumber'] ?? 'N/A';
    final requestId =
        data['requestId'] ?? requestData['requestId'] ?? notification.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 372,
          height: 219,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
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
                      _buildSimpleInfoText('Name : $senderName'),
                      const SizedBox(height: 4),
                      // Phone
                      _buildSimpleInfoText('phone : $senderPhone'),
                      const SizedBox(height: 4),
                      // Car kind
                      _buildSimpleInfoText('car kind : $senderCarModel'),
                      const SizedBox(height: 4),
                      // Car color
                      _buildSimpleInfoText('car color : $senderCarColor'),
                      const SizedBox(height: 4),
                      // Car number
                      _buildSimpleInfoText('car num: $senderPlateNumber'),
                      const SizedBox(height: 8),
                      // Rating placeholder (no rating data available)
                      Row(
                        children: List.generate(5, (index) {
                          return const Icon(
                            Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                      const Spacer(),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildSimpleRejectButton(requestId),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSimpleAcceptButton(requestId),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleInfoText(String text) {
    return Text(
      text,
      style: ArabicFontHelper.getAlmaraiTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.black,
        height: 1.5, // line-height 150%
        letterSpacing: -0.352, // letter-spacing -2.2%
      ).copyWith(
        fontFamily: ArabicFontHelper.isArabic(context)
            ? ArabicFontHelper.getAlmaraiFont(context)
            : 'Roboto',
      ),
    );
  }

  Widget _buildSimpleRejectButton(String requestId) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1F3551),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          _respondToHelpRequest(requestId, false);
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Reject',
          style: ArabicFontHelper.getTajawalTextStyle(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ).copyWith(
            fontFamily: ArabicFontHelper.isArabic(context)
                ? ArabicFontHelper.getTajawalFont(context)
                : 'Roboto',
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleAcceptButton(String requestId) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF01122A), Color(0xFF033E90)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          _respondToHelpRequest(requestId, true);
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Accept',
          style: ArabicFontHelper.getTajawalTextStyle(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ).copyWith(
            fontFamily: ArabicFontHelper.isArabic(context)
                ? ArabicFontHelper.getTajawalFont(context)
                : 'Roboto',
          ),
        ),
      ),
    );
  }

  // الرد على طلب المساعدة
  Future<void> _respondToHelpRequest(String requestId, bool accept) async {
    // Check if current user is Google authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Show message for traditional users
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Help request system is not available for your account right now. Please sign up with a Google account to access this feature.'),
          ),
        );
      }
      return;
    }

    try {
      await FirebaseHelpRequestService().respondToHelpRequest(
        requestId: requestId,
        accept: accept,
        estimatedArrival: accept ? '10-15 minutes' : null,
      );

      // إزالة الإشعار بعد الرد
      await _removeNotification(requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(accept ? 'تم قبول طلب المساعدة' : 'تم رفض طلب المساعدة'),
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في الرد على طلب المساعدة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الرد على طلب المساعدة'),
          ),
        );
      }
    }
  }

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
        double subtitleSize = titleSize * 0.8;
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
        double spacing = size.height * 0.02;

        return platform == TargetPlatform.iOS ||
                platform == TargetPlatform.macOS
            ? _buildCupertinoLayout(context, size, titleSize, subtitleSize,
                iconSize, navBarHeight, spacing, isDesktop)
            : _buildMaterialLayout(context, size, titleSize, subtitleSize,
                iconSize, navBarHeight, spacing, isDesktop);
      },
    );
  }

  Widget _buildMaterialLayout(
    BuildContext context,
    Size size,
    double titleSize,
    double subtitleSize,
    double iconSize,
    double navBarHeight,
    double spacing,
    bool isDesktop,
  ) {
    var lang = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF01122A),
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF01122A),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            size: iconSize,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.noNotifications,
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _clearAllNotifications,
            child: Text(
              lang.clearAll,
              style: ArabicFontHelper.getTajawalTextStyle(
                context,
                fontSize: subtitleSize,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.light
                    ? AppColors.getSwitchColor(context)
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(
          context, size, titleSize, subtitleSize, spacing, isDesktop),
      bottomNavigationBar:
          _buildMaterialNavBar(context, iconSize, navBarHeight, isDesktop),
    );
  }

  Widget _buildCupertinoLayout(
    BuildContext context,
    Size size,
    double titleSize,
    double subtitleSize,
    double iconSize,
    double navBarHeight,
    double spacing,
    bool isDesktop,
  ) {
    var lang = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : AppColors.getCardColor(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : AppColors.getCardColor(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.back,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            size: iconSize,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          lang.noNotifications,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            fontSize: titleSize,
            fontFamily: '.SF Pro Text',
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _clearAllNotifications,
          child: Text(
            lang.clearAll,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? AppColors.getSwitchColor(context)
                  : Colors.white,
              fontSize: subtitleSize,
              fontFamily: '.SF Pro Text',
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildBody(
                  context, size, titleSize, subtitleSize, spacing, isDesktop),
            ),
            _buildCupertinoNavBar(context, iconSize, navBarHeight, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Size size,
    double titleSize,
    double subtitleSize,
    double spacing,
    bool isDesktop,
  ) {
    final platform = Theme.of(context).platform;
    final isIOS =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    var lang = AppLocalizations.of(context)!;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 800 : 600,
        ),
        padding: EdgeInsets.all(size.width * 0.04),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          Theme.of(context).brightness == Brightness.light
                              ? "assets/images/notification light.png"
                              : "assets/images/Group 12.png",
                          width: size.width * (isDesktop ? 0.3 : 0.5),
                          height: size.height * 0.25,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: spacing * 3),
                        Text(
                          lang.noNotifications,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? AppColors.getSwitchColor(context)
                                    : const Color(0xFFA0A0A0),
                            fontSize: titleSize,
                            fontWeight: FontWeight.w600,
                            fontFamily: isIOS ? '.SF Pro Text' : null,
                          ),
                        ),
                        SizedBox(height: spacing * 1.5),
                        Text(
                          lang.notificationInboxEmpty,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? AppColors.getSwitchColor(context)
                                    : const Color(0xFFA0A0A0),
                            fontSize: subtitleSize,
                            fontFamily: isIOS ? '.SF Pro Text' : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];

                      // عرض جميع أنواع الإشعارات
                      return _buildNotificationItem(
                        context,
                        notification,
                        titleSize,
                        subtitleSize,
                      );
                    },
                  ),
      ),
    );
  }

  // تنسيق الوقت بنظام 12 ساعة
  String _formatTime(DateTime timestamp) {
    // تحويل إلى نظام 12 ساعة
    int hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    // إذا كانت الساعة 0 (منتصف الليل)، عرضها كـ 12
    hour = hour == 0 ? 12 : hour;
    String period = timestamp.hour >= 12 ? 'م' : 'ص';

    return '${hour.toString()}:${timestamp.minute.toString().padLeft(2, '0')} $period';
  }

  // بناء عنصر الإشعار
  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notification,
    double titleSize,
    double subtitleSize,
  ) {
    // إذا كان إشعار help_request، استخدم التصميم الجديد
    if (notification.type == 'help_request') {
      return _buildHelpRequestNotificationCard(notification);
    }

    // للإشعارات الأخرى، استخدم التصميم العادي
    final timestamp = notification.timestamp;
    final timeString = _formatTime(timestamp);
    final dateString = '${timestamp.day}/${timestamp.month}/${timestamp.year}';

    // تحديد لون الخلفية بناءً على حالة القراءة
    final backgroundColor = notification.isRead
        ? Colors.transparent
        : Theme.of(context).brightness == Brightness.light
            ? Colors.blue.withOpacity(0.1)
            : Colors.blue.withOpacity(0.2);

    // تحديد أيقونة الإشعار حسب النوع
    IconData notificationIcon;
    Color iconColor = Colors.white;
    Color iconBackgroundColor = AppColors.getSwitchColor(context);

    switch (notification.type) {
      case 'update':
        notificationIcon = Icons.system_update;
        iconBackgroundColor = Colors.green;
        break;
      case 'system_message':
        notificationIcon = Icons.info_outline;
        iconBackgroundColor = Colors.orange;
        break;
      default:
        notificationIcon = Icons.notifications_none;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      child: InkWell(
        onTap: () => _showNotificationContent(notification),
        child: Container(
          color: backgroundColor,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconBackgroundColor,
              child: Icon(notificationIcon, color: iconColor),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontSize: titleSize * 0.8,
                fontWeight:
                    notification.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: TextStyle(fontSize: subtitleSize * 0.9),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$timeString - $dateString',
                  style: TextStyle(
                    fontSize: subtitleSize * 0.8,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            trailing: notification.isRead
                ? null
                : Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpRequestNotificationCard(NotificationModel notification) {
    final data = notification.data ?? {};

    // البيانات قد تكون في data مباشرة أو في data['requestData']
    final requestData = data['requestData'] as Map<String, dynamic>? ?? data;

    final senderName = requestData['senderName'] ?? 'Unknown User';
    final senderPhone = requestData['senderPhone'] ?? 'N/A';
    final senderCarModel = requestData['senderCarModel'] ?? 'N/A';
    final senderCarColor = requestData['senderCarColor'] ?? 'N/A';
    final senderPlateNumber = requestData['senderPlateNumber'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: double.infinity,
        minHeight: 142, // حسب المواصفات المطلوبة
        maxHeight: 142, // ثابت لمنع التمدد
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNotificationContent(notification),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // User Avatar - 54x54 حسب المواصفات
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
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // User Information
                Expanded(
                  child: SizedBox(
                    height: 118, // ارتفاع ثابت لمنع الـ overflow
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Name
                        _buildNotificationInfoText('Name: $senderName'),
                        // Phone
                        _buildNotificationInfoText('Phone: $senderPhone'),
                        // Car Model
                        _buildNotificationInfoText('Car: $senderCarModel'),
                        // Car Color
                        _buildNotificationInfoText('Color: $senderCarColor'),
                        // Plate Number
                        _buildNotificationInfoText('Plate: $senderPlateNumber'),
                        // Rating
                        Row(
                          children: List.generate(5, (index) {
                            return const Icon(
                              Icons.star_border,
                              color: Colors.amber,
                              size: 12,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                // Unread indicator
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationInfoText(String text) {
    return Text(
      text,
      style: ArabicFontHelper.getAlmaraiTextStyle(
        context,
        fontSize: 12, // حجم أصغر لتجنب الـ overflow
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        height: 1.3, // ارتفاع سطر مضبوط
        letterSpacing: -0.264, // -2.2% letter spacing (12 * -0.022 = -0.264)
      ).copyWith(
        fontFamily: ArabicFontHelper.isArabic(context)
            ? ArabicFontHelper.getAlmaraiFont(context)
            : 'Roboto',
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _buildMaterialNavBar(
    BuildContext context,
    double iconSize,
    double navBarHeight,
    bool isDesktop,
  ) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 1200 : double.infinity,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        child: CurvedNavigationBar(
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF01122A),
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFF023A87)
              : const Color(0xFF1F3551),
          buttonBackgroundColor:
              Theme.of(context).brightness == Brightness.light
                  ? const Color(0xFF023A87)
                  : const Color(0xFF1F3551),
          animationDuration: const Duration(milliseconds: 300),
          height: 45,
          index: _selectedIndex,
          letIndexChange: (index) => true,
          items: [
            Icon(Icons.home_outlined, size: iconSize, color: Colors.white),
            Icon(Icons.location_on_outlined,
                size: iconSize, color: Colors.white),
            Icon(Icons.textsms_outlined, size: iconSize, color: Colors.white),
            Icon(Icons.notifications_outlined,
                size: iconSize, color: Colors.white),
            Icon(Icons.person_2_outlined, size: iconSize, color: Colors.white),
          ],
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            _handleNavigation(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildCupertinoNavBar(
    BuildContext context,
    double iconSize,
    double navBarHeight,
    bool isDesktop,
  ) {
    var lang = AppLocalizations.of(context)!;
    return Container(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 1200 : double.infinity,
      ),
      child: CupertinoTabBar(
        backgroundColor: AppColors.getBackgroundColor(context),
        activeColor: Colors.white,
        inactiveColor: Colors.white.withOpacity(0.6),
        height: navBarHeight,
        currentIndex: _selectedIndex,
        items: [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home, size: iconSize),
            label: lang.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.location, size: iconSize),
            label: lang.map,
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble, size: iconSize),
            label: lang.chat,
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bell, size: iconSize),
            label: lang.noNotifications,
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person, size: iconSize),
            label: lang.profile,
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _handleNavigation(context, index);
        },
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

    if (index >= 0 && index < routes.length) {
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }
}
