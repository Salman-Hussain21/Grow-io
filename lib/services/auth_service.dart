import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/notification_model.dart';
import 'notification_service.dart';
import 'community_notification_handler.dart';
import 'plant_reminder_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _lastError;
  Timer? _reminderTimer;
  CommunityNotificationHandler? _notificationHandler;
  PlantReminderService? _plantReminderService;

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  void setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  // Initialize notification services for logged-in user
  void _initializeNotificationServices(String userId) {
    // Initialize services
    _notificationHandler = CommunityNotificationHandler();
    _plantReminderService = PlantReminderService();

    // Setup notification listeners
    _notificationHandler!.setupPostUpvoteListener();
    _notificationHandler!.setupCommentListeners();

    // Setup periodic plant reminders (every 6 hours)
    _reminderTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      _plantReminderService!.sendRandomPlantReminders();
      _plantReminderService!.sendCareTips();
    });

    // Send welcome notification
    _sendWelcomeNotification(userId);
  }

  // Cleanup notification services on logout
  void _cleanupNotificationServices() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _notificationHandler = null;
    _plantReminderService = null;
  }

  Future<void> _sendWelcomeNotification(String userId) async {
    final notificationService = NotificationService();
    await notificationService.sendNotification(
      userId: userId,
      type: NotificationType.communityUpdate,
      title: 'Welcome to Growio! 🌱',
      message: 'Start growing your plant community! Share your plants, get tips, and help others.',
      data: {'type': 'welcome'},
    );
  }

  // Sign up with email and password
  Future<User?> signUpWithEmail(String email, String password, String name) async {
    try {
      _setLoading(true);
      _lastError = null;

      print("Creating user: $email");

      // Create user with email and password
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = result.user;

      if (user != null) {
        print("User created: ${user.uid}");

        // Update display name
        await user.updateDisplayName(name.trim());

        // Send verification email
        await user.sendEmailVerification();

        await user.reload();
        user = _auth.currentUser;

        print("Name updated: ${user?.displayName}");

        // Initialize notification services for new user
        _initializeNotificationServices(user!.uid);
      }

      _setLoading(false);
      return user;

    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _lastError = _getAuthErrorMessage(e);
      print("Sign up error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      _setLoading(false);
      _lastError = "Something went wrong. Please try again.";
      print("Unexpected error: $e");
      return null;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _lastError = null;

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        // Initialize notification services for logged-in user
        _initializeNotificationServices(result.user!.uid);
      }

      _setLoading(false);
      return result.user;

    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _lastError = _getAuthErrorMessage(e);
      print("Sign in error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      _setLoading(false);
      _lastError = "Something went wrong. Please try again.";
      print("Unexpected error: $e");
      return null;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _lastError = _getAuthErrorMessage(e);
      print("Password reset error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      _lastError = "Something went wrong. Please try again.";
      print("Unexpected error: $e");
      return false;
    }
  }

  // Check email verification status
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  // Resend verification email
  Future<bool> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      _lastError = "Failed to send verification email.";
      print("Resend verification error: $e");
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        await user.reload();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _lastError = "Failed to update profile.";
      print("Update profile error: $e");
      return false;
    }
  }

  // Update user email
  Future<bool> updateUserEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(newEmail.trim());
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _lastError = _getAuthErrorMessage(e);
      print("Update email error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      _lastError = "Something went wrong. Please try again.";
      print("Unexpected error: $e");
      return false;
    }
  }

  // Update user password
  Future<bool> updateUserPassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword.trim());
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _lastError = _getAuthErrorMessage(e);
      print("Update password error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      _lastError = "Something went wrong. Please try again.";
      print("Unexpected error: $e");
      return false;
    }
  }

  // Delete user account
  Future<bool> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();

        // Cleanup notification services
        _cleanupNotificationServices();

        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _lastError = _getAuthErrorMessage(e);
      print("Delete account error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      _lastError = "Something went wrong. Please try again.";
      print("Unexpected error: $e");
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Cleanup notification services first
      _cleanupNotificationServices();

      await _auth.signOut();
      notifyListeners();
      print("User signed out successfully");
    } on FirebaseAuthException catch (e) {
      _lastError = _getAuthErrorMessage(e);
      print("Sign out error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      _lastError = "Something went wrong during sign out.";
      print("Unexpected sign out error: $e");
      rethrow;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user display name
  String? getDisplayName() {
    return _auth.currentUser?.displayName;
  }

  // Get user email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  // Get user ID
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  // Check if user is verified
  bool isEmailVerified() {
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Google Sign In (placeholder - implement as needed)
  Future<User?> signInWithGoogle() async {
    // Implement Google Sign In logic here
    // This is a placeholder method
    return null;
  }

  // Error message helper
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again to perform this action.';
      case 'user-mismatch':
        return 'The provided credentials do not match the current user.';
      case 'provider-already-linked':
        return 'This account is already linked with another provider.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different user account.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Contact support.';
      case 'expired-action-code':
        return 'The action code has expired. Please try again.';
      case 'invalid-action-code':
        return 'The action code is invalid. Please try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}