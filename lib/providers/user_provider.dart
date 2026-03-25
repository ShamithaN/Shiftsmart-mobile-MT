import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic> _userProfile = {};

  Map<String, dynamic> get userProfile => _userProfile;

  void setUserProfile(Map<String, dynamic> profile) {
    print("UserProvider: Updating profile with: $profile");
    // Merge new profile data into existing profile to avoid losing fields like role
    _userProfile = {..._userProfile, ...profile}; 
    notifyListeners();
  }

  void clearUserProfile() { 
    _userProfile = {}; 
    notifyListeners();
  }
}
