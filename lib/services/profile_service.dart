import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_data.dart' as models;
import 'package:http_parser/http_parser.dart'; // لازم يكون موجود
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationResult {
  final Position? position;
  final String? error;

  LocationResult({this.position, this.error});
}

class ProfileService {
  final String baseUrl = 'http://81.10.91.96:8132/api';
  final Map<String, String> headers = {
    'Content-Type': 'application/json',
  };
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<models.ProfileData> getProfileData(String email,
      {bool useCache = false}) async {
    try {
      // التحقق من وجود بيانات مخزنة مؤقتًا
      if (useCache) {
        final hasFreshCache = await models.ProfileData.hasFreshCachedData();
        if (hasFreshCache) {
          final cachedData = await models.ProfileData.loadFromCache();
          if (cachedData != null && cachedData.email == email) {
            debugPrint('Using cached profile data for $email');
            return cachedData;
          }
        }
      }

      // التحقق من نوع المستخدم (Google أم عادي)
      final prefs = await SharedPreferences.getInstance();
      final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

      String apiEndpoint;
      String method;

      if (isGoogleSignIn) {
        // مستخدمو Google يستخدموا فقط API واحد محدد
        apiEndpoint = '$baseUrl/datagoogle';
        method = 'GET'; // حسب المواصفات المطلوبة
        debugPrint(
            '🔍 ProfileService: Google user detected - using ONLY datagoogle API');
      } else {
        // استخدام API العادي للمستخدمين العاديين
        apiEndpoint = '$baseUrl/data';
        method = 'POST';
        debugPrint(
            '🔍 ProfileService: Traditional user detected - using data API');
      }

      debugPrint('=== GET PROFILE DATA REQUEST ===');
      debugPrint('URL: $apiEndpoint');
      debugPrint('Method: $method');
      debugPrint('Body: ${jsonEncode({"email": email})}');
      debugPrint('Is Google User: $isGoogleSignIn');
      debugPrint('================================');

      http.Response response;

      if (isGoogleSignIn) {
        // استخدام GET method مع body للمستخدمين Google
        final request = http.Request('GET', Uri.parse(apiEndpoint));
        request.headers['Content-Type'] = 'application/json';
        request.headers['Accept'] = 'application/json';
        request.body = jsonEncode({"email": email});

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 15));
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // استخدام POST method للمستخدمين العاديين
        response = await http
            .post(
              Uri.parse(apiEndpoint),
              headers: headers,
              body: jsonEncode({"email": email}),
            )
            .timeout(const Duration(seconds: 15));
      }

      debugPrint('=== GET PROFILE DATA RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('=================================');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          models.ProfileData profileData;

          if (isGoogleSignIn) {
            // معالجة بيانات مستخدم Google من /api/datagoogle
            // البيانات تأتي في شكل: {"data": {"user": {...}}}
            final userData =
                responseData['data']['user'] ?? responseData['data'];

            profileData = models.ProfileData(
              name:
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                      .trim(),
              email: userData['email'] ?? email,
              phone: userData['phone'],
              profileImage: userData['profile_picture'],
              carModel: userData['car_model'],
              carColor: userData['car_color'],
              plateNumber: userData['car_number'],
            );
          } else {
            // معالجة بيانات المستخدم العادي من /api/data
            // البيانات تأتي في شكل: {"data": {"user": {...}, "car": {...}}}
            final userData = responseData['data'];
            final user = userData['user'] ?? userData;
            final car = userData['car'] ?? {};

            profileData = models.ProfileData(
              name:
                  '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
              email: user['email'] ?? email,
              phone: user['phone'],
              profileImage: user['profile_picture'],
              carModel: car['carModel'] ?? car['car_model'],
              carColor: car['carColor'] ?? car['car_color'],
              plateNumber: car['plateNumber']?.toString() ??
                  car['plate_number']?.toString(),
            );
          }

          // تخزين البيانات مؤقتًا للاستخدام المستقبلي
          await profileData.saveToCache();

          // حفظ البيانات في SharedPreferences للاستخدام في طلبات المساعدة
          await _saveProfileDataToSharedPreferences(profileData);

          return profileData;
        } else {
          throw Exception(
              responseData['message'] ?? 'لم يتم العثور على بيانات المستخدم');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ??
            'فشل جلب بيانات الملف الشخصي (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error in getProfileData: $e');

