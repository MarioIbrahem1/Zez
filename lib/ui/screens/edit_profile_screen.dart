import 'package:flutter/material.dart';
import 'package:road_helperr/services/profile_service.dart';
import 'package:road_helperr/models/profile_data.dart';
import 'edit_text_field.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class EditProfileScreen extends StatefulWidget {
  static const String routeName = "EditProfileScreen";
  final String email;
  final ProfileData? initialData;

  const EditProfileScreen({
    super.key,
    required this.email,
    this.initialData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carKindController = TextEditingController();
  final _profileService = ProfileService();
  bool _isLoading = false;
  ProfileData? _profileData;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final nameParts = widget.initialData!.name.split(' ');
      _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
      _lastNameController.text =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      _phoneController.text = widget.initialData!.phone ?? '';
      _emailController.text = widget.initialData!.email;
      _carNumberController.text = widget.initialData!.plateNumber ?? '';
      _carColorController.text = widget.initialData!.carColor ?? '';
      _carKindController.text = widget.initialData!.carModel ?? '';
      _profileData = widget.initialData;
    } else {
      _emailController.text = widget.email;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _carNumberController.dispose();
    _carColorController.dispose();
    _carKindController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final updatedData = ProfileData(
        name:
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                .trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        carModel: _carKindController.text.trim(),
        carColor: _carColorController.text.trim(),
        plateNumber: _carNumberController.text.trim(),
      );
      await _profileService.updateProfileData(widget.email, updatedData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, updatedData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;
    final isLight = Theme.of(context).brightness == Brightness.light;
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
                    : 0.055);
        double iconSize = size.width *
            (isDesktop
                ? 0.015
                : isTablet
                    ? 0.02
                    : 0.025);
        double avatarRadius = size.width *
            (isDesktop
                ? 0.08
                : isTablet
                    ? 0.1
                    : 0.15);
        double padding = size.width *
            (isDesktop
                ? 0.03
                : isTablet
                    ? 0.04
                    : 0.05);

        return Scaffold(
          backgroundColor: isLight ? Colors.white : const Color(0xFF01122A),
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_outlined,
                color: isLight ? Colors.black : Colors.white,
                size: iconSize * 1.2,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              lang.editProfile,
              style: ArabicFontHelper.getCairoTextStyle(
                context,
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: isLight ? Colors.black : Colors.white,
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Container(
                    constraints:
                        BoxConstraints(maxWidth: isDesktop ? 1200 : 800),
                    padding: EdgeInsets.all(padding),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: size.height * 0.04),
                          Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: avatarRadius,
                                  backgroundColor: isLight
                                      ? const Color(0xFF86A5D9)
                                      : Colors.transparent,
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: avatarRadius * 2,
                                      height: avatarRadius * 2,
                                      child: _profileData?.profileImage != null
                                          ? Image.network(
                                              _profileData!.profileImage!,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: isLight
                                                  ? const Color(0xFF86A5D9)
                                                  : const Color(0xFF2C4874),
                                              child: Icon(
                                                Icons.person,
                                                size: avatarRadius,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: size.height * 0.03),
                          EditTextField(
                            label: lang.firstName,
                            icon: Icons.person,
                            iconSize: 20,
                            controller: _firstNameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name';
                              }
                              return null;
                            },
                          ),
                          EditTextField(
                            label: lang.lastName,
                            icon: Icons.person,
                            iconSize: 20,
                            controller: _lastNameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your last name';
                              }
                              return null;
                            },
                          ),
                          EditTextField(
                            label: lang.phoneNumber,
                            icon: Icons.phone,
                            iconSize: 20,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          EditTextField(
                            label: lang.email,
                            icon: Icons.email,
                            iconSize: 20,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: false,
                          ),
                          SizedBox(height: size.height * 0.04),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: InkWell(
                              onTap: () {
                                carSettingsModalBottomSheet(context);
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: Colors.transparent,
                                  border: Border.all(
                                    color:
                                        isLight ? Colors.black87 : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      size: 20,
                                      color: isLight
                                          ? Colors.black87
                                          : Colors.white,
                                    ),
                                    SizedBox(width: size.width * 0.04),
                                    Text(
                                      lang.carSettings,
                                      style:
                                          ArabicFontHelper.getTajawalTextStyle(
                                        context,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: isLight
                                            ? Colors.black87
                                            : Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: isLight
                                          ? Colors.black87
                                          : Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.05),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SizedBox(
                              height: 50,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _updateProfile,
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                    const Color(0xFF023A87),
                                  ),
                                  shape: WidgetStateProperty.all<
                                      RoundedRectangleBorder>(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30.0),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  lang.updateChanges,
                                  style: ArabicFontHelper.getTajawalTextStyle(
                                    context,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  void carSettingsModalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final isLight = Theme.of(context).brightness == Brightness.light;
        var lang = AppLocalizations.of(context)!;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: size.height * 0.5,
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF01122A),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    lang.carSettings,
                    style: ArabicFontHelper.getTajawalTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isLight ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildCarSettingInput(
                          lang.carNumber,
                          Icons.confirmation_number,
                          _carNumberController,
                          isLight,
                        ),
                        const SizedBox(height: 16),
                        _buildCarSettingInput(
                          lang.carColor,
                          Icons.palette,
                          _carColorController,
                          isLight,
                        ),
                        const SizedBox(height: 16),
                        _buildCarSettingInput(
                          lang.carKind,
                          Icons.directions_car,
                          _carKindController,
                          isLight,
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarSettingInput(
    String title,
    IconData icon,
    TextEditingController controller,
    bool isLight,
  ) {
    final textColor = isLight ? Colors.black87 : Colors.white;
    final borderColor = isLight ? Colors.black87 : Colors.white;

    return TextFormField(
      controller: controller,
      style: ArabicFontHelper.getAlmaraiTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: textColor,
        ),
        labelText: title,
        labelStyle: ArabicFontHelper.getAlmaraiTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: borderColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.transparent,
      ),
    );
  }
}
