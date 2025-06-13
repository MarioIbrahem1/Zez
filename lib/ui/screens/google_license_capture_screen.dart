import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:road_helperr/ui/screens/car_google.dart';

class GoogleLicenseCaptureScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const GoogleLicenseCaptureScreen({
    super.key,
    required this.userData,
  });

  static const String routeName = "google_license_capture_screen";

  @override
  State<GoogleLicenseCaptureScreen> createState() =>
      _GoogleLicenseCaptureScreenState();
}

class _GoogleLicenseCaptureScreenState extends State<GoogleLicenseCaptureScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _isShowingFront = true;
  bool _showImagePreview = false;

  File? _frontImage;
  File? _backImage;
  File? _capturedImagePreview;

  late AnimationController _flipController;
  late AnimationController _pulseController;
  late Animation<double> _flipAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
  }

  void _initializeAnimations() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Capture image function
  Future<void> _captureImage() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        return;
      }

      final XFile image = await _cameraController!.takePicture();

      // Show image preview for confirmation
      setState(() {
        _capturedImagePreview = File(image.path);
        _showImagePreview = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  // Confirm captured image
  void _confirmImage() {
    if (_capturedImagePreview != null) {
      setState(() {
        if (_isShowingFront) {
          _frontImage = _capturedImagePreview;
        } else {
          _backImage = _capturedImagePreview;
        }
        _showImagePreview = false;
        _capturedImagePreview = null;
      });

      // If front is captured, flip to back
      if (_isShowingFront && _backImage == null) {
        _flipToBack();
      }
    }
  }

  // Retake image
  void _retakeImage() {
    setState(() {
      _showImagePreview = false;
      _capturedImagePreview = null;
    });
  }

  // Flip to back side
  void _flipToBack() {
    setState(() {
      _isShowingFront = false;
    });
    _flipController.forward();
  }

  // Continue to car settings with license images
  void _continueToCarSettings() {
    if (_frontImage != null && _backImage != null) {
      // Add license images to user data
      final updatedUserData = Map<String, dynamic>.from(widget.userData);
      updatedUserData['frontLicense'] = _frontImage;
      updatedUserData['backLicense'] = _backImage;

      // Navigate to car settings screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CarGoogleScreen(
            userData: updatedUserData,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please capture both sides of your license"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isLight ? Colors.white : const Color(0xFF01122A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, lang, isLight, size),

            // Main content
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Instructions
                  _buildInstructions(context, lang, isLight, size),

                  const SizedBox(height: 30),

                  // License frame
                  Expanded(
                    child: _buildLicenseFrame(context, lang, isLight, size),
                  ),

                  const SizedBox(height: 30),

                  // Controls
                  _buildControls(context, lang, isLight, size),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build header
  Widget _buildHeader(
      BuildContext context, AppLocalizations lang, bool isLight, Size size) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios,
              color: isLight ? const Color(0xFF023A87) : Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              "Driving License Capture",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size.width * 0.05,
                fontWeight: FontWeight.bold,
                color: isLight ? const Color(0xFF023A87) : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  // Build instructions
  Widget _buildInstructions(
      BuildContext context, AppLocalizations lang, bool isLight, Size size) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isLight ? const Color(0xFF86A5D9) : const Color(0xFF1F3551))
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? const Color(0xFF86A5D9) : const Color(0xFF1F3551),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isShowingFront ? Icons.credit_card : Icons.flip_to_back,
            color: isLight ? const Color(0xFF023A87) : const Color(0xFF86A5D9),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isShowingFront
                  ? "Place the front of your license in the frame"
                  : "Flip your license and capture the back side",
              style: TextStyle(
                fontSize: size.width * 0.04,
                color: isLight ? const Color(0xFF023A87) : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build license frame
  Widget _buildLicenseFrame(
      BuildContext context, AppLocalizations lang, bool isLight, Size size) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isShowingFront = _flipAnimation.value < 0.5;
          return Container(
            height: size.height * 0.35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: _showImagePreview
                  ? _buildImagePreview(_capturedImagePreview!, isLight)
                  : Stack(
                      children: [
                        // Camera preview or captured image
                        if (_isCameraInitialized && _cameraController != null)
                          SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: CameraPreview(_cameraController!),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.black,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: isLight
                                    ? const Color(0xFF86A5D9)
                                    : Colors.white,
                              ),
                            ),
                          ),

                        // License preview overlay
                        if (isShowingFront && _frontImage != null)
                          _buildImagePreview(_frontImage!, isLight)
                        else if (!isShowingFront && _backImage != null)
                          _buildImagePreview(_backImage!, isLight)
                        else
                          _buildPlaceholder(
                              lang, isLight, size, isShowingFront),

                        // Corner guides
                        _buildCornerGuides(isLight),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  // Build image preview
  Widget _buildImagePreview(File imageFile, bool isLight) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(imageFile),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // Build placeholder
  Widget _buildPlaceholder(
      AppLocalizations lang, bool isLight, Size size, bool isShowingFront) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isShowingFront ? Icons.credit_card : Icons.flip_to_back,
            size: 60,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(height: 16),
          Text(
            !_isCameraInitialized
                ? "Preparing camera..."
                : isShowingFront
                    ? "Place license here (Front)"
                    : "Place license here (Back)",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size.width * 0.04,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build corner guides
  Widget _buildCornerGuides(bool isLight) {
    final color = isLight ? const Color(0xFF86A5D9) : const Color(0xFF023A87);
    const cornerSize = 30.0;
    const strokeWidth = 3.0;

    return Stack(
      children: [
        // Top-left corner
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: strokeWidth),
                left: BorderSide(color: color, width: strokeWidth),
              ),
            ),
          ),
        ),
        // Top-right corner
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: strokeWidth),
                right: BorderSide(color: color, width: strokeWidth),
              ),
            ),
          ),
        ),
        // Bottom-left corner
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: strokeWidth),
                left: BorderSide(color: color, width: strokeWidth),
              ),
            ),
          ),
        ),
        // Bottom-right corner
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: strokeWidth),
                right: BorderSide(color: color, width: strokeWidth),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build controls
  Widget _buildControls(
      BuildContext context, AppLocalizations lang, bool isLight, Size size) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Image preview controls
          if (_showImagePreview)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _retakeImage,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retake"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirmImage,
                    icon: const Icon(Icons.check),
                    label: const Text("Confirm"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            // Flip button (only show if front is captured)
            if (_frontImage != null && _backImage == null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _flipToBack,
                      icon: const Icon(Icons.flip_to_back),
                      label: const Text("Flip to Back"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLight
                            ? const Color(0xFF86A5D9)
                            : const Color(0xFF023A87),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Capture button
            Row(
              children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isCapturing ? 0.95 : 1.0,
                        child: ElevatedButton.icon(
                          onPressed: _isCapturing ? null : _captureImage,
                          icon: _isCapturing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  size: 24 * _pulseAnimation.value,
                                ),
                          label: Text(
                            _isCapturing
                                ? "Capturing..."
                                : (_isShowingFront && _frontImage == null)
                                    ? "Capture Front"
                                    : (!_isShowingFront && _backImage == null)
                                        ? "Capture Back"
                                        : "Retake",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLight
                                ? const Color(0xFF023A87)
                                : const Color(0xFF86A5D9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Continue button
            if (_frontImage != null && _backImage != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _continueToCarSettings,
                  icon: const Icon(Icons.check_circle),
                  label: const Text("Continue"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
