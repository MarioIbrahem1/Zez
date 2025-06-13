import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:road_helperr/models/help_request.dart';
import 'package:road_helperr/services/firebase_help_request_service.dart';
import 'package:road_helperr/services/notification_service.dart';
import 'package:road_helperr/ui/screens/accepted_help_request_details_screen.dart';

class HelpRequestDialog extends StatefulWidget {
  final HelpRequest request;

  const HelpRequestDialog({
    super.key,
    required this.request,
  });

  static Future<bool?> show(BuildContext context, HelpRequest request) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HelpRequestDialog(request: request),
    );
  }

  @override
  State<HelpRequestDialog> createState() => _HelpRequestDialogState();
}

class _HelpRequestDialogState extends State<HelpRequestDialog> {
  bool _isLoading = false;
  double _userRating = 0.0;
  bool _isLoadingRating = true;

  @override
  void initState() {
    super.initState();
    _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    try {
      // For now, we'll use a default rating since rating system is not available for Google users only
      // This can be implemented later with Firebase-based rating system
      if (mounted) {
        setState(() {
          _userRating = 4.0; // Default rating
          _isLoadingRating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRating = false;
        });
      }
    }
  }

  Future<void> _respondToRequest(bool accept) async {
    if (_isLoading) return;

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
      _isLoading = true;
    });

    try {
      await FirebaseHelpRequestService().respondToHelpRequest(
        requestId: widget.request.requestId,
        accept: accept,
        estimatedArrival: accept ? '10-15 minutes' : null,
      );

      if (mounted) {
        Navigator.of(context).pop(accept);

        // إذا تم قبول الطلب، انتقل لشاشة التفاصيل
        if (accept) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AcceptedHelpRequestDetailsScreen(
                requestData: widget.request.toJson(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        NotificationService.showError(
          context: context,
          title: "Error",
          message: 'Failed to respond to help request: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxWidth: 350,
          maxHeight: 280,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with avatar and name
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B88C9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.senderName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _buildRatingRow(),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // User Information in a clean layout
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.phone, 'Phone',
                        widget.request.senderPhone ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.directions_car, 'Car',
                        widget.request.senderCarModel ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.palette, 'Color',
                        widget.request.senderCarColor ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.confirmation_number, 'Plate',
                        widget.request.senderPlateNumber ?? 'N/A'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildRejectButton(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAcceptButton(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow() {
    if (_isLoadingRating) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < _userRating.round() ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 16,
          );
        }),
        const SizedBox(width: 4),
        Text(
          '(${_userRating.toStringAsFixed(1)})',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildRejectButton() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1F3551),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: _isLoading ? null : () => _respondToRequest(false),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Reject',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptButton() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF01122A), Color(0xFF033E90)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: _isLoading ? null : () => _respondToRequest(true),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Accept',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
