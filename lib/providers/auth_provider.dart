import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import '../services/revenue_cat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Compatible with google_sign_in 7.2.7
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  User? user;
  bool isLoading = false;

  AuthProvider() {
    _auth.authStateChanges().listen((User? u) {
      user = u;
      notifyListeners();
    });
  }

  // ---------------- EMAIL SIGNUP ----------------

  Future<void> emailSignup(
    String email,
    String password,
    String name, {
    String? referralCode,
  }) async {
    try {
      _setLoading(true);

      final UserCredential cred =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await cred.user!.updateDisplayName(name);

      await _syncUserToFirestore(
        cred.user!,
        name: name,
        isNewUser: true,
        referredBy: referralCode,
      );
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Registration failed";
    } finally {
      _setLoading(false);
    }
  }

  // ---------------- EMAIL LOGIN ----------------

  Future<void> emailLogin(String email, String password) async {
    try {
      _setLoading(true);

      final UserCredential cred =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _syncUserToFirestore(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Authentication failed";
    } finally {
      _setLoading(false);
    }
  }

  // ---------------- GOOGLE LOGIN (7.2.7 COMPATIBLE) ----------------

  Future<bool> googleLogin({String? referralCode}) async {
    try {
      _setLoading(true);

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return false; // user cancelled
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create credential - both tokens still work in 7.2.7
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential cred = await _auth.signInWithCredential(credential);

      final bool isNewUser = cred.additionalUserInfo?.isNewUser ?? false;

      await _syncUserToFirestore(
        cred.user!,
        isNewUser: isNewUser,
        referredBy: referralCode,
      );

      return true;
    } catch (e) {
      debugPrint("Google Auth Error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------- FIRESTORE SYNC ----------------

  Future<void> _syncUserToFirestore(
    User u, {
    String? name,
    bool isNewUser = false,
    String? referredBy,
  }) async {
    final docRef = _db.collection('users').doc(u.uid);

    // Set RevenueCat user ID
    await RevenueCatService.setUserId(u.uid);

    // Get current subscription plan
    final currentPlan = await RevenueCatService.getCurrentPlan();

    String? fcmToken;
    try {
      fcmToken = await _fcm.getToken();
    } catch (_) {}

    final Map<String, dynamic> data = {
      "uid": u.uid,
      "email": u.email,
      "name": name ?? u.displayName ?? "Fyllo User",
      "photoUrl": u.photoURL ?? "",
      "fcmToken": fcmToken ?? "",
      "platform": "mobile",
      "plan": currentPlan, // Add subscription plan
      "lastLogin": FieldValue.serverTimestamp(),
    };

    if (isNewUser) {
      data["createdAt"] = FieldValue.serverTimestamp();
      if (referredBy != null && referredBy.isNotEmpty) {
        data["referredBy"] = referredBy;
      }
      await docRef.set(data);
    } else {
      await docRef.set(data, SetOptions(merge: true));
    }
  }

  // ---------------- DELETE ACCOUNT ----------------

  Future<void> deleteAccount(BuildContext context) async {
    try {
      _setLoading(true);
      final User? u = _auth.currentUser;
      if (u == null) return;

      // 1. Delete all expenses in subcollection
      final expensesRef = _db
          .collection('users')
          .doc(u.uid)
          .collection('expenses');
      
      final expensesSnapshot = await expensesRef.get();
      for (var doc in expensesSnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. Delete User Document
      await _db.collection('users').doc(u.uid).delete();

      // 3. Delete Firebase Auth User
      try {
        await u.delete();
      } catch (e) {
        // If delete fails but we already nuked DB, we should still try to sign out locally
        // so the user isn't stuck in a "zombie" state.
        debugPrint("Warning: u.delete() failed or needed re-auth: $e");
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
           rethrow; // Handle this specifically below
        }
      }

      // 4. Force Sign Out & Clear Google Cache (CRITICAL FOR "EMPTY SLATE")
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // 5. Clear RevenueCat ID & Local Prefs
      await RevenueCatService.clearUserId();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Wipe everything for a truly clean slate
      
      user = null;
      notifyListeners();

      // 6. Hard Restart App to ensure clean state
      if (context.mounted) {
        Phoenix.rebirth(context);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
         // Force sign out so they HAVE to log in again to try deleting
         await _auth.signOut();
         if (context.mounted) Phoenix.rebirth(context);
         throw "For security, we signed you out. Please log in again and try deleting your account.";
      }
      throw e.message ?? "Delete account failed";
    } catch (e) {
       throw "An error occurred while deleting account: $e";
    } finally {
      // _setLoading(false); // No need to set loading false if we are rebirthing
    }
  }

  // ---------------- LOADING ----------------

  void _setLoading(bool v) {
    isLoading = v;
    notifyListeners();
  }
}
