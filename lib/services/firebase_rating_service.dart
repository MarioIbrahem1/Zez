import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:road_helperr/models/user_rating.dart';

class FirebaseRatingService {
  static final FirebaseRatingService _instance =
      FirebaseRatingService._internal();
  factory FirebaseRatingService() => _instance;
  FirebaseRatingService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // تقييم مستخدم
  Future<Map<String, dynamic>> rateUser({
    required String userId,
    required double rating,
    String? comment,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      String? currentUserId = currentUser?.uid;

      debugPrint('🔄 Firebase Rating: Rating user $userId by $currentUserId');

      // إنشاء ID جديد للتقييم
      final ratingRef = _database.child('ratings').push();
      final ratingId = ratingRef.key!;

      // بيانات التقييم
      final ratingData = {
        'id': ratingId,
        'userId': userId,
        'ratedByUserId': currentUserId,
        'rating': rating,
        'comment': comment,
        'timestamp': ServerValue.timestamp,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // حفظ التقييم في Firebase
      await ratingRef.set(ratingData);

      // تحديث متوسط التقييم للمستخدم
      await _updateUserAverageRating(userId);

      debugPrint('✅ Firebase Rating: User rated successfully: $ratingId');
      return {
        'success': true,
        'ratingId': ratingId,
        'message': 'Rating submitted successfully'
      };
    } catch (e) {
      debugPrint('❌ Firebase Rating: Error rating user: $e');
      throw Exception('Failed to rate user: $e');
    }
  }

  // جلب تقييمات مستخدم
  Future<List<UserRating>> getUserRatings(String userId) async {
    try {
      debugPrint('🔄 Firebase Rating: Fetching ratings for user: $userId');

      final snapshot = await _database
          .child('ratings')
          .orderByChild('userId')
          .equalTo(userId)
          .get();

      if (!snapshot.exists) {
        debugPrint('📭 Firebase Rating: No ratings found for user: $userId');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final ratings = data.entries
          .map((entry) => _userRatingFromFirebase(entry.key, entry.value))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint(
          '✅ Firebase Rating: Found ${ratings.length} ratings for user: $userId');
      return ratings;
    } catch (e) {
      debugPrint('❌ Firebase Rating: Error fetching user ratings: $e');
      throw Exception('Failed to fetch user ratings: $e');
    }
  }

  // جلب متوسط تقييم مستخدم
  Future<double> getUserAverageRating(String userId) async {
    try {
      debugPrint(
          '🔄 Firebase Rating: Fetching average rating for user: $userId');

      final snapshot = await _database.child('users/$userId/rating').get();

      if (!snapshot.exists) {
        debugPrint(
            '📭 Firebase Rating: No average rating found for user: $userId');
        return 0.0;
      }

      final rating = (snapshot.value as num?)?.toDouble() ?? 0.0;
      debugPrint('✅ Firebase Rating: Average rating for user $userId: $rating');
      return rating;
    } catch (e) {
      debugPrint('❌ Firebase Rating: Error fetching average rating: $e');
      return 0.0;
    }
  }

  // تحديث متوسط التقييم للمستخدم
  Future<void> _updateUserAverageRating(String userId) async {
    try {
      debugPrint(
          '🔄 Firebase Rating: Updating average rating for user: $userId');

      // جلب جميع تقييمات المستخدم
      final snapshot = await _database
          .child('ratings')
          .orderByChild('userId')
          .equalTo(userId)
          .get();

      if (!snapshot.exists) {
        debugPrint(
            '📭 Firebase Rating: No ratings to calculate average for user: $userId');
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final ratings = data.values
          .map((rating) => (rating['rating'] as num).toDouble())
          .toList();

      // حساب المتوسط
      final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
      final totalRatings = ratings.length;

      // تحديث بيانات المستخدم
      await _database.child('users/$userId').update({
        'rating': averageRating,
        'totalRatings': totalRatings,
        'lastRatingUpdate': ServerValue.timestamp,
      });

      debugPrint(
          '✅ Firebase Rating: Updated average rating for user $userId: $averageRating ($totalRatings ratings)');
    } catch (e) {
      debugPrint('❌ Firebase Rating: Error updating average rating: $e');
    }
  }

  // تحويل بيانات Firebase إلى UserRating
  UserRating _userRatingFromFirebase(String ratingId, dynamic data) {
    final ratingData = data as Map<dynamic, dynamic>;

    return UserRating(
      id: ratingId,
      userId: ratingData['userId'] ?? '',
      ratedByUserId: ratingData['ratedByUserId'] ?? '',
      rating: (ratingData['rating'] as num).toDouble(),
      comment: ratingData['comment'],
      timestamp: DateTime.parse(
          ratingData['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // الاستماع لتقييمات مستخدم في الوقت الفعلي
  Stream<List<UserRating>> listenToUserRatings(String userId) {
    return _database
        .child('ratings')
        .orderByChild('userId')
        .equalTo(userId)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <UserRating>[];

      return data.entries
          .map((entry) => _userRatingFromFirebase(entry.key, entry.value))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // الاستماع لمتوسط تقييم مستخدم في الوقت الفعلي
  Stream<double> listenToUserAverageRating(String userId) {
    return _database.child('users/$userId/rating').onValue.map((event) {
      final rating = event.snapshot.value;
      return (rating as num?)?.toDouble() ?? 0.0;
    });
  }

  // تنظيف الموارد
  void dispose() {
    // يمكن إضافة تنظيف إضافي هنا إذا لزم الأمر
  }
}
