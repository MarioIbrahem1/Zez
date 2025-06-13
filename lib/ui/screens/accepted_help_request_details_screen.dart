import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// شاشة عرض بيانات الشخص عند قبول طلب المساعدة
class AcceptedHelpRequestDetailsScreen extends StatefulWidget {
  static const String routeName = '/accepted-help-request-details';

  final Map<String, dynamic> requestData;

  const AcceptedHelpRequestDetailsScreen({
    super.key,
    required this.requestData,
  });

  @override
  State<AcceptedHelpRequestDetailsScreen> createState() =>
      _AcceptedHelpRequestDetailsScreenState();
}

class _AcceptedHelpRequestDetailsScreenState
    extends State<AcceptedHelpRequestDetailsScreen> {
  double? _distance;
  bool _isCalculatingDistance = true;

  @override
  void initState() {
    super.initState();
    _calculateDistance();
  }

  Future<void> _calculateDistance() async {
    try {
      // الحصول على الموقع الحالي
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // الحصول على موقع الشخص الآخر
      final senderLocation = widget.requestData['senderLocation'];
      if (senderLocation != null) {
        final senderLat = senderLocation['latitude']?.toDouble() ?? 0.0;
        final senderLng = senderLocation['longitude']?.toDouble() ?? 0.0;

        // حساب المسافة
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          senderLat,
          senderLng,
        );

        setState(() {
          _distance = distance / 1000; // تحويل إلى كيلومتر
          _isCalculatingDistance = false;
        });
      } else {
        setState(() {
          _isCalculatingDistance = false;
        });
      }
    } catch (e) {
      debugPrint('Error calculating distance: $e');
      setState(() {
        _isCalculatingDistance = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن إجراء المكالمة')),
        );
      }
    }
  }

  Future<void> _openMaps() async {
    final senderLocation = widget.requestData['senderLocation'];
    if (senderLocation != null) {
      final lat = senderLocation['latitude'];
      final lng = senderLocation['longitude'];
      final Uri mapsUri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
      
      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح الخرائط')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderName = widget.requestData['senderName'] ?? 'Unknown';
    final senderPhone = widget.requestData['senderPhone'] ?? 'N/A';
    final senderCarModel = widget.requestData['senderCarModel'] ?? 'N/A';
    final senderCarColor = widget.requestData['senderCarColor'] ?? 'N/A';
    final senderPlateNumber = widget.requestData['senderPlateNumber'] ?? 'N/A';
    final message = widget.requestData['message'] ?? 'طلب مساعدة';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'تفاصيل طلب المساعدة',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF023A87),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // حالة الطلب
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تم قبول طلب المساعدة بنجاح',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // بيانات الشخص
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العنوان
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B88C9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بيانات طالب المساعدة',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'معلومات الاتصال والسيارة',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // البيانات
                  _buildDetailRow(Icons.person, 'الاسم', senderName),
                  _buildDetailRow(Icons.phone, 'رقم الهاتف', senderPhone, isPhone: true),
                  _buildDetailRow(Icons.directions_car, 'موديل السيارة', senderCarModel),
                  _buildDetailRow(Icons.palette, 'لون السيارة', senderCarColor),
                  _buildDetailRow(Icons.confirmation_number, 'رقم اللوحة', senderPlateNumber),
                  
                  // المسافة
                  _buildDetailRow(
                    Icons.location_on,
                    'المسافة',
                    _isCalculatingDistance
                        ? 'جاري الحساب...'
                        : _distance != null
                            ? '${_distance!.toStringAsFixed(2)} كم'
                            : 'غير متاح',
                  ),

                  const SizedBox(height: 20),

                  // رسالة الطلب
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.message, color: Colors.blue.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'رسالة الطلب',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // أزرار الإجراءات
            Row(
              children: [
                // زر الاتصال
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: senderPhone != 'N/A' ? () => _makePhoneCall(senderPhone) : null,
                    icon: const Icon(Icons.phone, size: 20),
                    label: const Text('اتصال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // زر الخرائط
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.map, size: 20),
                    label: const Text('الموقع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF023A87),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    letterSpacing: -0.264,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    letterSpacing: -0.352,
                  ),
                ),
              ],
            ),
          ),
          if (isPhone && value != 'N/A')
            IconButton(
              onPressed: () => _makePhoneCall(value),
              icon: Icon(
                Icons.phone,
                color: Colors.green.shade600,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
