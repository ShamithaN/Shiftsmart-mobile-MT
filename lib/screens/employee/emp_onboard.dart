import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shiftsmart/services/employee_service.dart';
import 'package:shiftsmart/services/job_service.dart';
import 'package:shiftsmart/models/job_role_type.dart';
import 'package:shiftsmart/services/onboarding_service.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/build_profile_avatar.dart';
import 'package:shiftsmart/widgets/gradient_button.dart';
import 'package:shiftsmart/screens/login.dart';

class _DialCountry {
  final String name;
  final String code;
  final String flag;

  const _DialCountry({
    required this.name,
    required this.code,
    required this.flag,
  });
}

class Emponboard extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? existingProfile;
  final int? employeeId;
  final String? rejectionReason;

  const Emponboard({
    super.key,
    required this.email,
    this.existingProfile,
    this.employeeId,
    this.rejectionReason,
  });

  @override
  State<Emponboard> createState() => _EmponboardState();
}

class _EmponboardState extends State<Emponboard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final OnboardingService _service = OnboardingService();

  int _currentStep = 1;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isResubmission = false;

  bool _isLoadingBank = false;
  bool _isBankNameReadOnly = true;
  final FocusNode _bsbFocusNode = FocusNode();

  Key _avatarKey = UniqueKey();

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _midNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  final _tfnCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();

  final _accNameCtrl = TextEditingController();
  final _bsbCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _nokNameCtrl = TextEditingController();
  final _nokRelCtrl = TextEditingController();
  final _nokPhoneCtrl = TextEditingController();
  final _nokEmailCtrl = TextEditingController();
  final _nokAddressCtrl = TextEditingController();

  String _jobRole = "";
  String _empType = "";
  String? _invitationToken;
  int? _invitationId;
  List<String> _requiredDocs = [];
  List<String> _rejectedKeys = [];

  File? _profilePic;
  final Map<String, File> _uploadedDocs = {};
  final Map<String, int> _requiredDocIds = {};
  final Set<String> _resubmittedDocs = {};
  String? _updatingDocName;

  String? _gender;

  final List<String> _genderOptions = [
    "Man",
    "Woman",
    "Non-binary",
    "I use a different term",
    "Prefer not to say",
  ];

  final List<Map<String, dynamic>> _nokList = [];

  static const List<_DialCountry> _dialCountries = [
    _DialCountry(name: 'Australia', code: '+61', flag: '🇦🇺'),
    _DialCountry(name: 'Sri Lanka', code: '+94', flag: '🇱🇰'),
    _DialCountry(name: 'United States', code: '+1', flag: '🇺🇸'),
    _DialCountry(name: 'India', code: '+91', flag: '🇮🇳'),
    _DialCountry(name: 'United Kingdom', code: '+44', flag: '🇬🇧'),
    _DialCountry(name: 'New Zealand', code: '+64', flag: '🇳🇿'),
    _DialCountry(name: 'Canada', code: '+1', flag: '🇨🇦'),
    _DialCountry(name: 'Singapore', code: '+65', flag: '🇸🇬'),
    _DialCountry(name: 'Malaysia', code: '+60', flag: '🇲🇾'),
    _DialCountry(name: 'United Arab Emirates', code: '+971', flag: '🇦🇪'),
  ];

  _DialCountry _selectedProfileCountry = _dialCountries.first;
  _DialCountry _selectedNokCountry = _dialCountries.first;

  final List<String> _allAvailableDocTypes = [
    "National ID",
    "Resume",
    "Electrical License",
    "White Card",
    "Driver's License",
    "RSA",
    "Police Check",
    "Passport",
    "Visa",
    "Other Certificate",
  ];

  @override
  void initState() {
    super.initState();
    _profilePic = null;

    if (widget.rejectionReason != null && widget.rejectionReason!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRejectionReasonDialog(widget.rejectionReason!);
      });
    }

    _initData();
    _bsbFocusNode.addListener(() {
      if (!_bsbFocusNode.hasFocus) {
        String clean = _bsbCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (clean.length == 6) _handleBsbLookup();
      }
    });
  }

  @override
  void dispose() {
    _bsbFocusNode.dispose();
    _firstNameCtrl.dispose();
    _midNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _countryCtrl.dispose();
    _tfnCtrl.dispose();
    _abnCtrl.dispose();
    _accNameCtrl.dispose();
    _bsbCtrl.dispose();
    _accNumCtrl.dispose();
    _bankNameCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nokNameCtrl.dispose();
    _nokRelCtrl.dispose();
    _nokPhoneCtrl.dispose();
    _nokEmailCtrl.dispose();
    _nokAddressCtrl.dispose();
    super.dispose();
  }

  void _setPhoneFromInternational(
    TextEditingController controller,
    String? rawValue,
    ValueChanged<_DialCountry> onCountryChanged,
  ) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) {
      controller.clear();
      return;
    }

    final cleanValue = value.replaceAll(RegExp(r'\s|-|\(|\)'), '');
    final country = _dialCountries
        .where((country) => cleanValue.startsWith(country.code))
        .fold<_DialCountry?>(null, (best, country) {
      if (best == null || country.code.length > best.code.length) {
        return country;
      }
      return best;
    });

    if (country == null) {
      controller.text = value.replaceAll(RegExp(r'[^0-9]'), '');
      return;
    }

    onCountryChanged(country);
    controller.text = cleanValue
        .substring(country.code.length)
        .replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _buildFullPhoneNumber(
    TextEditingController controller,
    _DialCountry country,
  ) {
    var localNumber = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (localNumber.startsWith('0')) {
      localNumber = localNumber.substring(1);
    }
    if (localNumber.isEmpty) return '';
    return '${country.code}$localNumber';
  }

  String? _validatePhoneNumber(
    String? value, {
    required String label,
    bool optional = false,
  }) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return optional ? null : '$label is required';
    if (digits.length < 6 || digits.length > 14) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String _readDocumentType(dynamic doc) {
    if (doc is String) return doc.trim();
    if (doc is! Map) return '';
    final value = doc['DocumentType'] ??
        doc['documentType'] ??
        doc['FileType'] ??
        doc['fileType'] ??
        doc['Name'] ??
        doc['name'];
    return value?.toString().trim() ?? '';
  }

  int? _readDocumentId(dynamic doc) {
    if (doc is! Map) return null;
    final value = doc['DocumentId'] ??
        doc['documentId'] ??
        doc['Id'] ??
        doc['id'] ??
        doc['CertificateId'] ??
        doc['certificateId'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String? _readFirstStringByKeys(dynamic source, List<String> keys) {
    if (source is Map) {
      for (final key in keys) {
        final value = source[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }

      for (final value in source.values) {
        final nested = _readFirstStringByKeys(value, keys);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    } else if (source is List) {
      for (final value in source) {
        final nested = _readFirstStringByKeys(value, keys);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    return null;
  }

  int? _readInvitationId(dynamic source) {
    final value = _readFirstStringByKeys(source, const [
      'invitationId',
      'InvitationId',
      'InvitationID',
    ]);
    return int.tryParse(value ?? '');
  }

  void _applyInvitationAuthData(Map<String, dynamic> data) {
    _invitationToken = _readFirstStringByKeys(data, const [
      'token',
      'Token',
      'invitationToken',
      'InvitationToken',
      'onboardingToken',
      'OnboardingToken',
    ]);
    _invitationId = _readInvitationId(data);
  }

  bool _stepHasContent(int step) {
    if (!_isResubmission) return true;
    if (step == 1) {
      return _shouldShow("FullName") ||
          _shouldShow("Gender") ||
          _shouldShow("MobileNumber") ||
          _shouldShow("DateOfBirth") ||
          _shouldShow("Address") ||
          _shouldShow("TaxInfo");
    }
    if (step == 2) return _shouldShow("Bank");
    if (step == 3) return _shouldShow("NextOfKin");
    if (step == 4) return _requiredDocs.isNotEmpty;
    return false;
  }

  int? _getNextStep(int current) {
    for (int i = current + 1; i <= 4; i++) {
      if (_stepHasContent(i)) return i;
    }
    return null;
  }

  int? _getPrevStep(int current) {
    for (int i = current - 1; i >= 1; i--) {
      if (_stepHasContent(i)) return i;
    }
    return null;
  }

  bool _shouldShow(String key) {
    if (!_isResubmission) return true;
    return _rejectedKeys.contains(key);
  }

  Future<void> _initData() async {
    if (widget.existingProfile != null) {
      _mapResubmissionData(widget.existingProfile!);
    } else {
      final data = await _service.fetchInvitation(widget.email);
      if (data != null) {
        _mapInvitationData(data);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBsbLookup() async {
    String bsb = _bsbCtrl.text.trim();
    String cleanBsb = bsb.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanBsb.length != 6) return;

    setState(() => _isLoadingBank = true);
    try {
      final result = await EmployeeService().lookupBank(cleanBsb);
      if (result['status'] == 'Found') {
        setState(() {
          _bankNameCtrl.text = result['bankName'].toString();
          _isBankNameReadOnly = true;
        });
      } else {
        setState(() {
          _bankNameCtrl.clear();
          _isBankNameReadOnly = false;
        });
      }
    } catch (e) {
      setState(() => _isBankNameReadOnly = false);
    } finally {
      if (mounted) setState(() => _isLoadingBank = false);
    }
  }

  void _mapResubmissionData(Map<String, dynamic> data) {
    setState(() {
      _isResubmission = true;
      if (data['RejectedFields'] != null) {
        _rejectedKeys = List<String>.from(data['RejectedFields']);
      }
      final rejectedDocsList =
          data['RejectedDocuments'] as List<dynamic>? ?? [];
      _requiredDocs = [];
      _requiredDocIds.clear();
      _resubmittedDocs.clear();
      if (rejectedDocsList.isNotEmpty) {
        for (final doc in rejectedDocsList) {
          final docType = _readDocumentType(doc);
          if (docType.isEmpty) continue;

          _requiredDocs.add(docType);
          final docId = _readDocumentId(doc);
          if (docId != null && docId > 0) {
            _requiredDocIds[docType] = docId;
          }
        }
      }

      final profile = data['Profile'] ?? {};
      String fullName = (profile['FullName'] ?? '').trim();
      List<String> nameParts = fullName.split(RegExp(r'\s+'));

      if (nameParts.isNotEmpty) {
        _firstNameCtrl.text = nameParts.first;
        if (nameParts.length == 2) {
          _lastNameCtrl.text = nameParts.last;
        } else if (nameParts.length > 2) {
          _midNameCtrl.text =
              nameParts.sublist(1, nameParts.length - 1).join(' ');
          _lastNameCtrl.text = nameParts.last;
        }
      }

      _dobCtrl.text = (profile['DateOfBirth'] ?? '').split('T').first;
      _setPhoneFromInternational(
        _phoneCtrl,
        profile['MobileNumber']?.toString(),
        (country) => _selectedProfileCountry = country,
      );

      String? incomingGender = profile['Gender'];
      if (incomingGender != null) {
        if (_genderOptions.contains(incomingGender)) {
          _gender = incomingGender;
        } else if (incomingGender.toLowerCase() == "male") {
          _gender = "Man";
        } else if (incomingGender.toLowerCase() == "female") {
          _gender = "Woman";
        } else {
          _gender = null;
        }
      }

      String rawAddress = profile['Address'] ?? '';
      List<String> addrParts =
          rawAddress.split(',').map((s) => s.trim()).toList();

      if (addrParts.isNotEmpty) {
        if (addrParts.isNotEmpty) _streetCtrl.text = addrParts[0];
        if (addrParts.length > 1) _cityCtrl.text = addrParts[1];
        if (addrParts.length > 2) _stateCtrl.text = addrParts[2];
        if (addrParts.length > 3) _zipCtrl.text = addrParts[3];
        if (addrParts.length > 4) _countryCtrl.text = addrParts[4];
      }

      final bank = profile['Bank'] ?? {};
      _bankNameCtrl.text = bank['Name'] ?? '';
      _bsbCtrl.text = bank['BSB'] ?? '';
      _accNumCtrl.text = bank['AccountNumber'] ?? '';
      _accNameCtrl.text = bank['AccountName'] ?? '';

      final tax = profile['TaxInfo'] ?? {};
      _empType = tax['EmploymentType'] ?? 'PAYG Employee';
      _tfnCtrl.text = tax['Tfn'] ?? '';
      _abnCtrl.text = tax['Abn'] ?? '';

      _jobRole = profile['JobRole'] ?? 'Standard Role';

      final noks = profile['NextOfKins'] as List<dynamic>? ?? [];
      _nokList.clear();
      for (var nok in noks) {
        _nokList.add({
          "fullName": nok['FullName'] ?? '',
          "relationship": nok['Relationship'] ?? '',
          "mobileNumber": nok['MobileNumber'] ?? '',
          "email": nok['Email'] ?? '',
          "address": nok['Address'] ?? '',
        });
      }
      _isLoading = false;
    });
  }

  void _mapInvitationData(Map<String, dynamic> data) {
    setState(() {
      _isResubmission = false;
      String fullName = (data['name'] ?? data['Name'] ?? '').trim();
      List<String> nameParts = fullName.split(RegExp(r'\s+'));

      if (nameParts.isNotEmpty) {
        _firstNameCtrl.text = nameParts.first;
        if (nameParts.length == 2) {
          _lastNameCtrl.text = nameParts.last;
        } else if (nameParts.length > 2) {
          _midNameCtrl.text =
              nameParts.sublist(1, nameParts.length - 1).join(' ');
          _lastNameCtrl.text = nameParts.last;
        }
      }

      _setPhoneFromInternational(
        _phoneCtrl,
        (data['phone'] ?? data['Phone'])?.toString(),
        (country) => _selectedProfileCountry = country,
      );
      _applyInvitationAuthData(data);
      _jobRole = data['jobRole'] ?? data['JobRole'] ?? '';
      _empType = data['employmentType'] ?? data['EmploymentType'] ?? '';

      dynamic docsRaw = data['requiredCertificates'] ??
          data['RequiredDocuments'] ??
          data['RequiredCertificates'] ??
          data['Certificates'] ??
          data['Documents'] ??
          data['required_documents'];

      if (docsRaw != null) {
        if (docsRaw is List) {
          _requiredDocs = docsRaw
              .map(_readDocumentType)
              .where((e) => e.isNotEmpty)
              .toList();
        } else if (docsRaw is String) {
          _requiredDocs = docsRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }

      if (_requiredDocs.isEmpty && _jobRole.isNotEmpty) {
        _fetchRoleRequirements();
      }
      _isLoading = false;
    });
  }

  Future<void> _fetchRoleRequirements() async {
    try {
      final List<JobRoleType> roles = await JobService().fetchJobRoleType();
      final target = roles.firstWhere(
        (r) => r.name.toLowerCase() == _jobRole.toLowerCase(),
        orElse: () => JobRoleType.unKnown(),
      );

      if (target.id != 0 && target.requiredDocuments.isNotEmpty) {
        setState(() {
          _requiredDocs = target.requiredDocuments;
        });
      }
    } catch (e) {
      debugPrint(" Error fetching role requirements: $e");
    }
  }

  String? _validateAge(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Date of Birth is required";
    return null;
  }

  void _pickProfileImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.white),
          title:
              const Text('Take Photo', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(ctx);
            final XFile? img = await ImagePicker()
                .pickImage(source: ImageSource.camera, imageQuality: 80);
            if (img != null) {
              setState(() {
                _profilePic = File(img.path);
                _avatarKey = UniqueKey();
              });
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library, color: Colors.white),
          title:
              const Text('From Gallery', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(ctx);
            final XFile? img = await ImagePicker()
                .pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (img != null) {
              setState(() {
                _profilePic = File(img.path);
                _avatarKey = UniqueKey();
              });
            }
          },
        ),
      ]),
    );
  }

  Future<File?> _selectDocumentFile({bool directCamera = false}) async {
    if (directCamera) {
      return _openCamera();
    }

    return showModalBottomSheet<File?>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.white),
          title:
              const Text('Take Photo', style: TextStyle(color: Colors.white)),
          onTap: () async {
            final file = await _openCamera();
            if (ctx.mounted) Navigator.pop(ctx, file);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library, color: Colors.white),
          title:
              const Text('From Gallery', style: TextStyle(color: Colors.white)),
          onTap: () async {
            final XFile? img = await ImagePicker()
                .pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (ctx.mounted) {
              Navigator.pop(ctx, img == null ? null : File(img.path));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.attach_file, color: Colors.white),
          title: const Text('Pick File (PDF)',
              style: TextStyle(color: Colors.white)),
          onTap: () async {
            FilePickerResult? result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
            );
            final path = result?.files.single.path;
            if (ctx.mounted) {
              Navigator.pop(ctx, path == null ? null : File(path));
            }
          },
        ),
      ]),
    );
  }

  Future<File?> _openCamera() async {
    final XFile? img = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (img == null) {
      return null;
    }
    return File(img.path);
  }

  Future<void> _updateRequiredDocument(
    String docName, {
    bool directCamera = false,
  }) async {
    final file = await _selectDocumentFile(directCamera: directCamera);
    if (file == null) return;

    final documentId = _requiredDocIds[docName];
    if (documentId == null || documentId <= 0) {
      setState(() => _uploadedDocs[docName] = file);
      return;
    }

    setState(() => _updatingDocName = docName);
    final error = await _service.resubmitDocument(
      documentId: documentId,
      file: file,
      documentType: docName,
    );

    if (!mounted) return;

    setState(() {
      _updatingDocName = null;
      if (error == null) {
        _uploadedDocs[docName] = file;
        _resubmittedDocs.add(docName);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "Document updated successfully."),
        backgroundColor: error == null ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<void> _selectDob(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      String formatted =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() => _dobCtrl.text = formatted);
    }
  }

  void _showRejectionReasonDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2F45),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    color: Colors.red, size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "Profile Error",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                reason,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Okay",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2F45),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "Submission Successful!",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "Your details have been submitted for review. You can now login.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: "Go to Login",
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                        (route) => false);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    Map<String, dynamic> payload = {};

    String finalGender = _gender ?? "";
    if (finalGender == "Man") finalGender = "Male";
    if (finalGender == "Woman") finalGender = "Female";

    if (_isResubmission) {
      payload["EmployeeId"] = widget.employeeId ?? 0;
      payload["Email"] = widget.email;

      if (_rejectedKeys.contains("FullName")) {
        String middleName =
            _midNameCtrl.text.trim().isEmpty ? "N/A" : _midNameCtrl.text.trim();
        payload["FullName"] =
            "${_firstNameCtrl.text.trim()} $middleName ${_lastNameCtrl.text.trim()}"
                .trim();
      }
      if (_rejectedKeys.contains("Gender")) {
        payload["Gender"] = finalGender;
      }
      if (_rejectedKeys.contains("DateOfBirth")) {
        payload["DateOfBirth"] = _dobCtrl.text.contains("T")
            ? _dobCtrl.text
            : "${_dobCtrl.text}T00:00:00";
      }
      if (_rejectedKeys.contains("MobileNumber")) {
        payload["MobileNumber"] =
            _buildFullPhoneNumber(_phoneCtrl, _selectedProfileCountry);
      }
      if (_rejectedKeys.contains("Address")) {
        payload["Street"] =
            _streetCtrl.text.trim().isEmpty ? "N/A" : _streetCtrl.text.trim();
        payload["City"] = _cityCtrl.text;
        payload["State"] =
            _stateCtrl.text.trim().isEmpty ? "N/A" : _stateCtrl.text.trim();
        payload["PostalCode"] =
            _zipCtrl.text.trim().isEmpty ? "N/A" : _zipCtrl.text.trim();
        payload["Country"] =
            _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia";
      }
      if (_rejectedKeys.contains("Bank")) {
        payload["BankBSB"] =
            _bsbCtrl.text.trim().isEmpty ? "N/A" : _bsbCtrl.text.trim();
        payload["BankAccountNumber"] =
            _accNumCtrl.text.trim().isEmpty ? "N/A" : _accNumCtrl.text.trim();
        payload["BankAccountName"] =
            _accNameCtrl.text.trim().isEmpty ? "N/A" : _accNameCtrl.text.trim();
        payload["BankName"] = _bankNameCtrl.text.trim().isEmpty
            ? "N/A"
            : _bankNameCtrl.text.trim();
      }
      if (_rejectedKeys.contains("TaxInfo")) {
        payload["EmploymentType"] = _empType;
        if (_empType.contains("Contractor")) {
          payload["Abn"] =
              _abnCtrl.text.trim().isEmpty ? "N/A" : _abnCtrl.text.trim();
        }
        if (_empType.contains("Employee")) {
          payload["Tfn"] =
              _tfnCtrl.text.trim().isEmpty ? "N/A" : _tfnCtrl.text.trim();
        }
      }
      if (_rejectedKeys.contains("NextOfKin") && _nokList.isNotEmpty) {
        var firstNok = _nokList.first;
        payload["NextOfKin"] = {
          "FullName": firstNok['fullName'],
          "MobileNumber": firstNok['mobileNumber'],
          "Email": firstNok['email'].toString().trim().isEmpty
              ? "N/A"
              : firstNok['email'],
          "Relationship": firstNok['relationship'].toString().trim().isEmpty
              ? "N/A"
              : firstNok['relationship'],
          "Address": firstNok['address'].toString().trim().isEmpty
              ? "N/A"
              : firstNok['address'],
          "IsPrimary": true
        };
      }

      if (_uploadedDocs.isNotEmpty) {
        List<Map<String, dynamic>> documentsList = [];
        _uploadedDocs.forEach((key, file) {
          documentsList.add({
            "DocumentId": _requiredDocIds[key] ?? 0,
            "DocumentType": key,
            "DocumentUrl": ""
          });
        });
        payload["Documents"] = documentsList;
      }
    } else {
      String middleName =
          _midNameCtrl.text.trim().isEmpty ? "N/A" : _midNameCtrl.text.trim();
      String street =
          _streetCtrl.text.trim().isEmpty ? "N/A" : _streetCtrl.text.trim();
      String state =
          _stateCtrl.text.trim().isEmpty ? "N/A" : _stateCtrl.text.trim();
      String postcode =
          _zipCtrl.text.trim().isEmpty ? "N/A" : _zipCtrl.text.trim();
      String bsb = _bsbCtrl.text.trim().isEmpty ? "N/A" : _bsbCtrl.text.trim();
      String accountNum =
          _accNumCtrl.text.trim().isEmpty ? "N/A" : _accNumCtrl.text.trim();
      String accountName =
          _accNameCtrl.text.trim().isEmpty ? "N/A" : _accNameCtrl.text.trim();
      String bankName =
          _bankNameCtrl.text.trim().isEmpty ? "N/A" : _bankNameCtrl.text.trim();
      String tfn = _tfnCtrl.text.trim().isEmpty ? "N/A" : _tfnCtrl.text.trim();
      String abn = _abnCtrl.text.trim().isEmpty ? "N/A" : _abnCtrl.text.trim();

      payload = {
        "FirstName": _firstNameCtrl.text,
        "MiddleName": middleName,
        "LastName": _lastNameCtrl.text,
        "Email": widget.email,
        "MobileNumber":
            _buildFullPhoneNumber(_phoneCtrl, _selectedProfileCountry),
        "Gender": finalGender,
        "DateOfBirth": _dobCtrl.text.isNotEmpty ? _dobCtrl.text : "1990-01-01",
        "Street": street,
        "City": _cityCtrl.text,
        "State": state,
        "PostalCode": postcode,
        "Country":
            _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia",
        "BankBSB": bsb,
        "BankAccountNumber": accountNum,
        "BankAccountName": accountName,
        "BankName": bankName,
        "EmploymentType": _empType,
        "JobRole": _jobRole,
      };
      if (_invitationId != null) payload["InvitationId"] = _invitationId;
      if (_invitationToken != null && _invitationToken!.isNotEmpty) {
        payload["InvitationToken"] = _invitationToken;
        payload["Token"] = _invitationToken;
      }
      if (_empType.contains("Contractor")) payload["Abn"] = abn;
      if (_empType.contains("Employee")) payload["Tfn"] = tfn;

      if (_uploadedDocs.isNotEmpty) {
        List<Map<String, dynamic>> documentsList = [];
        _uploadedDocs.forEach((key, file) {
          documentsList
              .add({"DocumentId": 0, "DocumentType": key, "DocumentUrl": ""});
        });
        payload["Certificates"] = documentsList;
      }
    }

    try {
      if (!_isResubmission &&
          (_invitationToken == null || _invitationToken!.isEmpty)) {
        final invitationData = await _service.fetchInvitation(widget.email);
        if (invitationData != null) {
          _applyInvitationAuthData(invitationData);
          if (_invitationId != null) payload["InvitationId"] = _invitationId;
          if (_invitationToken != null && _invitationToken!.isNotEmpty) {
            payload["InvitationToken"] = _invitationToken;
            payload["Token"] = _invitationToken;
          }
        }
      }

      if (!_isResubmission &&
          (_invitationToken == null || _invitationToken!.isEmpty)) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showErrorWithRetry(
              "Invitation token is missing. Please reopen the onboarding link or login again.");
        }
        return;
      }

      final docsToSubmit = Map<String, File>.from(_uploadedDocs);
      if (_isResubmission) {
        for (final docName in _resubmittedDocs) {
          docsToSubmit.remove(docName);
        }
      }

      final response = await _service.submitOnboardingForm(
        profilePicture: _profilePic ?? File(''),
        uploadedCertificates: docsToSubmit,
        profile: payload,
        nextOfKins: _nokList,
        password: _passCtrl.text.trim(),
        isResubmission: _isResubmission,
        invitationToken: _invitationToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showErrorWithRetry("Status Code: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorWithRetry(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF2F3846),
          body: Center(child: CircularProgressIndicator()));
    }

    int? nextStep = _getNextStep(_currentStep);
    int? prevStep = _getPrevStep(_currentStep);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
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
                        Expanded(
                          child: SingleChildScrollView(
                            child: Form(
                              key: _formKey,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_currentStep == 1) _buildStep1Profile(),
                                  if (_currentStep == 2)
                                    _buildStep2BankAndAuth(),
                                  if (_currentStep == 3) _buildStep3NextOfKin(),
                                  if (_currentStep == 4) _buildStep4Documents(),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (prevStep == null)
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const Login())),
                              )
                            else
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () =>
                                    setState(() => _currentStep = prevStep),
                              ),
                            GradientButton(
                              text: nextStep == null
                                  ? (_isSubmitting ? "Submitting..." : "Submit")
                                  : "Next",
                              onPressed: () {
                                if (nextStep != null) {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _currentStep = nextStep);
                                  }
                                } else {
                                  // Final Step Validation (Documents & Submit)
                                  bool isStepValid = true;

                                  if (_currentStep == 3 &&
                                      _shouldShow("NextOfKin")) {
                                    isStepValid = _nokList.isNotEmpty;
                                  } else if (_currentStep == 4) {
                                    isStepValid = _requiredDocs.isEmpty ||
                                        _requiredDocs.every((doc) =>
                                            _uploadedDocs.containsKey(doc) ||
                                            _resubmittedDocs.contains(doc));
                                  }

                                  if (_isResubmission &&
                                      !_stepHasContent(_currentStep)) {
                                    isStepValid = true;
                                  }

                                  if (isStepValid && !_isSubmitting) {
                                    _submitForm();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(_currentStep == 3
                                            ? "Please add at least one Next of Kin."
                                            : "Please upload required documents."),
                                        backgroundColor: Colors.redAccent));
                                  }
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
        ],
      ),
    );
  }

  Widget _buildStep1Profile() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: ProfileAvatar(
          key: _avatarKey,
          editable: true,
          initialImage: _profilePic,
          onImageSelected: (File image) {
            setState(() {
              _profilePic = image;
            });
          },
        ),
      ),
      const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            "Profile Picture (Optional)",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (_shouldShow("FullName")) ...[
        _buildTextField("First Name", _firstNameCtrl),
        _buildTextField("Middle Name (Optional)", _midNameCtrl,
            validator: (_) => null),
        _buildTextField("Last Name", _lastNameCtrl),
      ],
      if (_shouldShow("Gender"))
        _buildDropdown("Gender", _genderOptions, _gender,
            (v) => setState(() => _gender = v)),
      if (_shouldShow("MobileNumber"))
        _buildPhoneNumberField(
          label: "Mobile Number",
          controller: _phoneCtrl,
          selectedCountry: _selectedProfileCountry,
          onCountryChanged: (country) =>
              setState(() => _selectedProfileCountry = country),
        ),
      if (_shouldShow("DateOfBirth"))
        _buildDatePicker("Date of Birth", _dobCtrl, validator: _validateAge),
      if (_shouldShow("Address")) ...[
        _buildTextField("Street (Optional)", _streetCtrl,
            validator: (_) => null),
        _buildTextField("City", _cityCtrl),
        _buildTextField("State (Optional)", _stateCtrl, validator: (_) => null),
        _buildTextField("Postcode (Optional)", _zipCtrl,
            keyboardType: TextInputType.number, validator: (_) => null),
        _buildTextField("Country", _countryCtrl),
      ],
      const SizedBox(height: 20),
      const Text("Employment Details",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      _buildReadOnlyField("Job Role", _jobRole),
      _buildReadOnlyField("Employment Type", _empType),
      if (_shouldShow("TaxInfo")) ...[
        if (_empType.contains("Contractor"))
          _buildTextField("ABN (Optional)", _abnCtrl, validator: (_) => null),
        if (_empType.contains("Employee"))
          _buildTextField("TFN (Optional)", _tfnCtrl, validator: (_) => null),
      ]
    ]);
  }

  Widget _buildStep2BankAndAuth() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_shouldShow("Bank")) ...[
        const Text("Bank Details (Optional - All fields can be left empty)",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 10),
        _buildTextField("Account Name (Optional)", _accNameCtrl,
            validator: (_) => null),
        _buildTextField("BSB (Optional)", _bsbCtrl,
            validator: (_) => null,
            focusNode: _bsbFocusNode,
            onChanged: (val) {
              String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
              if (clean.length == 6) {
                _handleBsbLookup();
              } else {
                if (!_isBankNameReadOnly || _bankNameCtrl.text.isNotEmpty) {
                  setState(() {
                    _bankNameCtrl.clear();
                    _isBankNameReadOnly = true;
                  });
                }
              }
            },
            onFieldSubmitted: (_) => _handleBsbLookup(),
            suffixIcon: _isLoadingBank
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : null),
        _buildTextField("Account Number (Optional)", _accNumCtrl,
            validator: (_) => null),
        _buildTextField("Bank Name (Optional)", _bankNameCtrl,
            readOnly: _isBankNameReadOnly, validator: (_) => null),
      ],
      if (!_isResubmission) ...[
        const SizedBox(height: 20),
        const Text("Set Password",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 10),
        _buildTextField("New Password", _passCtrl,
            obscure: true,
            validator: (v) => v!.length < 6 ? "Min 6 chars" : null),
        _buildTextField("Confirm Password", _confirmPassCtrl,
            obscure: true,
            validator: (v) =>
                v != _passCtrl.text ? "Passwords do not match" : null),
      ]
    ]);
  }

  Widget _buildStep3NextOfKin() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_shouldShow("NextOfKin")) ...[
        const Text("Next of Kin",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 10),
        _buildTextField("Full Name", _nokNameCtrl, validator: (v) {
          if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
          return (v == null || v.isEmpty) ? "Full Name is required" : null;
        }),
        _buildTextField("Relationship (Optional)", _nokRelCtrl,
            validator: (_) => null),
        _buildPhoneNumberField(
          label: "Mobile",
          controller: _nokPhoneCtrl,
          selectedCountry: _selectedNokCountry,
          onCountryChanged: (country) =>
              setState(() => _selectedNokCountry = country),
          validator: (v) => _validatePhoneNumber(
            v,
            label: 'Mobile',
            optional: _nokList.isNotEmpty,
          ),
        ),
        _buildTextField("Email (Optional)", _nokEmailCtrl,
            keyboardType: TextInputType.emailAddress, validator: (_) => null),
        _buildTextField("Address (Optional)", _nokAddressCtrl,
            validator: (_) => null),
        Align(
          alignment: Alignment.centerRight,
          child: GradientButton(
              text: "Add NoK",
              onPressed: () {
                final name = _nokNameCtrl.text.trim();
                final rel = _nokRelCtrl.text.trim();
                final mobile =
                    _buildFullPhoneNumber(_nokPhoneCtrl, _selectedNokCountry);
                final email = _nokEmailCtrl.text.trim();
                final address = _nokAddressCtrl.text.trim();

                if (name.isEmpty || mobile.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          "Please fill in Full Name and Mobile (required fields)."),
                      backgroundColor: Colors.redAccent));
                  return;
                }

                if (_validatePhoneNumber(_nokPhoneCtrl.text, label: 'Mobile') !=
                    null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please enter a valid mobile number."),
                      backgroundColor: Colors.redAccent));
                  return;
                }

                if (email.isNotEmpty) {
                  final emailRegex =
                      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Please enter a valid email address."),
                        backgroundColor: Colors.redAccent));
                    return;
                  }
                }

                setState(() {
                  _nokList.add({
                    "fullName": name,
                    "relationship": rel.isEmpty ? "N/A" : rel,
                    "mobileNumber": mobile,
                    "email": email.isEmpty ? "N/A" : email,
                    "address": address.isEmpty ? "N/A" : address,
                  });
                  _nokNameCtrl.clear();
                  _nokRelCtrl.clear();
                  _nokPhoneCtrl.clear();
                  _selectedNokCountry = _dialCountries.first;
                  _nokEmailCtrl.clear();
                  _nokAddressCtrl.clear();
                });
              }),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _nokList.map((nok) {
            return Chip(
              label: Text(nok['fullName']),
              backgroundColor: Colors.blueAccent,
              deleteIcon:
                  const Icon(Icons.close, size: 18, color: Colors.white),
              onDeleted: () => setState(() => _nokList.remove(nok)),
            );
          }).toList(),
        ),
      ],
    ]);
  }

  Widget _buildStep4Documents() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Required Documents",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      if (_requiredDocs.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text("No documents required yet. Add them above.",
                style: TextStyle(color: Colors.white54)),
          ),
        ),
      ..._requiredDocs.map((docName) {
        bool isUploaded = _uploadedDocs.containsKey(docName) ||
            _resubmittedDocs.contains(docName);
        bool isUpdating = _updatingDocName == docName;
        final actionLabel = isUploaded ? "Update" : "Add";
        File? file = _uploadedDocs[docName];
        bool isImage = file != null &&
            (file.path.toLowerCase().endsWith('.jpg') ||
                file.path.toLowerCase().endsWith('.jpeg') ||
                file.path.toLowerCase().endsWith('.png'));

        return Card(
          color: Colors.white.withValues(alpha: 0.1),
          child: ListTile(
            title: Text(docName, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
                _resubmittedDocs.contains(docName)
                    ? "Updated"
                    : isUploaded
                        ? "Ready to submit"
                        : "Required",
                style: TextStyle(
                    color: isUploaded ? Colors.greenAccent : Colors.redAccent)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUploaded)
                  GestureDetector(
                    onTap: isImage ? () => _showImagePreview(file) : null,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isImage
                            ? Image.file(file, fit: BoxFit.cover)
                            : const Icon(Icons.picture_as_pdf,
                                color: Colors.redAccent, size: 24),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: isUpdating
                      ? null
                      : () => _updateRequiredDocument(docName),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF3E5BFF),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          actionLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
            onTap: isUploaded && isImage
                ? () => _showImagePreview(file)
                : () => _updateRequiredDocument(docName),
          ),
        );
      }),
    ]);
  }

  void _showAddDocModal() {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1F2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final filtered = _allAvailableDocTypes
              .where((doc) =>
                  doc.toLowerCase().contains(searchQuery.toLowerCase()) &&
                  !_requiredDocs.contains(doc))
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add Required Document",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setModalState(() => searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Search document...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 15),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      return ListTile(
                        title: Text(doc,
                            style: const TextStyle(color: Colors.white)),
                        trailing:
                            const Icon(Icons.add, color: Colors.blueAccent),
                        onTap: () {
                          setState(() => _requiredDocs.add(doc));
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                if (searchQuery.isNotEmpty && !filtered.contains(searchQuery))
                  ListTile(
                    title: Text("Add '$searchQuery'...",
                        style: const TextStyle(color: Colors.blueAccent)),
                    leading: const Icon(Icons.create, color: Colors.blueAccent),
                    onTap: () {
                      setState(() => _requiredDocs.add(searchQuery));
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildPhoneNumberField({
    required String label,
    required TextEditingController controller,
    required _DialCountry selectedCountry,
    required ValueChanged<_DialCountry> onCountryChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 56,
                child: Material(
                  color: const Color(0xFF233565),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showCountryPicker(
                      selectedCountry: selectedCountry,
                      onSelected: onCountryChanged,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF5B86FF), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selectedCountry.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    validator: validator ??
                        (v) => _validatePhoneNumber(v, label: label),
                    decoration: InputDecoration(
                      hintText: "Phone number",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF6A4DE8), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCountryPicker({
    required _DialCountry selectedCountry,
    required ValueChanged<_DialCountry> onSelected,
  }) {
    String query = '';

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1A31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCountries = _dialCountries.where((country) {
              final normalizedQuery = query.toLowerCase().trim();
              if (normalizedQuery.isEmpty) return true;
              return country.name.toLowerCase().contains(normalizedQuery) ||
                  country.code.contains(normalizedQuery);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.62,
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) =>
                            setModalState(() => query = value),
                        decoration: InputDecoration(
                          hintText: "Search country...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF111D35),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF5B86FF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredCountries.length,
                          itemBuilder: (context, index) {
                            final country = filteredCountries[index];
                            final isSelected =
                                country.name == selectedCountry.name &&
                                    country.code == selectedCountry.code;

                            return InkWell(
                              onTap: () {
                                onSelected(country);
                                Navigator.of(sheetContext).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF3368F5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(country.flag,
                                        style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            country.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            "Dial code ${country.code}",
                                            style: const TextStyle(
                                                color: Colors.white60),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      country.code,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    Function(String)? onFieldSubmitted,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        readOnly: readOnly,
        focusNode: focusNode,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        validator: validator ??
            (v) => (v == null || v.isEmpty) ? "$label is required" : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor:
              readOnly ? Colors.white10 : Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: suffixIcon,
          helperText:
              (readOnly && ctrl.text.isNotEmpty) ? "Verified Bank" : null,
          helperStyle: const TextStyle(color: Colors.greenAccent),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        style: const TextStyle(color: Colors.white60),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value,
      Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white38)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text("Select $label",
              style: const TextStyle(color: Colors.white70)),
          dropdownColor: Colors.grey[900],
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          onChanged: onChanged,
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white))))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.white),
        validator: validator ??
            (v) => (v == null || v.isEmpty) ? "$label is required" : null,
        onTap: () => _selectDob(context),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  void _showImagePreview(File file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.file(file),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorWithRetry(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2F45),
        title: const Text("Submission Error",
            style: TextStyle(color: Colors.white)),
        content: Text("Failed to submit: $error",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitForm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text("Retry", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