      // في حالة فشل API، جرب التحميل من Cache
      if (!useCache) {
        debugPrint('API failed, trying to load from cache...');
        try {
          final cachedData = await models.ProfileData.loadFromCache();
          if (cachedData != null && cachedData.email == email) {
            debugPrint('Using cached data as fallback');
            return cachedData;
          }
        } catch (cacheError) {
          debugPrint('Cache fallback also failed: $cacheError');
        }
      }

      throw Exception('فشل جلب بيانات الملف الشخصي: $e');
    }
  }

  Future<void> saveProfileData(String email, models.ProfileData data) async {
    try {
      // حفظ البيانات محلياً أولاً (هذا هو الأهم)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', data.name);
      await prefs.setString('user_phone', data.phone ?? '');
      await prefs.setString('user_car_model', data.carModel ?? '');
      await prefs.setString('user_car_color', data.carColor ?? '');
      await prefs.setString('user_plate_number', data.plateNumber ?? '');

      // محاولة حفظ البيانات في Firebase Database (اختياري)
      try {
        final snapshot = await _database
            .child('users')
            .orderByChild('email')
            .equalTo(email)
            .get();
        if (snapshot.exists) {
          final userId = snapshot.children.first.key;
          await _database.child('users/$userId').update({
            'name': data.name,
            'phone': data.phone,
            'carModel': data.carModel,
            'carColor': data.carColor,
            'plateNumber': data.plateNumber,
          });
          debugPrint('✅ Profile data saved to Firebase Database');
        }
      } catch (firebaseError) {
        debugPrint(
            '⚠️ Firebase Database save failed (non-critical): $firebaseError');
        // لا نرمي خطأ هنا لأن حفظ البيانات محلياً نجح
      }
    } catch (e) {
      throw Exception('فشل حفظ بيانات الملف الشخصي: $e');
    }
  }

  Future<void> updateProfileData(String email, models.ProfileData profileData,
      {File? profileImageFile}) async {
    try {
      // التحقق من نوع المستخدم (Google أم عادي)
      final prefs = await SharedPreferences.getInstance();
      final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

      debugPrint(
          '🔄 ProfileService: Updating profile for ${isGoogleSignIn ? "Google" : "Traditional"} user: $email');

      if (isGoogleSignIn) {
        // استخدام endpoint خاص بمستخدمين Google
        await updateGoogleUserProfile(email, profileData,
            profileImageFile: profileImageFile);
      } else {
        // استخدام endpoint العادي للمستخدمين العاديين
        await updateRegularUserProfile(email, profileData);
      }

      // Save updated profile data to SharedPreferences for help request functionality
      await _saveProfileDataToSharedPreferences(profileData);
    } catch (e) {
      debugPrint('Error in updateProfileData: $e');
      throw Exception('Error updating profile data: $e');
    }
  }

  // حفظ بيانات الملف الشخصي في SharedPreferences للاستخدام في طلبات المساعدة
  Future<void> _saveProfileDataToSharedPreferences(
      models.ProfileData profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('user_name', profileData.name);
      if (profileData.phone != null) {
        await prefs.setString('user_phone', profileData.phone!);
      }
      if (profileData.carModel != null) {
        await prefs.setString('user_car_model', profileData.carModel!);
      }
      if (profileData.carColor != null) {
        await prefs.setString('user_car_color', profileData.carColor!);
      }
      if (profileData.plateNumber != null) {
        await prefs.setString('user_plate_number', profileData.plateNumber!);
      }
      if (profileData.profileImage != null) {
        await prefs.setString('user_profile_image', profileData.profileImage!);
      }

      debugPrint('✅ Profile data saved to SharedPreferences for help requests');
    } catch (e) {
      debugPrint('❌ Error saving profile data to SharedPreferences: $e');
    }
  }

  // تحديث بيانات المستخدم العادي
  Future<void> updateRegularUserProfile(
      String email, models.ProfileData profileData) async {
    try {
      // فصل رقم اللوحة إلى حروف وأرقام
      String letters = '';
      String plateNumber = '';

      if (profileData.plateNumber != null &&
          profileData.plateNumber!.isNotEmpty) {
        final plateData = profileData.plateNumber!;
        // إذا كان يحتوي على شرطة، فصل الحروف عن الأرقام
        if (plateData.contains('-')) {
          final parts = plateData.split('-');
          letters = parts[0];
          plateNumber = parts.length > 1 ? parts[1] : '';
        } else {
          // إذا لم يحتوي على شرطة، حاول فصل الحروف عن الأرقام
          final regex = RegExp(r'^([^\d]*)(\d*)$');
          final match = regex.firstMatch(plateData);
          if (match != null) {
            letters = match.group(1) ?? '';
            plateNumber = match.group(2) ?? '';
          } else {
            // إذا فشل الفصل، ضع كل شيء في plate_number
            plateNumber = plateData;
          }
        }
      }

      final Map<String, dynamic> requestData = {
        'email': email,
        'firstName': profileData.name.split(' ')[0],
        'lastName': profileData.name.split(' ').length > 1
            ? profileData.name.split(' ').sublist(1).join(' ')
            : '',
        'phone': profileData.phone,
        'car_model': profileData.carModel,
        'car_color': profileData.carColor,
        'letters': letters,
        'plate_number': plateNumber,
      };

      final requestBody = json.encode(requestData);

      debugPrint('=== UPDATE REGULAR USER PROFILE REQUEST ===');
      debugPrint('URL: $baseUrl/updateuser');
      debugPrint('Method: PUT');
      debugPrint('Headers: ${{'Content-Type': 'application/json'}}');
      debugPrint('Body: $requestBody');
      debugPrint('==========================================');

      final response = await http.put(
        Uri.parse('$baseUrl/updateuser'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      debugPrint('=== UPDATE REGULAR USER PROFILE RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('============================================');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update regular user profile data: ${response.statusCode}');
      }

      // تحديث الكاش فوراً بعد نجاح التحديث
      debugPrint('✅ Profile update successful, updating cache...');
      await profileData.saveToCache();
      debugPrint('✅ Cache updated with new profile data');
    } catch (e) {
      debugPrint('Error in updateRegularUserProfile: $e');
      throw Exception('Error updating regular user profile data: $e');
    }
  }

  // تحديث بيانات مستخدم Google
  Future<void> updateGoogleUserProfile(
      String email, models.ProfileData profileData,
      {File? profileImageFile}) async {
    try {
      // تحضير البيانات للإرسال
      final Map<String, dynamic> requestData = {
        'email': email,
        'firstName': profileData.name.split(' ')[0],
        'lastName': profileData.name.split(' ').length > 1
            ? profileData.name.split(' ').sublist(1).join(' ')
            : '',
        'phone': profileData.phone,
        'car_model': profileData.carModel,
        'car_color': profileData.carColor,
        'car_number': profileData.plateNumber,
      };

      // إضافة الصورة إذا كانت متوفرة
      if (profileImageFile != null) {
        requestData['profile_picture'] = profileImageFile;
      }

      debugPrint('=== UPDATE GOOGLE USER PROFILE REQUEST ===');
      debugPrint('Email: $email');
      debugPrint('Data: ${requestData.keys.toList()}');
      debugPrint('Has profile image: ${profileImageFile != null}');
      debugPrint('==========================================');

      // استدعاء الدالة الجديدة من ApiService
      final result = await ApiService.updateGoogleUser(requestData);

      debugPrint('=== UPDATE GOOGLE USER PROFILE RESPONSE ===');
      debugPrint('Success: ${result['success']}');
      debugPrint('Message: ${result['message'] ?? result['error']}');
      debugPrint('===========================================');

      if (result['success'] != true) {
        throw Exception(
            result['error'] ?? 'Failed to update Google user profile');
      }

      // تحديث الكاش فوراً بعد نجاح التحديث
      debugPrint('✅ Google profile update successful, updating cache...');
      await profileData.saveToCache();
      debugPrint('✅ Cache updated with new Google profile data');
    } catch (e) {
      debugPrint('Error in updateGoogleUserProfile: $e');
      throw Exception('Error updating Google user profile: $e');
    }
  }

  Future<String> uploadProfileImage(String email, File imageFile) async {
    try {
      // Validate email
      if (email.isEmpty) {
        debugPrint('Error: Empty email provided to uploadProfileImage');
        return '';
      }

      email = email.trim(); // Trim any whitespace

      // التحقق من نوع المستخدم (Google أم عادي)
      final prefs = await SharedPreferences.getInstance();
      final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

      debugPrint('=== UPLOAD IMAGE DEBUG INFO ===');
      debugPrint('Email: $email');
      debugPrint('is_google_sign_in from SharedPreferences: $isGoogleSignIn');
      debugPrint('All SharedPreferences keys: ${prefs.getKeys()}');
      debugPrint('==============================');

      if (isGoogleSignIn) {
        // للمستخدمين Google، استخدم updateGoogleUser مع الصورة
        debugPrint('=== UPLOAD IMAGE FOR GOOGLE USER ===');
        debugPrint('Email: $email');
        debugPrint('Using updateGoogleUser endpoint');

        return await _uploadImageForGoogleUser(email, imageFile);
      } else {
        // للمستخدمين العاديين، استخدم الطريقة العادية
        debugPrint('=== UPLOAD IMAGE REQUEST (REGULAR USER) ===');
        debugPrint('URL: $baseUrl/upload');
        debugPrint('Method: POST');
        debugPrint('Email: $email');

        return await _uploadImageForRegularUser(email, imageFile);
      }
    } catch (e) {
      debugPrint('Error in uploadProfileImage: $e');
      return '';
    }
  }

  // رفع صورة للمستخدمين Google
  Future<String> _uploadImageForGoogleUser(String email, File imageFile) async {
    try {
      // أولاً، جلب البيانات الحالية للمستخدم
      debugPrint('Fetching current Google user data before image upload...');
      final currentUserData = await ApiService.getGoogleUserData(email);

      if (currentUserData['success'] != true ||
          currentUserData['data'] == null) {
        debugPrint(
            'Failed to fetch current user data: ${currentUserData['error']}');
        return '';
      }

      final userData = currentUserData['data']['user'];

      // تحضير البيانات الكاملة مع الصورة الجديدة
      final Map<String, dynamic> requestData = {
        'email': email,
        'firstName': userData['firstName'] ?? '',
        'lastName': userData['lastName'] ?? '',
        'phone': userData['phone'] ?? '',
        'car_number': userData['car_number'] ?? '',
        'car_color': userData['car_color'] ?? '',
        'car_model': userData['car_model'] ?? '',
        'profile_picture': imageFile, // الصورة الجديدة
      };

      debugPrint('Updating Google user with complete data + new image...');
      final result = await ApiService.updateGoogleUser(requestData);

      if (result['success'] == true) {
        // جلب البيانات المحدثة للحصول على رابط الصورة الجديد
        final userData = await ApiService.getGoogleUserData(email);
        if (userData['success'] == true && userData['data'] != null) {
          final userInfo = userData['data']['user'];
          final profilePicture = userInfo['profile_picture'];

          if (profilePicture != null && profilePicture.isNotEmpty) {
            String imageUrl = profilePicture.toString();

            // التأكد من أن الرابط صحيح
            if (!imageUrl.startsWith('http')) {
              if (imageUrl.startsWith('/')) {
                imageUrl = 'http://81.10.91.96:8132$imageUrl';
              } else {
                imageUrl = 'http://81.10.91.96:8132/$imageUrl';
              }
            }

            // إضافة معلمة لمنع التخزين المؤقت
            final cleanUrl = _cleanCacheBustingParams(imageUrl);
            final finalUrl = _addCacheBustingParam(cleanUrl);

            debugPrint(
                '🖼️ Google ProfileService Upload - Original URL: $imageUrl');
            debugPrint(
                '🧹 Google ProfileService Upload - Clean URL: $cleanUrl');
            debugPrint(
                '🔗 Google ProfileService Upload - Final URL: $finalUrl');

            imageUrl = finalUrl;

            debugPrint('Google user image uploaded successfully: $imageUrl');

            // التحقق من وجود الصورة على السيرفر
            if (await _validateImageUrl(imageUrl)) {
              debugPrint('✅ Google user image uploaded successfully');
              return imageUrl;
            } else {
              debugPrint('❌ Google image validation failed');
              return '';
            }
          }
        }
      }

      debugPrint('Failed to upload image for Google user: ${result['error']}');
      return '';
    } catch (e) {
      debugPrint('Error uploading image for Google user: $e');
      return '';
    }
  }

  // رفع صورة للمستخدمين العاديين
  Future<String> _uploadImageForRegularUser(
      String email, File imageFile) async {
    try {
      // Check if file exists and is readable
      if (!await imageFile.exists()) {
        debugPrint('Error: Image file does not exist: ${imageFile.path}');
        return '';
      }

      // Check file size
      final fileSize = await imageFile.length();
      debugPrint('File size: $fileSize bytes');

      // If file is too large (> 5MB), warn about it
      if (fileSize > 5 * 1024 * 1024) {
        debugPrint(
            'Warning: File is large (${fileSize / (1024 * 1024)} MB), upload may take longer');
      }

      // Create a multipart request with timeout
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

      // Add email field
      request.fields['email'] = email;

      // Determine the correct MIME type based on file extension
      String ext = path.extension(imageFile.path).toLowerCase();
      String mimeType = ext == '.png' ? 'png' : 'jpeg';

      // Add the image file to the request
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ),
      );

      // Print request details for debugging
      debugPrint('Request fields: ${request.fields}');
      debugPrint(
          'Request files: ${request.files.map((f) => f.filename).toList()}');

      try {
        // Send the request with timeout
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('Request timed out for uploadProfileImage');
            throw Exception('Request timed out');
          },
        );

        final response = await http.Response.fromStream(streamedResponse);

        debugPrint('Upload response status code: ${response.statusCode}');
        debugPrint('Upload response: ${response.body}');

        if (response.statusCode != 200) {
          debugPrint('Error: Non-200 status code: ${response.statusCode}');
          return '';
        }

        try {
          // Parse the response
          final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          debugPrint('Parsed JSON response: $jsonResponse');

          // Check if the response indicates success
          if (jsonResponse['status'] == 'success') {
            debugPrint('Upload successful according to status');

            // Case 1: Server returns image_url directly
            if (jsonResponse['image_url'] != null) {
              String imageUrl = jsonResponse['image_url'];
              debugPrint('Image uploaded. URL: $imageUrl');

              // Validate and fix URL format if needed
              if (!imageUrl.startsWith('http')) {
                debugPrint(
                    'Warning: Image URL does not start with http: $imageUrl');

                // Try to fix the URL if it's a relative path
                if (imageUrl.startsWith('/')) {
                  imageUrl = 'http://81.10.91.96:8132$imageUrl';
                } else {
                  // If it's not a relative path, prepend the base URL without the /api part
                  imageUrl = 'http://81.10.91.96:8132/$imageUrl';
                }

                debugPrint('Fixed image URL: $imageUrl');
              }

              // Add cache-busting parameter to avoid caching issues
              // إزالة أي معاملات t= موجودة مسبقاً
              final cleanUrl = _cleanCacheBustingParams(imageUrl);
              final finalUrl = _addCacheBustingParam(cleanUrl);

              debugPrint('🖼️ ProfileService Upload - Original URL: $imageUrl');
              debugPrint('🧹 ProfileService Upload - Clean URL: $cleanUrl');
              debugPrint('🔗 ProfileService Upload - Final URL: $finalUrl');

              imageUrl = finalUrl;

              // التحقق من وجود الصورة على السيرفر
              if (await _validateImageUrl(imageUrl)) {
                debugPrint('✅ Image uploaded successfully and validated');
                return imageUrl;
              } else {
                debugPrint('❌ Image validation failed');
                return '';
              }
            }
            // Case 2: Server returns success message but no URL
            // In this case, we'll try to get the image URL by making a request to the images endpoint
            else if (jsonResponse['message'] != null &&
                jsonResponse['message']
                    .toString()
                    .contains('uploaded successfully')) {
              debugPrint(
                  'Server returned success message but no URL. Fetching image URL from API.');

              // Make a request to get the image URL
              final imageUrl = await getProfileImage(email);

              if (imageUrl.isNotEmpty) {
                debugPrint('Retrieved image URL after upload: $imageUrl');

                debugPrint('✅ Image retrieved from API after upload');
                return imageUrl;
              } else {
                debugPrint(
                    'Could not retrieve image URL after successful upload');
                return '';
              }
            }
            // If we get here, the response was successful but we couldn't determine the URL
            else {
              debugPrint('Upload successful but could not determine image URL');
              debugPrint('Response body: ${response.body}');

              // Try to get the image URL by making a request to the images endpoint
              final imageUrl = await getProfileImage(email);

              if (imageUrl.isNotEmpty) {
                debugPrint('Retrieved image URL after upload: $imageUrl');

                debugPrint('✅ Image retrieved from API after upload');
                return imageUrl;
              } else {
                debugPrint(
                    'Could not retrieve image URL after successful upload');
                return '';
              }
            }
          } else {
            debugPrint('Upload failed. Response status indicates failure.');
            debugPrint('Response body: ${response.body}');
            return '';
          }
        } catch (parseError) {
          debugPrint('Error parsing JSON response: $parseError');
          debugPrint('Raw response: ${response.body}');
          return '';
        }
      } catch (httpError) {
        debugPrint('HTTP error during upload: $httpError');
        return '';
      }
    } catch (e) {
      debugPrint('Error in _uploadImageForRegularUser: $e');
      return '';
    }
  }

  Future<String> getProfileImage(String email) async {
    try {
      debugPrint('🔍 Fetching profile image from API for: $email');

      // Validate email
      if (email.isEmpty) {
        debugPrint('Error: Empty email provided to getProfileImage');
        return '';
      }

      email = email.trim(); // Trim any whitespace

      // التحقق من نوع المستخدم (Google أم عادي)
      final prefs = await SharedPreferences.getInstance();
      final isGoogleSignIn = prefs.getBool('is_google_sign_in') ?? false;

      if (isGoogleSignIn) {
        // مستخدمو Google يستخدموا فقط API واحد محدد: /api/datagoogle
        debugPrint(
            '🔍 ProfileService: Google user detected - getting image from ONLY datagoogle API');

        final response = await ApiService.getGoogleUserData(email);

        if (response['success'] == true && response['data'] != null) {
          final userData = response['data']['user'] ?? response['data'];
          final profilePicture = userData['profile_picture'];

          if (profilePicture != null && profilePicture.isNotEmpty) {
            String imageUrl = profilePicture.toString();

            // التأكد من أن الرابط صحيح
            if (!imageUrl.startsWith('http')) {
              if (imageUrl.startsWith('/')) {
                imageUrl = 'http://81.10.91.96:8132$imageUrl';
              } else {
                imageUrl = 'http://81.10.91.96:8132/$imageUrl';
              }
            }

            debugPrint(
                '✅ ProfileService: Found Google user image from datagoogle API: $imageUrl');
            return imageUrl;
          }
        }

        debugPrint(
            '❌ ProfileService: No image found for Google user in datagoogle API');
        return '';
      }

      // للمستخدمين العاديين فقط - استخدام /api/images
      debugPrint('=== GET PROFILE IMAGE REQUEST (TRADITIONAL USER) ===');
      debugPrint('URL: $baseUrl/images');
      debugPrint('Method: GET');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${jsonEncode({"email": email})}');
      debugPrint('========================');

      // Create a GET request with a body (which is unusual but seems to be what the API expects)
      final request = http.Request('GET', Uri.parse('$baseUrl/images'));
      request.headers.addAll(headers);
      request.body = jsonEncode({"email": email});

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Request timed out for getProfileImage');
          throw Exception('Request timed out');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('=== GET PROFILE IMAGE RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('==========================');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);

          if (jsonResponse['status'] == 'success' &&
              jsonResponse['images'] is List &&
              (jsonResponse['images'] as List).isNotEmpty) {
            final firstImage = jsonResponse['images'][0];
            String? imageUrl;

            // Based on the Postman screenshot, the image URL is in the 'imageUrl' field
            if (firstImage is Map<String, dynamic> &&
                firstImage.containsKey('imageUrl')) {
              imageUrl = firstImage['imageUrl'].toString();
              debugPrint('Found image URL in imageUrl field: $imageUrl');
            }
            // Also check for 'filepath' field as seen in the screenshot
            else if (firstImage is Map<String, dynamic> &&
                firstImage.containsKey('filepath')) {
              final filepath = firstImage['filepath'].toString();
              debugPrint('Found filepath: $filepath');
              imageUrl = 'http://81.10.91.96:8132/$filepath';
            }
            // Also check for 'filePath' field (camel case variation)
            else if (firstImage is Map<String, dynamic> &&
                firstImage.containsKey('filePath')) {
              final filepath = firstImage['filePath'].toString();
              debugPrint('Found filePath: $filepath');
              imageUrl = 'http://81.10.91.96:8132/$filepath';
            }

            if (imageUrl != null && imageUrl.isNotEmpty) {
              debugPrint('✅ Found profile image URL: $imageUrl');
              return imageUrl;
            }
          }
        } catch (e) {
          debugPrint('Error parsing JSON response: $e');
        }
      }

      // If we couldn't get a URL from the API, return empty string
      debugPrint('Could not get profile image URL');
      return '';
    } catch (e) {
      debugPrint('Error in getProfileImage: $e');
      return '';
    }
  }

  // التحقق من صحة رابط الصورة
  Future<bool> _validateImageUrl(String imageUrl) async {
    try {
      debugPrint('🔍 Validating image URL: $imageUrl');

      // إزالة cache busting parameters للتحقق
      String cleanUrl = _cleanCacheBustingParams(imageUrl);

      final response = await http.head(Uri.parse(cleanUrl)).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏰ Image validation timeout');
          throw Exception('Timeout');
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Image URL is valid');
        return true;
      } else {
        debugPrint('❌ Image URL validation failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error validating image URL: $e');
      return false;
    }
  }

  Future<void> checkLocationPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<LocationResult> getCurrentLocation() async {
    try {
      // تحقق من تفعيل خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(error: 'خدمة الموقع غير مفعلة. يرجى تفعيل GPS.');
      }

      // تحقق من الصلاحية
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
              error: 'تم رفض صلاحية الموقع. يرجى السماح للتطبيق.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
            error:
                'صلاحية الموقع مرفوضة بشكل دائم. يرجى تفعيلها من الإعدادات.');
      }

      // جلب الموقع
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      return LocationResult(position: position);
    } catch (e) {
      debugPrint('Location error: $e');
      return LocationResult(error: 'حدث خطأ أثناء جلب الموقع: $e');
    }
  }

  // Helper method to clean cache busting parameters from URL
  String _cleanCacheBustingParams(String url) {
    String cleanUrl = url;

    // Remove all existing cache busting parameters more thoroughly
    // Handle multiple t= parameters
    while (cleanUrl.contains('?t=') || cleanUrl.contains('&t=')) {
      if (cleanUrl.contains('?t=')) {
        final parts = cleanUrl.split('?t=');
        cleanUrl = parts[0];
        // If there are more parameters after t=, we need to handle them
        if (parts.length > 1 && parts[1].contains('&')) {
          final afterT = parts[1].split('&');
          if (afterT.length > 1) {
            // Reconstruct URL with remaining parameters
            cleanUrl += '?${afterT.skip(1).join('&')}';
          }
        }
      }
      if (cleanUrl.contains('&t=')) {
        final parts = cleanUrl.split('&t=');
        cleanUrl = parts[0];
        // If there are more parameters after t=, we need to handle them
        if (parts.length > 1 && parts[1].contains('&')) {
          final afterT = parts[1].split('&');
          if (afterT.length > 1) {
            // Reconstruct URL with remaining parameters
            cleanUrl += '&${afterT.skip(1).join('&')}';
          }
        }
      }
    }

    return cleanUrl;
  }

  // Helper method to add cache busting parameter to URL
  String _addCacheBustingParam(String url) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (!url.contains('?')) {
      return '$url?t=$timestamp';
    } else {
      return '$url&t=$timestamp';
    }
  }
}
