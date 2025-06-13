import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:road_helperr/models/help_request.dart';
import 'package:road_helperr/models/user_rating.dart';
import 'package:road_helperr/services/auth_service.dart';
import 'package:road_helperr/services/firebase_user_location_service.dart';
import 'package:road_helperr/services/firebase_rating_service.dart';

import 'package:path_provider/path_provider.dart' as path_provider;

class ApiService {
  static const String baseUrl = 'http://81.10.91.96:8132';
//
  // Get token from auth service
  static Future<String> _getToken() async {
    final authService = AuthService();
    final token = await authService.getToken() ?? '';
    debugPrint(
        'Retrieved token: ${token.isNotEmpty ? 'Token exists' : 'Token is empty'}');
    return token;
  }

  // Check internet connectivity
  static Future<bool> _checkConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      bool hasConnection =
          !connectivityResult.contains(ConnectivityResult.none);
      debugPrint('Internet connection available: $hasConnection');
      return hasConnection;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  // Login API
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    if (!await _checkConnectivity()) {
      return {
        'error':
            'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى'
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // حفظ بيانات المصادقة مع تمكين persistent login
        if (responseData['token'] != null) {
          final authService = AuthService();
          await authService.saveAuthData(
            token: responseData['token'],
            userId: responseData['user_id'] ?? '',
            email: email,
            name: responseData['name'],
            enablePersistentLogin: true, // تمكين persistent login افتراضياً
          );
          debugPrint(
              'تم حفظ بيانات المصادقة بعد تسجيل الدخول مع persistent login');
        }

        return responseData;
      } else {
        final errorBody = json.decode(response.body);
        return {
          'error':
              'فشل تسجيل الدخول: ${errorBody['message'] ?? 'خطأ غير معروف'} (كود الخطأ: ${response.statusCode})'
        };
      }
    } catch (e) {
      if (e is http.ClientException) {
        return {
          'error':
              'فشل الاتصال بالخادم: ${e.message}. تأكد من صحة عنوان الخادم والبورت'
        };
      }
      return {'error': 'حدث خطأ غير متوقع: $e'};
    }
  }

  // Send OTP API
  static Future<Map<String, dynamic>> sendOTP(String email) async {
    if (!await _checkConnectivity()) {
      return {
        'success': false,
        'error':
            'No internet connection. Please check your connection and try again'
      };
    }

    try {
      final requestData = {'email': email};
      debugPrint('Sending OTP request to: $baseUrl/otp/send');
      debugPrint('Request data: ${jsonEncode(requestData)}');
      debugPrint(
          'Request headers: {"Content-Type": "application/json", "Accept": "application/json"}');

      final response = await http.post(
        Uri.parse('$baseUrl/otp/send'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');
      debugPrint('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP sent successfully'
        };
      } else if (response.statusCode == 404) {
        // إذا كان البريد الإلكتروني غير موجود
        return {
          'success': false,
          'error': 'This email is not registered in our system'
        };
      } else if (response.statusCode == 400) {
        // إذا كان هناك خطأ في تنسيق البريد الإلكتروني
        return {'success': false, 'error': 'Invalid email format'};
      } else {
        // أي خطأ آخر من الخادم
        return {
          'success': false,
          'error':
              responseData['message'] ?? 'Server error. Please try again later'
        };
      }
    } catch (e) {
      debugPrint('Error in sendOTP: $e');
      if (e is http.ClientException) {
        return {
          'success': false,
          'error':
              'Connection error. Please check your internet connection and try again'
        };
      }
      return {
        'success': false,
        'error':
            'An unexpected error occurred while sending OTP. Please try again'
      };
    }
  }

  // Send OTP Without Verification (for signup only)
  static Future<Map<String, dynamic>> sendOTPWithoutVerification(
      String email) async {
    if (!await _checkConnectivity()) {
      return {
        'success': false,
        'error':
            'No internet connection. Please check your connection and try again'
      };
    }

    try {
      final requestData = {'email': email};
      debugPrint(
          'Sending OTP without verification request to: $baseUrl/otp/send-without-verification');
      debugPrint('Request data: ${jsonEncode(requestData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/otp/send-without-verification'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP sent successfully'
        };
      } else if (response.statusCode == 400) {
        return {'success': false, 'error': 'Invalid email format'};
      } else {
        return {
          'success': false,
          'error':
              responseData['message'] ?? 'Server error. Please try again later'
        };
      }
    } catch (e) {
      debugPrint('Error in sendOTPWithoutVerification: $e');
      if (e is http.ClientException) {
        return {
          'success': false,
          'error':
              'Connection error. Please check your internet connection and try again'
        };
      }
      return {
        'success': false,
        'error':
            'An unexpected error occurred while sending OTP. Please try again'
      };
    }
  }

  // Register API - Updated to verify OTP first and upload license
  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> userData, String otp) async {
    if (!await _checkConnectivity()) {
      return {
        'error':
            'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى'
      };
    }

    try {
      // OTP verification is already done in OTP screen, proceed directly with registration
      final String email = userData['email'];
      debugPrint('Proceeding with registration for email: $email');
      debugPrint('OTP was already verified in OTP screen');

      // رفع الرخصة أولاً إذا كانت متوفرة
      if (userData['frontLicense'] != null && userData['backLicense'] != null) {
        debugPrint('Uploading license before registration...');

        try {
          final licenseResponse = await uploadLicense(
            email: email,
            frontImage: userData['frontLicense'],
            backImage: userData['backLicense'],
          );

          if (licenseResponse['success'] == true) {
            // حفظ روابط الصور في البيانات
            userData['front_license_url'] = licenseResponse['front_image_url'];
            userData['back_license_url'] = licenseResponse['back_image_url'];
            debugPrint('License uploaded successfully');
          } else {
            debugPrint('License upload failed: ${licenseResponse['error']}');
            // المتابعة حتى لو فشل رفع الرخصة
          }
        } catch (e) {
          debugPrint('License upload error: $e');
          // المتابعة حتى لو فشل رفع الرخصة
        }

        // إزالة ملفات الصور من البيانات قبل الإرسال للسيرفر
        userData.remove('frontLicense');
        userData.remove('backLicense');
      }

      debugPrint('Registration data being sent: $userData');

      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      debugPrint('Registration response status: ${response.statusCode}');
      debugPrint('Registration response body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
          'message': 'تم التسجيل بنجاح'
        };
      } else {
        final errorBody = json.decode(response.body);
        return {
          'error':
              'فشل التسجيل: ${errorBody['message'] ?? 'خطأ غير معروف'} (كود الخطأ: ${response.statusCode})'
        };
      }
    } catch (e) {
      debugPrint('Error during registration process: $e');
      if (e is http.ClientException) {
        return {
          'error':
              'فشل الاتصال بالخادم: ${e.message}. تأكد من صحة عنوان الخادم والبورت'
        };
      }
      return {'error': 'حدث خطأ غير متوقع: $e'};
    }
  }

  // Verify OTP API - Improved with better error handling
  static Future<Map<String, dynamic>> verifyOTP(
      String email, String otp) async {
    if (!await _checkConnectivity()) {
      return {'error': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      debugPrint('Verifying OTP request to: $baseUrl/otp/verify');
      debugPrint('Data being sent: email=$email, otp=$otp');

      final response = await http.post(
        Uri.parse('$baseUrl/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');
      debugPrint('Response body: ${response.body}');

      try {
        final responseData = jsonDecode(response.body);
        debugPrint('Decoded response: $responseData');

        if (response.statusCode == 200) {
          return {
            'success': true,
            'message': responseData['message'] ?? 'تم التحقق بنجاح'
          };
        } else if (response.statusCode == 400 || response.statusCode == 401) {
          return {'error': responseData['message'] ?? 'رمز التحقق غير صحيح'};
        } else {
          return {
            'error': 'حدث خطأ في التحقق من الرمز (${response.statusCode})'
          };
        }
      } catch (e) {
        debugPrint('Error decoding response: $e');
        return {'error': 'تنسيق استجابة غير صالح من الخادم'};
      }
    } catch (e) {
      debugPrint('Error in verifyOTP: $e');
      return {'error': 'حدث خطأ أثناء التحقق من الرمز: $e'};
    }
  }

  // Check if email exists using the API endpoint
  static Future<Map<String, dynamic>> checkEmailExists(String email) async {
    try {
      // Check connectivity first
      if (!await _checkConnectivity()) {
        debugPrint('=== فحص البريد الإلكتروني ===');
        debugPrint('❌ لا يوجد اتصال بالإنترنت');
        debugPrint('============================');
        return {
          'success': false,
          'exists': false,
          'message': 'No internet connection',
        };
      }

      // تحضير بيانات الطلب
      final Map<String, dynamic> requestData = {'email': email};

      // Send GET request with email in body (using http.Request for more control)
      final request =
          http.Request('GET', Uri.parse('$baseUrl/api/check-email'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';
      request.body = jsonEncode(requestData);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          // Based on the Postman screenshot, we expect:
          // {"status": "success", "message": "Email does not exist"} when email doesn't exist

          if (data.containsKey('status')) {
            // Get the message from the response
            final message = data['message'] ?? '';
            final status = data['status'];

            // Exactly as shown in Postman:
            // If status is "success" and message is "Email does not exist", email doesn't exist
            if (status == 'success' && message == 'Email does not exist') {
              return {
                'success': true,
                'exists': false,
                'message': 'البريد الإلكتروني غير موجود في النظام',
                'message_en': 'Email does not exist in the system',
              };
            }
            // If status is not success or message indicates email exists
            else {
              return {
                'success': true,
                'exists': true,
                'message': 'هذا البريد الإلكتروني مرتبط بحساب موجود بالفعل',
                'message_en':
                    'This email is already associated with an existing account',
              };
            }
          }

          // Fallback for other response formats
          return {
            'success': true,
            'exists': false,
            'message': 'تم التحقق من البريد الإلكتروني',
            'message_en': 'Email check completed',
          };
        } catch (e) {
          return {
            'success': false,
            'exists': false,
            'message': 'حدث خطأ أثناء تحليل استجابة الخادم',
            'message_en': 'Invalid response format from server',
          };
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'exists': false,
            'message':
                errorData['message'] ?? 'فشل التحقق من وجود البريد الإلكتروني',
            'message_en':
                errorData['message'] ?? 'Failed to check email existence',
          };
        } catch (e) {
          return {
            'success': false,
            'exists': false,
            'message': 'فشل التحقق من وجود البريد الإلكتروني',
            'message_en': 'Failed to check email existence',
          };
        }
      }
    } catch (e) {
      if (e is http.ClientException) {
        return {
          'success': false,
          'exists': false,
          'message': 'خطأ في الاتصال بالخادم',
          'message_en': 'Connection error',
        };
      }
      return {
        'success': false,
        'exists': false,
        'message': 'حدث خطأ أثناء التحقق من البريد الإلكتروني',
        'message_en': 'An error occurred while checking email',
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String newPassword) async {
    if (!await _checkConnectivity()) {
      return {
        'error':
            'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى'
      };
    }

    try {
      debugPrint(
          'Sending reset password request to: $baseUrl/api/reset-password');
      debugPrint(
          'Data being sent: {"email": "$email", "password": "$newPassword"}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': newPassword,
        }),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message':
              responseData['message'] ?? 'تم إعادة تعيين كلمة المرور بنجاح'
        };
      } else {
        final errorData = jsonDecode(response.body);
        String errorMessage =
            errorData['message'] ?? 'فشل في إعادة تعيين كلمة المرور';

        // تحسين رسائل الخطأ
        if (response.statusCode == 404) {
          errorMessage = 'البريد الإلكتروني غير مسجل في النظام';
        } else if (response.statusCode == 400) {
          errorMessage = 'كلمة المرور الجديدة غير صالحة';
        } else if (response.statusCode == 500) {
          errorMessage = 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقاً';
        }

        return {'error': errorMessage};
      }
    } catch (e) {
      debugPrint('Error in resetPassword: $e');
      if (e is http.ClientException) {
        return {
          'error':
              'فشل الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى'
        };
      }
      return {
        'error':
            'حدث خطأ غير متوقع أثناء إعادة تعيين كلمة المرور. يرجى المحاولة مرة أخرى'
      };
    }
  }

  // Update user's location - Using Firebase as fallback since API is not available
  static Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint(
          '🔄 API: Attempting to update location: $latitude, $longitude');

      // Try API first if connectivity is available
      if (await _checkConnectivity()) {
        try {
          final token = await _getToken();
          if (token.isNotEmpty) {
            debugPrint('📡 API: Trying server update first...');

            final response = await http
                .post(
                  Uri.parse('$baseUrl/update-location'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'latitude': latitude,
                    'longitude': longitude,
                  }),
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              debugPrint('✅ API: Location updated successfully via server');
              return;
            } else {
              debugPrint(
                  '⚠️ API: Server update failed: ${response.statusCode}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ API: Server update failed: $e');
        }
      }

      // Fallback to Firebase since API is not available
      debugPrint('🔥 API: Using Firebase fallback for location update');
      await _updateLocationViaFirebase(latitude, longitude);
    } catch (e) {
      debugPrint('❌ API: Error updating location: $e');
      throw Exception('Error updating location: $e');
    }
  }

  // Firebase fallback for location update
  static Future<void> _updateLocationViaFirebase(
      double latitude, double longitude) async {
    try {
      final locationService = FirebaseUserLocationService();
      await locationService.updateUserLocation(LatLng(latitude, longitude));

      debugPrint('✅ API: Location updated successfully via Firebase');
    } catch (e) {
      debugPrint('❌ API: Firebase location update failed: $e');
      throw Exception('Failed to update location via Firebase: $e');
    }
  }

  // Note: API endpoint for nearby users is not implemented yet
  // Using Firebase Database only for nearby users functionality

  // Get user data by email
  static Future<Map<String, dynamic>> getUserData(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/data'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch user data');
      }
    } catch (e) {
      throw Exception('Error fetching user data: $e');
    }
  }

  // Send help request - Using Firebase as fallback since API is not available
  static Future<Map<String, dynamic>> sendHelpRequest({
    required String receiverId,
    required LatLng senderLocation,
    required LatLng receiverLocation,
    String? message,
    String? receiverName,
  }) async {
    try {
      debugPrint('🔄 API: Attempting to send help request to: $receiverId');

      // Try API first if connectivity is available
      if (await _checkConnectivity()) {
        try {
          final token = await _getToken();
          if (token.isNotEmpty) {
            debugPrint('📡 API: Trying server help request first...');

            final response = await http
                .post(
                  Uri.parse('$baseUrl/help-request/send'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'receiverId': receiverId,
                    'senderLocation': {
                      'latitude': senderLocation.latitude,
                      'longitude': senderLocation.longitude,
                    },
                    'receiverLocation': {
                      'latitude': receiverLocation.latitude,
                      'longitude': receiverLocation.longitude,
                    },
                    'message': message,
                  }),
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              debugPrint('✅ API: Help request sent successfully via server');
              return jsonDecode(response.body);
            } else {
              debugPrint(
                  '⚠️ API: Server help request failed: ${response.statusCode}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ API: Server help request failed: $e');
        }
      }

      // Help requests are now only available for Google authenticated users
      // No fallback to Firebase for traditional users
      throw Exception(
          'Help request system is only available for Google authenticated users');
    } catch (e) {
      debugPrint('❌ API: Error sending help request: $e');
      throw Exception('Error sending help request: $e');
    }
  }

  // Respond to help request - Using Firebase as fallback since API is not available
  static Future<Map<String, dynamic>> respondToHelpRequest({
    required String requestId,
    required bool accept,
    String? estimatedArrival,
  }) async {
    try {
      debugPrint('🔄 API: Attempting to respond to help request: $requestId');

      // Try API first if connectivity is available
      if (await _checkConnectivity()) {
        try {
          final token = await _getToken();
          if (token.isNotEmpty) {
            debugPrint('📡 API: Trying server response first...');

            final response = await http
                .post(
                  Uri.parse('$baseUrl/help-request/respond'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'requestId': requestId,
                    'accept': accept,
                  }),
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              debugPrint(
                  '✅ API: Help request response sent successfully via server');
              return jsonDecode(response.body);
            } else {
              debugPrint(
                  '⚠️ API: Server response failed: ${response.statusCode}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ API: Server response failed: $e');
        }
      }

      // Help request responses are now only available for Google authenticated users
      // No fallback to Firebase for traditional users
      throw Exception(
          'Help request system is only available for Google authenticated users');
    } catch (e) {
      debugPrint('❌ API: Error responding to help request: $e');
      throw Exception('Error responding to help request: $e');
    }
  }

  // Get pending help requests - Using Firebase as fallback since API is not available
  static Future<List<HelpRequest>> getPendingHelpRequests() async {
    try {
      debugPrint('🔄 API: Attempting to get pending help requests');

      // Try API first if connectivity is available
      if (await _checkConnectivity()) {
        try {
          final token = await _getToken();
          if (token.isNotEmpty) {
            debugPrint('📡 API: Trying server pending requests first...');

            final response = await http.get(
              Uri.parse('$baseUrl/help-request/pending'),
              headers: {
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              debugPrint(
                  '✅ API: Pending help requests fetched successfully via server');
              final List<dynamic> data = jsonDecode(response.body);
              return data.map((json) => HelpRequest.fromJson(json)).toList();
            } else {
              debugPrint(
                  '⚠️ API: Server pending requests failed: ${response.statusCode}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ API: Server pending requests failed: $e');
        }
      }

      // Help requests are now only available for Google authenticated users
      // No fallback to Firebase for traditional users
      throw Exception(
          'Help request system is only available for Google authenticated users');
    } catch (e) {
      debugPrint('❌ API: Error fetching pending help requests: $e');
      throw Exception('Error fetching pending help requests: $e');
    }
  }

  // Get help request by ID
  static Future<HelpRequest> getHelpRequestById(String requestId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/help-request/$requestId'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HelpRequest.fromJson(data);
      } else {
        throw Exception('Failed to fetch help request');
      }
    } catch (e) {
      throw Exception('Error fetching help request: $e');
    }
  }

  // Rate a user - Using Firebase as fallback since API is not available
  static Future<Map<String, dynamic>> rateUser({
    required String userId,
    required double rating,
    String? comment,
  }) async {
    try {
      debugPrint('🔄 API: Attempting to rate user: $userId');

      // Try API first if connectivity is available
      if (await _checkConnectivity()) {
        try {
          final token = await _getToken();
          if (token.isNotEmpty) {
            debugPrint('📡 API: Trying server rating first...');

            final response = await http
                .post(
                  Uri.parse('$baseUrl/user/rate'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'userId': userId,
                    'rating': rating,
                    'comment': comment,
                  }),
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              debugPrint('✅ API: User rated successfully via server');
              return jsonDecode(response.body);
            } else {
              debugPrint(
                  '⚠️ API: Server rating failed: ${response.statusCode}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ API: Server rating failed: $e');
        }
      }

      // Fallback to Firebase since API is not available
      debugPrint('🔥 API: Using Firebase fallback for user rating');
      return await _rateUserViaFirebase(
        userId: userId,
        rating: rating,
        comment: comment,
      );
    } catch (e) {
      debugPrint('❌ API: Error rating user: $e');
      throw Exception('Error rating user: $e');
    }
  }

  // Firebase fallback for user rating
  static Future<Map<String, dynamic>> _rateUserViaFirebase({
    required String userId,
    required double rating,
    String? comment,
  }) async {
    try {
      final ratingService = FirebaseRatingService();
      final result = await ratingService.rateUser(
        userId: userId,
        rating: rating,
        comment: comment,
      );

      debugPrint('✅ API: User rated successfully via Firebase');
      return result;
    } catch (e) {
      debugPrint('❌ API: Firebase user rating failed: $e');
      throw Exception('Failed to rate user via Firebase: $e');
    }
  }

  // Get user ratings - Using Firebase as fallback since API is not available
  static Future<List<UserRating>> getUserRatings(String userId) async {
    try {
      debugPrint('🔄 API: Attempting to get user ratings for: $userId');

      // Try API first if connectivity is available
      if (await _checkConnectivity()) {
        try {
          final token = await _getToken();
          if (token.isNotEmpty) {
            debugPrint('📡 API: Trying server user ratings first...');

            final response = await http.get(
              Uri.parse('$baseUrl/user/$userId/ratings'),
              headers: {
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              debugPrint('✅ API: User ratings fetched successfully via server');
              final List<dynamic> data = jsonDecode(response.body);
              return data.map((json) => UserRating.fromJson(json)).toList();
            } else {
              debugPrint(
                  '⚠️ API: Server user ratings failed: ${response.statusCode}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ API: Server user ratings failed: $e');
        }
      }

      // Fallback to Firebase since API is not available
      debugPrint('🔥 API: Using Firebase fallback for user ratings');
      return await _getUserRatingsViaFirebase(userId);
    } catch (e) {
      debugPrint('❌ API: Error fetching user ratings: $e');
      throw Exception('Error fetching user ratings: $e');
    }
  }

  // Firebase fallback for user ratings
  static Future<List<UserRating>> _getUserRatingsViaFirebase(
      String userId) async {
    try {
      final ratingService = FirebaseRatingService();
      final ratings = await ratingService.getUserRatings(userId);

      debugPrint(
          '✅ API: User ratings fetched successfully via Firebase: ${ratings.length}');
      return ratings;
    } catch (e) {
      debugPrint('❌ API: Firebase user ratings failed: $e');
      throw Exception('Failed to fetch user ratings via Firebase: $e');
    }
  }

  // Get user average rating - Using Firebase as fallback since API is not available
  static Future<double> getUserAverageRating(String userId) async {
    try {
      debugPrint('🔄 API: Attempting to get user average rating for: $userId');

      // Try API first if connectivity is available
      if (await _checkConnectivity()) {
        try {
          final token = await _getToken();
          if (token.isNotEmpty) {
            debugPrint('📡 API: Trying server average rating first...');

            final response = await http.get(
              Uri.parse('$baseUrl/user/$userId/average-rating'),
              headers: {
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              debugPrint(
                  '✅ API: User average rating fetched successfully via server');
              final data = jsonDecode(response.body);
              return data['averageRating'].toDouble();
            } else {
              debugPrint(
                  '⚠️ API: Server average rating failed: ${response.statusCode}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ API: Server average rating failed: $e');
        }
      }

      // Fallback to Firebase since API is not available
      debugPrint('🔥 API: Using Firebase fallback for user average rating');
      return await _getUserAverageRatingViaFirebase(userId);
    } catch (e) {
      debugPrint('❌ API: Error fetching user average rating: $e');
      throw Exception('Error fetching user average rating: $e');
    }
  }

  // Firebase fallback for user average rating
  static Future<double> _getUserAverageRatingViaFirebase(String userId) async {
    try {
      final ratingService = FirebaseRatingService();
      final averageRating = await ratingService.getUserAverageRating(userId);

      debugPrint(
          '✅ API: User average rating fetched successfully via Firebase: $averageRating');
      return averageRating;
    } catch (e) {
      debugPrint('❌ API: Firebase user average rating failed: $e');
      return 0.0; // Return 0.0 as fallback instead of throwing exception
    }
  }

  static Future<Map<String, dynamic>> registerGoogleUser(
      Map<String, dynamic> userData) async {
    if (!await _checkConnectivity()) {
      return {
        'success': false,
        'error':
            'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى',
      };
    }

    try {
      debugPrint('Registering Google user with data: $userData');

      // 1. إنشاء طلب متعدد الأجزاء (لرفع الملف)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/SignUpGoogle'),
      );

      // 2. إضافة الحقول النصية (بنفس الأسماء كما في Postman)
      request.fields['firstName'] = userData['firstName'] ?? '';
      request.fields['lastName'] = userData['lastName'] ?? '';
      request.fields['email'] = userData['email'] ?? '';
      request.fields['phone'] = userData['phone'] ?? '';
      request.fields['car_number'] =
          userData['Car Number'] ?? ''; // مطلوب في Postman
      request.fields['car_color'] =
          userData['car_color'] ?? ''; // مطلوب في Postman
      request.fields['car_model'] =
          userData['car_model'] ?? ''; // مطلوب في Postman

      // 3. رفع الصورة كملف (إذا كانت متوفرة)
      if (userData['photoURL'] != null && userData['photoURL'].isNotEmpty) {
        try {
          // تنزيل الصورة من رابط Google
          var imageResponse = await http.get(Uri.parse(userData['photoURL']));
          if (imageResponse.statusCode == 200) {
            // حفظ الصورة مؤقتًا
            final tempDir = await path_provider.getTemporaryDirectory();
            final filePath =
                '${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File(filePath);
            await file.writeAsBytes(imageResponse.bodyBytes);

            // إضافة الملف إلى الطلب (باسم profile_picture كما في Postman)
            request.files.add(
              await http.MultipartFile.fromPath(
                'profile_picture', // اسم الحقل في الخادم
                file.path,
              ),
            );
            debugPrint('تم إرفاق صورة البروفايل كملف');
          }
        } catch (e) {
          debugPrint('فشل تحميل الصورة: $e');
        }
      }

      // 4. إرسال الطلب
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      debugPrint('Google registration response status: ${response.statusCode}');
      debugPrint('Google registration response body: $responseData');

      if (response.statusCode == 200) {
        // حفظ بيانات المستخدم في الجلسة (إذا كان الخادم يُرجع token أو user data)
        if (jsonResponse['data'] != null &&
            jsonResponse['data']['user'] != null) {
          final user = jsonResponse['data']['user'];
          final authService = AuthService();
          await authService.saveAuthData(
            token: jsonResponse['token'] ?? '',
            userId: user['id'].toString(),
            email: user['email'] ?? '',
            name: '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
          );
        }

        // رفع الرخصة بعد نجاح التسجيل مباشرة
        if (userData['frontLicense'] != null &&
            userData['backLicense'] != null) {
          debugPrint('تم التسجيل بنجاح، الآن رفع الرخصة...');

          try {
            final licenseResponse = await uploadLicense(
              email: userData['email'] ?? '',
              frontImage: userData['frontLicense'] as File,
              backImage: userData['backLicense'] as File,
            );

            if (licenseResponse['success'] == true) {
              debugPrint('تم رفع الرخصة بنجاح بعد التسجيل');
              return {
                'success': true,
                'data': jsonResponse['data'],
                'message':
                    jsonResponse['message'] ?? 'تم التسجيل ورفع الرخصة بنجاح',
                'license_uploaded': true,
              };
            } else {
              debugPrint('فشل رفع الرخصة: ${licenseResponse['error']}');
              // إذا فشل رفع الرخصة، نعتبر العملية فاشلة
              return {
                'success': false,
                'error':
                    'تم التسجيل لكن فشل رفع الرخصة: ${licenseResponse['error']}',
              };
            }
          } catch (e) {
            debugPrint('خطأ في رفع الرخصة: $e');
            return {
              'success': false,
              'error': 'تم التسجيل لكن فشل رفع الرخصة: $e',
            };
          }
        } else {
          // لا توجد رخصة للرفع
          return {
            'success': true,
            'data': jsonResponse['data'],
            'message': jsonResponse['message'] ?? 'تم التسجيل بنجاح',
          };
        }
      } else {
        return {
          'success': false,
          'error':
              jsonResponse['message'] ?? 'فشل التسجيل (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Error during Google registration: $e');
      return {
        'success': false,
        'error': 'حدث خطأ غير متوقع: ${e.toString()}',
      };
    }
  }

  // استرجاع بيانات المستخدم الذي قام بالتسجيل أو تسجيل الدخول باستخدام Google
  static Future<Map<String, dynamic>> getGoogleUserData(String email) async {
    if (!await _checkConnectivity()) {
      return {
        'success': false,
        'error':
            'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى',
      };
    }

    try {
      debugPrint('Fetching Google user data for email: $email');

      // تغيير من POST إلى GET مع إرسال البيانات في الـ body كما هو موضح في Postman
      final request = http.Request('GET', Uri.parse('$baseUrl/api/datagoogle'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';
      request.body = jsonEncode({
        'email': email,
      });

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Google user data response status: ${response.statusCode}');
      debugPrint('Google user data response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // التحقق من نجاح الاستجابة
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return {
            'success': true,
            'data': responseData['data'],
          };
        } else {
          return {
            'success': false,
            'error':
                responseData['message'] ?? 'لم يتم العثور على بيانات المستخدم',
          };
        }
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ??
              'فشل استرجاع بيانات المستخدم (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Error fetching Google user data: $e');
      if (e is http.ClientException) {
        return {
          'success': false,
          'error':
              'فشل الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى',
        };
      }
      return {
        'success': false,
        'error':
            'حدث خطأ غير متوقع أثناء استرجاع بيانات المستخدم: ${e.toString()}',
      };
    }
  }

  // تحديث بيانات المستخدم الذي قام بالتسجيل أو تسجيل الدخول باستخدام Google
  static Future<Map<String, dynamic>> updateGoogleUser(
      Map<String, dynamic> userData) async {
    if (!await _checkConnectivity()) {
      return {
        'success': false,
        'error':
            'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى',
      };
    }

    try {
      debugPrint('Updating Google user with data: $userData');

      // إنشاء طلب متعدد الأجزاء (form-data) كما هو موضح في Postman
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/updateusergoogle'),
      );

      // إضافة الحقول النصية (بنفس الأسماء كما في Postman)
      if (userData['email'] != null) {
        request.fields['email'] = userData['email'].toString();
      }
      if (userData['firstName'] != null) {
        request.fields['firstName'] = userData['firstName'].toString();
      }
      if (userData['lastName'] != null) {
        request.fields['lastName'] = userData['lastName'].toString();
      }
      if (userData['phone'] != null) {
        request.fields['phone'] = userData['phone'].toString();
      }
      if (userData['car_number'] != null) {
        request.fields['car_number'] = userData['car_number'].toString();
      }
      if (userData['car_color'] != null) {
        request.fields['car_color'] = userData['car_color'].toString();
      }
      if (userData['car_model'] != null) {
        request.fields['car_model'] = userData['car_model'].toString();
      }

      // رفع الصورة كملف (إذا كانت متوفرة)
      if (userData['profile_picture'] != null &&
          userData['profile_picture'] is File) {
        try {
          final file = userData['profile_picture'] as File;
          if (await file.exists()) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'profile_picture', // اسم الحقل في الخادم
                file.path,
              ),
            );
            debugPrint('تم إرفاق صورة البروفايل كملف');
          }
        } catch (e) {
          debugPrint('فشل إرفاق الصورة: $e');
        }
      }

      debugPrint('=== UPDATE GOOGLE USER REQUEST ===');
      debugPrint('URL: ${request.url}');
      debugPrint('Method: ${request.method}');
      debugPrint('Fields: ${request.fields}');
      debugPrint('Files: ${request.files.map((f) => f.field).toList()}');
      debugPrint('===================================');

      // إرسال الطلب
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      debugPrint('=== UPDATE GOOGLE USER RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: $responseData');
      debugPrint('===================================');

      if (response.statusCode == 200) {
        try {
          var jsonResponse = json.decode(responseData);

          return {
            'success': true,
            'data': jsonResponse,
            'message': jsonResponse['message'] ?? 'تم تحديث البيانات بنجاح',
          };
        } catch (e) {
          // إذا لم يكن الرد JSON، نعتبر العملية ناجحة إذا كان status code 200
          return {
            'success': true,
            'message': 'تم تحديث البيانات بنجاح',
          };
        }
      } else {
        try {
          var jsonResponse = json.decode(responseData);
          return {
            'success': false,
            'error': jsonResponse['message'] ??
                'فشل تحديث البيانات (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'فشل تحديث البيانات (${response.statusCode})',
          };
        }
      }
    } catch (e) {
      debugPrint('Error during Google user update: $e');
      return {
        'success': false,
        'error': 'حدث خطأ غير متوقع: ${e.toString()}',
      };
    }
  }

  // رفع رخصة القيادة للسيرفر - إرسال كل البيانات (email + صورتين) في طلب واحد
  static Future<Map<String, dynamic>> uploadLicense({
    required String email,
    required File frontImage,
    required File backImage,
  }) async {
    if (!await _checkConnectivity()) {
      return {
        'success': false,
        'error':
            'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى',
      };
    }

    try {
      debugPrint('Uploading license for email: $email');

      // إنشاء طلب متعدد الأجزاء (form-data) - إرسال كل البيانات مرة واحدة
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload-license'),
      );

      // إضافة headers
      request.headers['Accept'] = 'application/json';

      // تحديد نوع MIME للصور
      String frontExt = path.extension(frontImage.path).toLowerCase();
      String frontMimeType = frontExt == '.png' ? 'png' : 'jpeg';

      String backExt = path.extension(backImage.path).toLowerCase();
      String backMimeType = backExt == '.png' ? 'png' : 'jpeg';

      // الترتيب الصحيح: frontImage أولاً
      request.files.add(
        await http.MultipartFile.fromPath(
          'frontImage', // الاسم الصحيح
          frontImage.path,
          filename: 'front_license.$frontMimeType',
          contentType: MediaType('image', frontMimeType),
        ),
      );

      // ثم backImage
      request.files.add(
        await http.MultipartFile.fromPath(
          'backImage', // الاسم الصحيح
          backImage.path,
          filename: 'back_license.$backMimeType',
          contentType: MediaType('image', backMimeType),
        ),
      );

      // وأخيراً email
      request.fields['email'] = email;

      debugPrint('=== UPLOAD LICENSE REQUEST (CORRECT ORDER & NAMES) ===');
      debugPrint('URL: ${request.url}');
      debugPrint('Method: ${request.method}');
      debugPrint('1. frontImage -> ${frontImage.path}');
      debugPrint('2. backImage -> ${backImage.path}');
      debugPrint('3. email -> $email');
      debugPrint('Headers: ${request.headers}');
      debugPrint('=== SENDING ALL DATA TOGETHER IN CORRECT ORDER ===');

      // إرسال الطلب - كل البيانات معاً في طلب واحد
      debugPrint('Sending single request with all data...');
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      debugPrint('=== UPLOAD LICENSE RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: $responseData');
      debugPrint('===============================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          var jsonResponse = json.decode(responseData);

          return {
            'success': true,
            'data': jsonResponse,
            'message': jsonResponse['message'] ?? 'تم رفع الرخصة بنجاح',
            'front_image_url': jsonResponse['front_image_url'],
            'back_image_url': jsonResponse['back_image_url'],
          };
        } catch (e) {
          // إذا لم يكن الرد JSON، نعتبر العملية ناجحة إذا كان status code 200/201
          return {
            'success': true,
            'message': 'تم رفع الرخصة بنجاح',
          };
        }
      } else {
        try {
          var jsonResponse = json.decode(responseData);
          return {
            'success': false,
            'error': jsonResponse['message'] ??
                'فشل رفع الرخصة (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'فشل رفع الرخصة (${response.statusCode})',
          };
        }
      }
    } catch (e) {
      debugPrint('Error during license upload: $e');
      if (e is http.ClientException) {
        return {
          'success': false,
          'error':
              'فشل الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى',
        };
      }
      return {
        'success': false,
        'error': 'حدث خطأ غير متوقع أثناء رفع الرخصة: ${e.toString()}',
      };
    }
  }
}
