import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/sos_user_data.dart';
import '../../services/sos_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/arabic_font_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SOSEmergencyContactsScreen extends StatefulWidget {
  static const String routeName = '/sos-emergency-contacts';

  const SOSEmergencyContactsScreen({super.key});

  @override
  State<SOSEmergencyContactsScreen> createState() =>
      _SOSEmergencyContactsScreenState();
}

class _SOSEmergencyContactsScreenState
    extends State<SOSEmergencyContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final List<TextEditingController> _contactControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  /// تحميل البيانات المحفوظة عند فتح الشاشة
  Future<void> _loadSavedData() async {
    try {
      final sosService = SOSService();
      final savedData = await sosService.getUserData();

      if (savedData != null) {
        // ملء الحقول بالبيانات المحفوظة
        _firstNameController.text = savedData.firstName;
        _middleNameController.text = savedData.middleName;
        _lastNameController.text = savedData.lastName;
        _ageController.text = savedData.age.toString();

        // ملء جهات الاتصال الطارئة
        for (int i = 0;
            i < savedData.emergencyContacts.length &&
                i < _contactControllers.length;
            i++) {
          _contactControllers[i].text = savedData.emergencyContacts[i];
        }

        debugPrint('✅ SOS Emergency Contacts: Loaded saved data successfully');
      } else {
        debugPrint('ℹ️ SOS Emergency Contacts: No saved data found');
      }
    } catch (e) {
      debugPrint('❌ SOS Emergency Contacts: Error loading saved data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    for (var controller in _contactControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _validatePhoneNumbers() {
    final contacts = _contactControllers
        .map((controller) => controller.text.trim())
        .where((contact) => contact.isNotEmpty)
        .toList();

    // Check if we have at least one contact
    if (contacts.isEmpty) {
      return false;
    }

    // Normalize phone numbers (remove spaces and special characters)
    final normalizedContacts = contacts
        .map((contact) => contact.replaceAll(RegExp(r'[^0-9]'), ''))
        .toList();

    // Check if all phone numbers are exactly 11 digits and start with valid prefixes
    for (int i = 0; i < normalizedContacts.length; i++) {
      final contact = normalizedContacts[i];
      if (contact.length != 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'ar'
                ? 'يجب أن تكون جهة الاتصال الطارئة ${i + 1} 11 رقماً بالضبط'
                : 'Emergency Contact ${i + 1} must be exactly 11 digits'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // Check if it starts with valid Egyptian mobile prefixes
      if (!contact.startsWith('010') &&
          !contact.startsWith('011') &&
          !contact.startsWith('012') &&
          !contact.startsWith('015')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'ar'
                ? 'يجب أن تبدأ جهة الاتصال الطارئة ${i + 1} بـ 010 أو 011 أو 012 أو 015'
                : 'Emergency Contact ${i + 1} must start with 010, 011, 012, or 015'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    // Check for duplicates
    final uniqueContacts = normalizedContacts.toSet();
    if (uniqueContacts.length != normalizedContacts.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Localizations.localeOf(context).languageCode == 'ar'
              ? 'يجب أن تكون جهات الاتصال الطارئة مختلفة عن بعضها البعض'
              : 'Emergency contacts must be different from each other'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  /// مسح البيانات المحفوظة والبدء من جديد
  void _clearSavedData() async {
    try {
      // مسح البيانات من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sosUserData');

      // مسح الحقول
      _firstNameController.clear();
      _middleNameController.clear();
      _lastNameController.clear();
      _ageController.clear();
      for (var controller in _contactControllers) {
        controller.clear();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'ar'
                ? 'تم مسح بيانات جهات الاتصال الطارئة بنجاح'
                : 'Emergency contact data cleared successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'ar'
                ? 'خطأ في مسح البيانات: $e'
                : 'Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveUserData() async {
    if (_formKey.currentState!.validate() && _validatePhoneNumbers()) {
      try {
        final userData = SOSUserData(
          firstName: _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          age: int.parse(_ageController.text),
          emergencyContacts: _contactControllers
              .map((controller) =>
                  controller.text.trim().replaceAll(RegExp(r'[^0-9]'), ''))
              .where((contact) => contact.isNotEmpty)
              .toList(),
        );

        await SOSService().setUserData(userData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم حفظ معلومات جهات الاتصال الطارئة بنجاح!\nسيتم الاحتفاظ ببياناتك لتنبيهات SOS.'
                  : 'Emergency contact information saved successfully!\nYour data will be preserved for SOS alerts.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          // Navigate back
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Localizations.localeOf(context).languageCode == 'ar'
                  ? 'خطأ في حفظ البيانات: $e'
                  : 'Error saving data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor:
          isLight ? const Color(0xFFF5F8FF) : AppColors.primaryColor,
      appBar: AppBar(
        title: Text(
          lang?.emergencyContactInformation ?? 'Emergency Contact Information',
          style: ArabicFontHelper.getCairoTextStyle(
            context,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isLight ? const Color(0xFF023A87) : Colors.white,
          ),
        ),
        backgroundColor:
            isLight ? const Color(0xFF86A5D9) : AppColors.primaryColor,
        foregroundColor: isLight ? const Color(0xFF023A87) : Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: isLight ? const Color(0xFF023A87) : Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang?.loadingSavedEmergencyContacts ??
                        'Loading saved emergency contacts...',
                    style: ArabicFontHelper.getTajawalTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isLight ? const Color(0xFF47609A) : Colors.white70,
                    ),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                    lang?.setupEmergencyContactsForSOS ??
                        'Set up your emergency contacts for SOS alerts',
                    style: ArabicFontHelper.getTajawalTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isLight ? const Color(0xFF47609A) : Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // First Name
                  _buildTextField(
                    controller: _firstNameController,
                    label: lang?.firstName ?? 'First Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lang?.pleaseEnterFirstName ??
                            'Please enter your first name';
                      }
                      if (!RegExp(r'^[a-zA-Zأ-ي\s]+$').hasMatch(value)) {
                        return lang?.firstNameLettersOnly ??
                            'First name should contain only letters';
                      }
                      if (value.length < 3) {
                        return lang?.firstNameMinLength ??
                            'First name should be at least 3 characters';
                      }
                      if (value.length > 13) {
                        return lang?.firstNameMaxLength ??
                            'First name should not exceed 13 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Middle Name
                  _buildTextField(
                    controller: _middleNameController,
                    label: Localizations.localeOf(context).languageCode == 'ar'
                        ? 'الاسم الأوسط'
                        : 'Middle Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يرجى إدخال اسمك الأوسط'
                            : 'Please enter your middle name';
                      }
                      if (!RegExp(r'^[a-zA-Zأ-ي\s]+$').hasMatch(value)) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب أن يحتوي الاسم الأوسط على أحرف فقط'
                            : 'Middle name should contain only letters';
                      }
                      if (value.length < 3) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب أن يكون الاسم الأوسط 3 أحرف على الأقل'
                            : 'Middle name should be at least 3 characters';
                      }
                      if (value.length > 13) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب ألا يتجاوز الاسم الأوسط 13 حرفاً'
                            : 'Middle name should not exceed 13 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Last Name
                  _buildTextField(
                    controller: _lastNameController,
                    label: lang?.lastName ?? 'Last Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يرجى إدخال اسمك الأخير'
                            : 'Please enter your last name';
                      }
                      if (!RegExp(r'^[a-zA-Zأ-ي\s]+$').hasMatch(value)) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب أن يحتوي الاسم الأخير على أحرف فقط'
                            : 'Last name should contain only letters';
                      }
                      if (value.length < 3) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب أن يكون الاسم الأخير 3 أحرف على الأقل'
                            : 'Last name should be at least 3 characters';
                      }
                      if (value.length > 13) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب ألا يتجاوز الاسم الأخير 13 حرفاً'
                            : 'Last name should not exceed 13 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Age
                  _buildTextField(
                    controller: _ageController,
                    label: Localizations.localeOf(context).languageCode == 'ar'
                        ? 'العمر'
                        : 'Age',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يرجى إدخال عمرك'
                            : 'Please enter your age';
                      }
                      final age = int.tryParse(value);
                      if (age == null) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يرجى إدخال عمر صحيح'
                            : 'Please enter a valid age';
                      }
                      if (age < 18) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب أن يكون العمر 18 سنة على الأقل'
                            : 'Age must be at least 18 years old';
                      }
                      if (age > 100) {
                        return Localizations.localeOf(context).languageCode ==
                                'ar'
                            ? 'يجب أن يكون العمر أقل من 100 سنة'
                            : 'Age must be less than 100 years old';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? 'جهات الاتصال في الطوارئ (أدخل واحدة على الأقل)'
                        : 'Emergency Contacts (Enter at least one)',
                    style: ArabicFontHelper.getCairoTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isLight ? const Color(0xFF023A87) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emergency Contacts
                  ...List.generate(3, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: _buildTextField(
                        controller: _contactControllers[index],
                        label:
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'جهة الاتصال الطارئة ${index + 1}'
                                : 'Emergency Contact ${index + 1}',
                        hintText:
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'أدخل رقم الهاتف'
                                : 'Enter phone number',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (index == 0 && (value == null || value.isEmpty)) {
                            return Localizations.localeOf(context)
                                        .languageCode ==
                                    'ar'
                                ? 'يرجى إدخال جهة اتصال طارئة واحدة على الأقل'
                                : 'Please enter at least one emergency contact';
                          }
                          if (value != null && value.isNotEmpty) {
                            // Remove any spaces or special characters and keep only digits
                            final digitsOnly =
                                value.replaceAll(RegExp(r'[^0-9]'), '');
                            if (digitsOnly.length != 11) {
                              return Localizations.localeOf(context)
                                          .languageCode ==
                                      'ar'
                                  ? 'يجب أن يكون رقم الهاتف 11 رقماً بالضبط'
                                  : 'Phone number must be exactly 11 digits';
                            }
                            // Check if it starts with valid Egyptian mobile prefixes
                            if (!digitsOnly.startsWith('010') &&
                                !digitsOnly.startsWith('011') &&
                                !digitsOnly.startsWith('012') &&
                                !digitsOnly.startsWith('015')) {
                              return Localizations.localeOf(context)
                                          .languageCode ==
                                      'ar'
                                  ? 'يجب أن يبدأ رقم الهاتف بـ 010 أو 011 أو 012 أو 015'
                                  : 'Phone number must start with 010, 011, 012, or 015';
                            }
                          }
                          return null;
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 30),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'حفظ معلومات الطوارئ'
                            : 'Save Emergency Information',
                        style: ArabicFontHelper.getTajawalTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Clear Data Button (Optional)
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton(
                      onPressed: () {
                        // Show confirmation dialog
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            final dialogIsLight =
                                Theme.of(context).brightness ==
                                    Brightness.light;
                            return AlertDialog(
                              backgroundColor: dialogIsLight
                                  ? Colors.white
                                  : const Color(0xFF1F3551),
                              title: Text(
                                lang?.clearEmergencyData ??
                                    'Clear Emergency Data',
                                style: ArabicFontHelper.getCairoTextStyle(
                                  context,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: dialogIsLight
                                      ? const Color(0xFF023A87)
                                      : Colors.white,
                                ),
                              ),
                              content: Text(
                                lang?.clearEmergencyDataConfirmation ??
                                    'Are you sure you want to clear all saved emergency contact information? This action cannot be undone.',
                                style: ArabicFontHelper.getTajawalTextStyle(
                                  context,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: dialogIsLight
                                      ? const Color(0xFF47609A)
                                      : Colors.white70,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    Localizations.localeOf(context)
                                                .languageCode ==
                                            'ar'
                                        ? 'إلغاء'
                                        : 'Cancel',
                                    style: ArabicFontHelper.getTajawalTextStyle(
                                      context,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: dialogIsLight
                                          ? const Color(0xFF47609A)
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _clearSavedData();
                                  },
                                  child: Text(
                                    Localizations.localeOf(context)
                                                .languageCode ==
                                            'ar'
                                        ? 'مسح'
                                        : 'Clear',
                                    style: ArabicFontHelper.getTajawalTextStyle(
                                      context,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: isLight
                                ? const Color(0xFF86A5D9)
                                : Colors.white54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'مسح البيانات المحفوظة'
                            : 'Clear Saved Data',
                        style: ArabicFontHelper.getTajawalTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isLight
                              ? const Color(0xFF47609A)
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: ArabicFontHelper.getAlmaraiTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: isLight ? const Color(0xFF023A87) : Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: ArabicFontHelper.getAlmaraiTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: isLight ? const Color(0xFF47609A) : Colors.white70,
        ),
        hintText: hintText,
        hintStyle: ArabicFontHelper.getAlmaraiTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: isLight ? const Color(0xFF86A5D9) : Colors.white38,
        ),
        filled: true,
        fillColor: isLight ? Colors.white : Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(
              color: isLight ? const Color(0xFF86A5D9) : Colors.white54,
              width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(
              color: isLight ? const Color(0xFF86A5D9) : Colors.white54,
              width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(
              color: isLight ? const Color(0xFF023A87) : Colors.blue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: validator,
    );
  }
}
