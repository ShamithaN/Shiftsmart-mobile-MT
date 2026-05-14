import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/models/empcert_model.dart';
import 'package:shiftsmart/services/employee_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/emp_slidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';


class Employeecert extends StatefulWidget {
  const Employeecert({super.key});

  @override
  State<Employeecert> createState() => _EmployeecertState();
}

class _EmployeecertState extends State<Employeecert> {
  List<EmployeeCertificate> _certificates = [];
  bool _isLoading = true;
  int? _employeeId;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _employeeId = prefs.getInt('employeeId') ?? prefs.getInt('userId');

      if (_employeeId != null) {
        final docs = await EmployeeService().fetchEmployeeDocuments(_employeeId!);
        setState(() {
          _certificates = docs;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint(" No Employee ID found in SharedPreferences");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading docs: $e")),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        return Colors.greenAccent;
      case 'pending':
        return Colors.orangeAccent;
      case 'rejected':
      case 'declined':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  Future<void> _viewDocument(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Document URL is missing")),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open document")),
        );
      }
    }
  }

  Future<void> _deleteDocument(EmployeeCertificate doc) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2230),
        title: const Text("Delete Document", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete ${doc.fileName}?", 
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && doc.documentId != null) {
      setState(() => _isLoading = true);
      final bool success = await EmployeeService().deleteCertificate(doc.documentId!);
      if (success) {
        _loadDocuments();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete document")),
          );
        }
      }
    }
  }

  Future<void> _showAddUpdateDialog({EmployeeCertificate? existingDoc}) async {
    File? selectedFile;
    String? fileName;
    String documentType = existingDoc?.documentType ?? 'General';
    final List<String> docTypes = [
      'General',
      'National ID',
      'National Police Check',
      'Working with Children Check',
      'Drivers License',
      'Passport',
      'CV',
      'Contract'
    ];

    // Ensure the current documentType is in the list to avoid DropdownButton assertion error
    if (!docTypes.contains(documentType)) {
      docTypes.add(documentType);
    }

    bool isUploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1C2230),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existingDoc == null ? "Add Document" : "Update Document",
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Document Type Dropdown
              const Text("Document Type", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButton<String>(
                  value: documentType,
                  dropdownColor: const Color(0xFF2A3240),
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  items: docTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => documentType = val);
                  },
                ),
              ),
              const SizedBox(height: 20),
              // File Picker
              const Text("File", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1C2230),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            "Select Attachment Method",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: Color(0xFF3498DB)),
                            title: const Text("Take Photo", style: TextStyle(color: Colors.white)),
                            onTap: () async {
                              Navigator.pop(context);
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 80,
                              );
                              if (image != null) {
                                setModalState(() {
                                  selectedFile = File(image.path);
                                  fileName = path.basename(selectedFile!.path);
                                });
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.upload_file, color: Color(0xFF3498DB)),
                            title: const Text("Select File", style: TextStyle(color: Colors.white)),
                            onTap: () async {
                              Navigator.pop(context);
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                              );
                              if (result != null && result.files.single.path != null) {
                                setModalState(() {
                                  selectedFile = File(result.files.single.path!);
                                  fileName = path.basename(selectedFile!.path);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                },

                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10, style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file, color: Color(0xFF3498DB)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName ?? (existingDoc != null ? "Change current file..." : "Select file..."),
                          style: TextStyle(color: fileName != null ? Colors.white : Colors.white38),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Action Button
              ElevatedButton(
                onPressed: isUploading || (_employeeId == null) || (selectedFile == null && existingDoc == null)
                    ? null
                    : () async {
                        setModalState(() => isUploading = true);
                        final error = await EmployeeService().uploadCertificate(
                          file: selectedFile!,
                          employeeId: _employeeId!,
                          certificateType: documentType,
                          documentId: existingDoc?.documentId,
                        );
                        if (error == null) {
                          Navigator.pop(context);
                          _loadDocuments();
                        } else {
                          setModalState(() => isUploading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isUploading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(existingDoc == null ? "ADD DOCUMENT" : "UPDATE DOCUMENT"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const EmpSidenav(currentScreen: 'EmployeeCert'),
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(showBackButton: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUpdateDialog(),
        backgroundColor: const Color(0xFF3498DB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(children: [
        const Background(),
        Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "MY DOCUMENTS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Manage your onboarding documents",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _buildDocList(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ])
      ]),
    );
  }

  Widget _buildDocList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 50.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_certificates.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 30),
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: const [
            Icon(Icons.folder_off_outlined, size: 40, color: Colors.white38),
            SizedBox(height: 10),
            Text("No documents found.",
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return Column(
      children: _certificates.map((doc) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A3240), Color(0xFF1C2230)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.article_rounded,
                      color: Color(0xFF3498DB),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name & Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doc.status,
                          style: TextStyle(
                            color: _getStatusColor(doc.status),
                            fontSize: 11,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _viewDocument(doc.documentUrl),
                    child: const Text("VIEW", style: TextStyle(color: Color(0xFF3498DB), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => _showAddUpdateDialog(existingDoc: doc),
                    child: const Text("UPDATE", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (doc.documentType.toLowerCase() == 'general')
                    TextButton(
                      onPressed: () => _deleteDocument(doc),
                      child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),

                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
