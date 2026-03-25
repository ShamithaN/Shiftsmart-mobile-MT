import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/services/profile_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/utils/profile_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/build_profile_avatar.dart';
import 'package:shiftsmart/widgets/emp_slidenav.dart';
import 'package:shiftsmart/widgets/gradient_button.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';
import 'package:shiftsmart/screens/employee/employee_next_of_kin.dart';

class EmployeeProfile extends StatefulWidget {
  const EmployeeProfile({super.key});

  @override
  State<EmployeeProfile> createState() => _EmployeeProfileState();
}

class _EmployeeProfileState extends State<EmployeeProfile> {
  // Navigation State
  int _currentStep = 1;
  bool _isInitialized = false;
  bool _isLoading = false;

  // Per-field inline validation errors
  final Map<String, String> _fieldErrors = {};

  // Data State
  File? _selectedProfilePicture;

  // --- Controllers: Step 1 (Personal Info) ---
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _midNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _suburbController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _postalController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();

  // --- Controllers: Step 2 (Bank & Job) ---
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _bsbController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _jobroleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    enableFullScreen();
  }

  // Load initial data from UserProvider when screen opens
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _populateFieldsFromUserProvider();
        _isInitialized = true;
      }
    });
  }

  // Helper to fill text controllers with existing user data
  void _populateFieldsFromUserProvider() {
    final userProfile =
        Provider.of<UserProvider>(context, listen: false).userProfile;

    setState(() {
      _firstNameController.text = userProfile['firstName'] ?? '';
      _midNameController.text = userProfile['middleName'] ?? '';
      _lastNameController.text = userProfile['lastName'] ?? '';
      _genderController.text = userProfile['gender'] ?? '';
      _phoneController.text = userProfile['mobileNumber'] ?? '';
      _emailController.text = userProfile['email'] ?? '';
      
      // Format Date of Birth: Remove time part (T00:00:00) if present
      String dob = userProfile['dateOfBirth'] ?? '';
      if (dob.contains('T')) {
        dob = dob.split('T')[0];
      }
      _dateController.text = dob;

      _streetController.text = userProfile['street'] ?? '';
      _suburbController.text = userProfile['city'] ?? '';
      _stateController.text = userProfile['state'] ?? '';
      _postalController.text = userProfile['postalCode'] ?? '';
      _countryController.text = userProfile['country'] ?? '';

      _accountNameController.text = userProfile['bankAccountName'] ?? '';
      _bsbController.text = userProfile['bankBSB'] ?? '';
      _accountNumberController.text = userProfile['bankAccountNumber'] ?? '';
      _bankNameController.text = userProfile['bankName'] ?? '';
      _jobroleController.text = userProfile['jobRole'] ?? '';
    });
  }



  // ── INLINE VALIDATION ─────────────────────────────────
  /// Returns true if all fields in the current step are valid.
  bool _validateStep() {
    final errors = <String, String>{};

    if (_currentStep == 1) {
      final first = _firstNameController.text.trim();
      if (first.isEmpty)
        errors['firstName'] = 'First Name is required.';
      else if (!RegExp(r"^[a-zA-ZÀ-ÿ\s.'-]{2,50}$").hasMatch(first))
        errors['firstName'] = '2–50 letters only.';

      final last = _lastNameController.text.trim();
      if (last.isEmpty)
        errors['lastName'] = 'Last Name is required.';
      else if (!RegExp(r"^[a-zA-ZÀ-ÿ\s.'-]{1,50}$").hasMatch(last))
        errors['lastName'] = 'Letters only.';

      if (_genderController.text.trim().isEmpty)
        errors['gender'] = 'Gender is required.';

      final phone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
      if (phone.isEmpty)
        errors['phone'] = 'Phone Number is required.';
      else if (!RegExp(r'^\+?[1-9]\d{6,14}$').hasMatch(phone))
        errors['phone'] = 'Use international format, e.g. +94771234567';

      final email = _emailController.text.trim();
      if (email.isEmpty)
        errors['email'] = 'Email is required.';
      else if (!RegExp(r'^[\w._%+\-]+@[\w.\-]+\.[a-zA-Z]{2,}$').hasMatch(email))
        errors['email'] = 'Enter a valid email address.';

      final dob = _dateController.text.trim();
      if (dob.isEmpty) {
        errors['dob'] = 'Date of Birth is required.';
      } else {
        try {
          final dobDate = DateTime.parse(dob);
          final age = DateTime.now().difference(dobDate).inDays ~/ 365;
          if (age < 16) errors['dob'] = 'Must be at least 16 years old.';
        } catch (_) {
          errors['dob'] = 'Use format YYYY-MM-DD.';
        }
      }

      if (_streetController.text.trim().isEmpty)
        errors['street'] = 'Street Address is required.';
      if (_suburbController.text.trim().isEmpty)
        errors['suburb'] = 'City/Suburb is required.';
      if (_countryController.text.trim().isEmpty)
        errors['country'] = 'Country is required.';
      final postal = _postalController.text.trim();
      if (postal.isNotEmpty && !RegExp(r'^[A-Za-z0-9\s\-]{2,10}$').hasMatch(postal))
        errors['postal'] = 'Enter a valid Postal/ZIP code.';
    }

    if (_currentStep == 2) {
      if (_accountNameController.text.trim().isEmpty)
        errors['accountName'] = 'Account Name is required.';
      final accNo = _accountNumberController.text.trim();
      if (accNo.isEmpty)
        errors['accountNumber'] = 'Account Number is required.';
      else if (!RegExp(r'^[0-9A-Za-z\-]{4,34}$').hasMatch(accNo))
        errors['accountNumber'] = 'Enter a valid account number (4–34 chars).';
      if (_bankNameController.text.trim().isEmpty)
        errors['bankName'] = 'Bank Name is required.';
      if (_jobroleController.text.trim().isEmpty)
        errors['jobRole'] = 'Job Role is required.';
    }

    setState(() {
      _fieldErrors.clear();
      _fieldErrors.addAll(errors);
    });
    return errors.isEmpty;
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2E), // Match app background
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toString().split(' ')[0];
        if (_fieldErrors.containsKey('dob')) _fieldErrors.remove('dob');
      });
    }
  }

  // Sends updated data to the backend
  // Returns true if successful, false otherwise
  Future<bool> _updateProfile(File? profilePictureFile) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employeeId = userProvider.userProfile['employeeId'];

    // Construct the profile object
    final profile = {
      "firstName": _firstNameController.text,
      "middleName": _midNameController.text,
      "lastName": _lastNameController.text,
      "gender": _genderController.text,
      "email": _emailController.text,
      "mobileNumber": _phoneController.text,
      "dateOfBirth": _dateController.text,
      "street": _streetController.text,
      "city": _suburbController.text,
      "state": _stateController.text,
      "postalCode": _postalController.text,
      "country": _countryController.text,
      "bankAccountName": _accountNameController.text,
      "bankBSB": _bsbController.text,
      "bankAccountNumber": _accountNumberController.text,
      "bankName": _bankNameController.text,
      "employmentStatus": "Active",
      "jobRole": _jobroleController.text
    };

    final error = await ProfileService().updateProfile(
      employeeId: employeeId,
      profile: profile,
      nextOfKins: const [],
      profilePicture: profilePictureFile,
    );

    return error == null;
  }

  // Builds the profile map from current form fields
  Map<String, dynamic> _buildProfileMap() {
    return {
      "firstName": _firstNameController.text,
      "middleName": _midNameController.text,
      "lastName": _lastNameController.text,
      "gender": _genderController.text,
      "email": _emailController.text,
      "mobileNumber": _phoneController.text,
      "dateOfBirth": _dateController.text,
      "street": _streetController.text,
      "city": _suburbController.text,
      "state": _stateController.text,
      "postalCode": _postalController.text,
      "country": _countryController.text,
      "bankAccountName": _accountNameController.text,
      "bankBSB": _bsbController.text,
      "bankAccountNumber": _accountNumberController.text,
      "bankName": _bankNameController.text,
      "employmentStatus": "Active",
      "jobRole": _jobroleController.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const Uppernavbar(showBackButton: true),
          drawer: const EmpSidenav(),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Scrollable Form Content
                        Expanded(
                          child: SingleChildScrollView(
                            child: Form(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_currentStep == 1) _buildProfileForm(),
                                  if (_currentStep == 2) _buildBankAndJobForm(),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Bottom Navigation Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button logic
                            if (_currentStep == 1)
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () => Navigator.pop(context),
                              ),
                            if (_currentStep > 1)
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () => setState(() => _currentStep--),
                              ),

                            // Next button logic
                            GradientButton(
                              text: 'Next',
                              onPressed: () {
                                if (!_validateStep()) return;
                                if (_currentStep < 2) {
                                  setState(() => _currentStep++);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmployeeNextOfKinScreen(
                                        profileData: _buildProfileMap(),
                                        profilePicture: _selectedProfilePicture,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 1: Personal Information ---
  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Center(
            child: ProfileAvatar(
          editable: true,
          initialImage: _selectedProfilePicture,
          onImageSelected: (File image) {
            setState(() {
              _selectedProfilePicture = image;
            });
          },
        )),
        const SizedBox(height: 20),
        _buildTextField("First Name", _firstNameController, errorKey: 'firstName'),
        _buildTextField("Middle Name", _midNameController),
        _buildTextField("Last Name", _lastNameController, errorKey: 'lastName'),
        _buildTextField("Gender", _genderController, errorKey: 'gender'),
        _buildTextField("Phone Number", _phoneController, errorKey: 'phone'),
        _buildTextField("Email", _emailController, errorKey: 'email'),
        _buildTextField("Date of birth", _dateController, 
            errorKey: 'dob', 
            readOnly: true, 
            onTap: _selectDate),
        const Text("Address",
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 12),
        _buildSubTextField("Street Address", _streetController, errorKey: 'street'),
        _buildSubTextField("Suburb", _suburbController, errorKey: 'suburb'),
        _buildSubTextField("State/Territory", _stateController),
        _buildSubTextField("Postal Code", _postalController, errorKey: 'postal',
            keyboardType: TextInputType.number),
        _buildSubTextField("Country", _countryController, errorKey: 'country'),
      ],
    );
  }

  // --- Step 2: Bank & Job ---
  Widget _buildBankAndJobForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text("Bank Details",
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 12),
        _buildSubTextField("Account Name", _accountNameController, errorKey: 'accountName'),
        _buildSubTextField("BSB Number", _bsbController,
            keyboardType: TextInputType.number),
        _buildSubTextField("Account Number", _accountNumberController,
            keyboardType: TextInputType.number, errorKey: 'accountNumber'),
        _buildSubTextField("Bank Name", _bankNameController, errorKey: 'bankName'),
        const SizedBox(height: 20),
        _buildTextField("Job Role", _jobroleController, errorKey: 'jobRole'),
      ],
    );
  }


  // --- UI Helper: Main Text Fields ---
  Widget _buildTextField(String label, TextEditingController controller,
      {String? errorKey, bool readOnly = false, VoidCallback? onTap}) {
    final error = errorKey != null ? _fieldErrors[errorKey] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: error != null ? Colors.redAccent : Colors.white),
            ),
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onTap: onTap,
              style: const TextStyle(color: Colors.white70),
              onChanged: (_) {
                if (errorKey != null && _fieldErrors.containsKey(errorKey)) {
                  setState(() => _fieldErrors.remove(errorKey));
                }
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                hintText: ' $label',
                hintStyle: const TextStyle(color: Colors.white70),
                suffixIcon: onTap != null ? const Icon(Icons.calendar_today, color: Colors.white70, size: 20) : null,
              ),
            ),
          ),
          if (error != null) ...
            [
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              ]),
            ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // --- UI Helper: Sub Text Fields ---
  Widget _buildSubTextField(
    String label,
    TextEditingController controller, {
    String? errorKey,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final error = errorKey != null ? _fieldErrors[errorKey] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: error != null ? Colors.redAccent : Colors.white),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              keyboardType: keyboardType,
              onChanged: (_) { if (errorKey != null && _fieldErrors.containsKey(errorKey)) setState(() => _fieldErrors.remove(errorKey)); },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: InputBorder.none,
                hintText: ' $label',
                hintStyle: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          if (error != null) ...
            [
              const SizedBox(height: 4),
              Row(children: [
                const SizedBox(width: 4),
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              ]),
            ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
