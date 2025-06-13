import 'package:flutter/material.dart';
import 'package:road_helperr/ui/public_details/main_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_helperr/ui/screens/bottomnavigationbar_screes/home_screen.dart';
import 'package:road_helperr/ui/screens/email_screen.dart';
import 'package:road_helperr/ui/screens/signupScreen.dart';
import 'package:road_helperr/services/api_service.dart';
import 'package:road_helperr/services/auth_service.dart';
import 'package:road_helperr/services/notification_service.dart';
import 'package:road_helperr/utils/app_colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:road_helperr/services/fcm_token_manager.dart';
import 'package:road_helperr/services/google_auth_service.dart';
import 'package:road_helperr/utils/arabic_font_helper.dart';

class SignInScreen extends StatefulWidget {
  static const String routeName = "signinscreen";

  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool status = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    debugPrint('Starting Google Sign-In process from signin_screen...');

    // استخدام خدمة المصادقة المخصصة
    final GoogleAuthService authService = GoogleAuthService();

    try {
      // محاولة تسجيل الدخول باستخدام الطريقة البديلة
      final Map<String, dynamic>? userData =
          await authService.signInWithGoogleAlternative();

      if (userData == null) {
        debugPrint('تم إلغاء تسجيل الدخول بواسطة المستخدم');
        throw Exception('Google Sign In was cancelled by user');
      }

      debugPrint('تم تسجيل الدخول بنجاح: ${userData['email']}');
      return userData;
    } catch (e) {
      debugPrint('خطأ في تسجيل الدخول باستخدام Google: ${e.toString()}');
      throw Exception('Error during Google sign-in: ${e.toString()}');
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // تحميل البيانات فقط إذا كان المستخدم قد اختار "تذكرني" صراحة
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (rememberMe) {
        // تحميل البيانات من المفاتيح المحفوظة
        emailController.text = prefs.getString('remember_me_email') ??
            prefs.getString('email') ??
            '';
        passwordController.text = prefs.getString('remember_me_password') ??
            prefs.getString('password') ??
            '';
        status = true;
      } else {
        // عدم تحميل أي بيانات إذا لم يختر المستخدم "تذكرني"
        emailController.text = '';
        passwordController.text = '';
        status = false;
      }
    });

    debugPrint(
        '📥 Loaded user data - Email: ${emailController.text}, Remember: $status');
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (status) {
      // حفظ بيانات "تذكرني" بالمفاتيح الصحيحة
      await prefs.setString('email', emailController.text);
      await prefs.setString('password', passwordController.text);
      await prefs.setBool('rememberMe', status);

      // حفظ بيانات "تذكرني" بالمفاتيح التي يتوقعها AuthService
      await prefs.setString('remember_me_email', emailController.text);
      await prefs.setString('remember_me_password', passwordController.text);

      debugPrint('💾 Remember me data saved for: ${emailController.text}');
    } else {
      // حذف جميع بيانات "تذكرني"
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.remove('rememberMe');
      await prefs.remove('remember_me_email');
      await prefs.remove('remember_me_password');

      debugPrint('🗑️ Remember me data cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Size mediaQuery = MediaQuery.of(context).size;
    final Color textColor = isLight ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor:
          isLight ? const Color(0xFFF5F8FF) : const Color(0xFF1F3551),
      body: SafeArea(
        child: Container(
          height: mediaQuery.height,
          color: isLight ? const Color(0xFFF5F8FF) : const Color(0xFF1F3551),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header Image
                Container(
                  width: mediaQuery.width,
                  height: mediaQuery.height * 0.28,
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(
                            0xFF86A5D9) // لون خلفية الصورة في وضع الإضاءة
                        : const Color(0xFF1F3551),
                    image: DecorationImage(
                      image: AssetImage(
                        isLight
                            ? "assets/images/OnBoardingLight.png"
                            : "assets/images/rafiki.png",
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: mediaQuery.height * 0.02),

                // Main Content
                Container(
                  width: mediaQuery.width,
                  // تعديل ارتفاع الحاوية لتمتد إلى أسفل الشاشة
                  constraints: BoxConstraints(
                    minHeight: mediaQuery.height * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : const Color(0xFF01122A),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: mediaQuery.width * 0.05,
                      vertical: mediaQuery.height * 0.02,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            lang.welcomeBack,
                            style: ArabicFontHelper.getCairoTextStyle(
                              context,
                              fontSize: mediaQuery.width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: mediaQuery.height * 0.03),

                          // Email Input
                          InputField(
                            icon: Icons.email_outlined,
                            hintText: lang.enterYourEmail,
                            label: lang.email,
                            validatorIsContinue: (emailText) {
                              final regExp = RegExp(
                                  r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                              if (emailText == null || emailText.isEmpty) {
                                return lang.pleaseEnterYourEmail;
                              }
                              if (!regExp.hasMatch(emailText)) {
                                return lang.pleaseEnterAValidEmail;
                              }
                              return null;
                            },
                            controller: emailController,
                          ),
                          SizedBox(height: mediaQuery.height * 0.02),

                          // Password Input
                          InputField(
                            icon: Icons.lock,
                            hintText: lang.enterYourPassword,
                            label: lang.password,
                            isPassword: true,
                            validatorIsContinue: (passwordText) {
                              if (passwordText == null ||
                                  passwordText.isEmpty) {
                                return lang.pleaseEnterYourPassword;
                              }
                              if (passwordText.length < 6) {
                                return lang.passwordMustBeAtLeast6Characters;
                              }
                              return null;
                            },
                            controller: passwordController,
                          ),
                          SizedBox(height: mediaQuery.height * 0.01),

                          // Remember Me & Forgot Password
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.9,
                                    child: Checkbox(
                                      value: status,
                                      onChanged: (value) {
                                        setState(() {
                                          status = value!;
                                        });
                                      },
                                      fillColor: WidgetStateProperty.all(
                                        isLight
                                            ? AppColors.getCardColor(context)
                                            : Colors.white,
                                      ),
                                      checkColor: isLight
                                          ? Colors.white
                                          : AppColors.getBackgroundColor(
                                              context),
                                    ),
                                  ),
                                  Text(
                                    lang.rememberMe,
                                    style: ArabicFontHelper.getTajawalTextStyle(
                                      context,
                                      fontSize: mediaQuery.width * 0.035,
                                      fontWeight: FontWeight.w400,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context)
                                      .pushNamed(EmailScreen.routeName);
                                },
                                child: Text(
                                  lang.forgotPassword,
                                  style: ArabicFontHelper.getTajawalTextStyle(
                                    context,
                                    fontSize: mediaQuery.width * 0.035,
                                    fontWeight: FontWeight.w400,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: mediaQuery.height * 0.02),

                          // Login Button
                          MainButton(
                            textButton: lang.login,
                            onPress: () async {
                              if (_formKey.currentState!.validate()) {
                                try {
                                  final response = await ApiService.login(
                                    emailController.text,
                                    passwordController.text,
                                  );

                                  if (!mounted) return;

                                  if (response['error'] != null) {
                                    if (mounted) {
                                      NotificationService
                                          .showInvalidCredentials(context);
                                    }
                                  } else {
                                    debugPrint(
                                        '🎉 Login successful! Processing response...');

                                    // Save user data if remember me is checked
                                    if (status) {
                                      await _saveUserData();
                                      debugPrint('✅ Remember me data saved');
                                    }

                                    // Save logged in user email and auth type
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString('logged_in_email',
                                        emailController.text);
                                    await prefs.setBool('is_google_sign_in',
                                        false); // تسجيل دخول تقليدي
                                    debugPrint('✅ Logged in email saved');
                                    debugPrint(
                                        '✅ Auth type saved: Traditional');

                                    // Save FCM token for the logged in user
                                    try {
                                      final fcmTokenManager = FCMTokenManager();
                                      final tokenSaved = await fcmTokenManager
                                          .saveTokenOnLogin();
                                      if (tokenSaved) {
                                        debugPrint(
                                            '✅ FCM token saved for regular user');
                                      } else {
                                        debugPrint(
                                            '⚠️ Failed to save FCM token for regular user');
                                      }
                                    } catch (e) {
                                      debugPrint(
                                          '❌ Error saving FCM token: $e');
                                    }

                                    // التحقق من أن البيانات تم حفظها بواسطة API service
                                    final authService = AuthService();
                                    final isLoggedIn =
                                        await authService.isLoggedIn();
                                    debugPrint(
                                        '🔍 Login status after API call: $isLoggedIn');

                                    if (!isLoggedIn) {
                                      debugPrint(
                                          '⚠️ Auth data not saved by API service, saving manually...');
                                      if (response['token'] != null) {
                                        await authService.saveAuthData(
                                          token: response['token'],
                                          userId: response['user_id'] ?? '',
                                          email: emailController.text,
                                          name: response['name'],
                                          isGoogleSignIn:
                                              false, // تسجيل دخول تقليدي
                                          enablePersistentLogin:
                                              status, // حفظ حالة "تذكرني"
                                        );
                                        debugPrint(
                                            '✅ Auth data saved manually');
                                      }
                                    }

                                    // Traditional SQL users logged in successfully
                                    // Help request system is not available for traditional users
                                    debugPrint(
                                        '✅ Traditional user logged in successfully');

                                    // Show success message before navigation
                                    if (mounted) {
                                      NotificationService.showLoginSuccess(
                                        context,
                                        onConfirm: () {
                                          if (mounted) {
                                            Navigator.of(context)
                                                .pushReplacementNamed(
                                                    HomeScreen.routeName);
                                          }
                                        },
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    NotificationService.showNetworkError(
                                        context);
                                  }
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // Google Sign In Button
                          InkWell(
                            onTap: () async {
                              try {
                                // Show loading indicator
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                );

                                // استخدام دالة تسجيل الدخول المحدثة
                                final userData = await signInWithGoogle();

                                // Close loading dialog
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }

                                if (!mounted) return;

                                if (userData != null) {
                                  // حفظ بريد المستخدم ونوع المصادقة
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString('logged_in_email',
                                      userData['email'].toString());
                                  await prefs.setBool('is_google_sign_in',
                                      true); // تسجيل دخول Google
                                  debugPrint('✅ Auth type saved: Google');

                                  // Google user logged in successfully
                                  // Help request system is available for Google users
                                  debugPrint(
                                      '✅ Google user logged in successfully - Help requests enabled');

                                  // توجيه المستخدم مباشرة إلى الشاشة الرئيسية عند تسجيل الدخول
                                  if (mounted) {
                                    NotificationService.showLoginSuccess(
                                      context,
                                      onConfirm: () {
                                        if (mounted) {
                                          Navigator.of(context)
                                              .pushReplacementNamed(
                                                  HomeScreen.routeName);
                                        }
                                      },
                                    );
                                  }
                                }
                              } catch (e) {
                                // Close loading dialog if it's still showing
                                if (mounted) {
                                  // Check if dialog is showing before popping
                                  try {
                                    Navigator.of(context).pop();
                                  } catch (dialogError) {
                                    // Dialog might not be showing, ignore error
                                  }

                                  final BuildContext currentContext = context;
                                  if (e
                                      .toString()
                                      .contains('PigeonUserDetails')) {
                                    // For PigeonUserDetails error, we'll try to navigate anyway
                                    // since the user is likely authenticated in Firebase
                                    final authService = GoogleAuthService();
                                    if (authService.isUserSignedIn()) {
                                      final currentUser =
                                          authService.getCurrentUser();
                                      if (currentUser != null) {
                                        // توجيه المستخدم مباشرة إلى الشاشة الرئيسية عند تسجيل الدخول
                                        NotificationService.showLoginSuccess(
                                          currentContext,
                                          onConfirm: () {
                                            Navigator.of(currentContext)
                                                .pushReplacementNamed(
                                                    HomeScreen.routeName);
                                          },
                                        );
                                      }
                                    } else {
                                      final lang =
                                          AppLocalizations.of(currentContext)!;
                                      showDialog(
                                        context: currentContext,
                                        builder: (context) => AlertDialog(
                                          title: Text(lang.error),
                                          content: const Text(
                                              'There is a problem signing in with Google. Please try again later.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: Text(lang.ok),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } else {
                                    NotificationService.showNetworkError(
                                        currentContext);
                                  }
                                }
                              }
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                color: isLight
                                    ? const Color(0xFF023A87)
                                    : const Color(0xFF1F3551),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google.png',
                                    height: 24,
                                    width: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    lang.signInWithGoogle,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: mediaQuery.width * 0.04,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: mediaQuery.height * 0.02),

                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                lang.dontHaveAnAccount,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: mediaQuery.width * 0.035,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context)
                                      .pushNamed(SignupScreen.routeName);
                                },
                                child: Text(
                                  lang.register,
                                  style: TextStyle(
                                    color: isLight
                                        ? AppColors.getTextStackColor(context)
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: mediaQuery.width * 0.035,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// InputField Widget يدعم الثيم الدايناميك
class InputField extends StatefulWidget {
  final IconData icon;
  final String hintText;
  final String label;
  final bool isPassword;
  final String? Function(String?)? validatorIsContinue;
  final TextEditingController controller;

  const InputField({
    super.key,
    required this.icon,
    required this.hintText,
    required this.label,
    this.isPassword = false,
    this.validatorIsContinue,
    required this.controller,
  });

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;
    final Color textColor = isLightMode ? Colors.black : Colors.white;
    var width = MediaQuery.of(context).size.width;

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _isObscure : false,
      validator: widget.validatorIsContinue,
      style: TextStyle(
        color: textColor,
        fontSize: width * 0.04,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          widget.icon,
          color: textColor,
          size: width * 0.055,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure ? Icons.visibility_off : Icons.visibility,
                  color: textColor,
                  size: width * 0.055,
                ),
                onPressed: () {
                  setState(() {
                    _isObscure = !_isObscure;
                  });
                },
              )
            : null,
        hintText: widget.hintText,
        labelText: widget.label,
        labelStyle: TextStyle(
          color: textColor,
          fontSize: width * 0.04,
        ),
        hintStyle: TextStyle(
          color: isLightMode ? Colors.grey[600] : Colors.white54,
          fontSize: width * 0.035,
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: width * 0.04,
          horizontal: width * 0.04,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(width * 0.04),
          borderSide: BorderSide(
            color: textColor,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(width * 0.04),
          borderSide: BorderSide(
            color: textColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(width * 0.04),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(width * 0.04),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: isLightMode ? Colors.white : Colors.transparent,
      ),
    );
  }
}
