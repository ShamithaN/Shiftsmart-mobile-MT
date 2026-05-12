// import 'dart:io';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:path/path.dart' as path;
// import 'package:url_launcher/url_launcher.dart';
// import 'package:shiftsmart/models/empcert_model.dart';
// import 'package:shiftsmart/services/onboarding_service.dart';

// class EmployeeDocumentDetail extends StatefulWidget {
//   final EmployeeCertificate document;

//   const EmployeeDocumentDetail({super.key, required this.document});

//   @override
//   State<EmployeeDocumentDetail> createState() => _EmployeeDocumentDetailState();
// }

// class _EmployeeDocumentDetailState extends State<EmployeeDocumentDetail> {
//   File? _selectedFile;
//   String? _selectedFileName;
//   bool _isSubmitting = false;

//   Future<void> _pickFile() async {
//     final result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
//     );

//     if (result != null && result.files.single.path != null) {
//       setState(() {
//         _selectedFile = File(result.files.single.path!);
//         _selectedFileName = path.basename(_selectedFile!.path);
//       });
//     }
//   }

//   Future<void> _submitUpdate() async {
//     if (_selectedFile == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a file to update.')),
//       );
//       return;
//     }

//     setState(() => _isSubmitting = true);

//     final int documentId = widget.document.documentId ?? 0;
//     final String documentType = widget.document.documentType;

//     final String? error = await OnboardingService().resubmitDocument(
//       documentId: documentId,
//       file: _selectedFile!,
//       documentType: documentType,
//     );

//     if (mounted) {
//       setState(() => _isSubmitting = false);

//       if (error == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Document update submitted successfully.')),
//         );
//         Navigator.of(context).pop(true);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(error)),
//         );
//       }
//     }
//   }

//   Future<void> _openDocument() async {
//     final url = widget.document.documentUrl;
//     if (url.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Document URL is missing.')),
//       );
//       return;
//     }

//     final uri = Uri.parse(url);
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri, mode: LaunchMode.externalApplication);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Cannot open document.')),
//       );
//     }
//   }

//   String get _formattedUploadedAt {
//     try {
//       final date = DateTime.parse(widget.document.uploadedAt);
//       return DateFormat.yMMMMd().format(date);
//     } catch (_) {
//       return widget.document.uploadedAt;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Document Details'),
//         backgroundColor: const Color(0xFF1C2230),
//       ),
//       backgroundColor: const Color(0xFF121826),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const SizedBox(height: 8),
//               _buildDetailCard(),
//               const SizedBox(height: 20),
//               _buildActionSection(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailCard() {
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: const Color(0xFF252F3F),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white10),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             widget.document.fileName,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 10),
//           _buildInfoRow('Type', widget.document.documentType),
//           _buildInfoRow('Status', widget.document.status),
//           _buildInfoRow('Uploaded', _formattedUploadedAt),
//           if (widget.document.remarks != null && widget.document.remarks!.isNotEmpty)
//             _buildInfoRow('Remarks', widget.document.remarks!),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF3498DB),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   onPressed: _openDocument,
//                   child: const Text('Open Document'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionSection() {
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: const Color(0xFF252F3F),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white10),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Update Document',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           ElevatedButton.icon(
//             icon: const Icon(Icons.upload_file),
//             label: const Text('Select New File'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF2F80ED),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             onPressed: _pickFile,
//           ),
//           if (_selectedFileName != null) ...[
//             const SizedBox(height: 12),
//             Text(
//               'Selected file: $_selectedFileName',
//               style: const TextStyle(color: Colors.white70),
//             ),
//           ],
//           const SizedBox(height: 18),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: _isSubmitting ? null : _submitUpdate,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF27AE60),
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//               child: _isSubmitting
//                   ? const SizedBox(
//                       height: 20,
//                       width: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : const Text('Submit Update'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             '$label:',
//             style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(width: 6),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(color: Colors.white60),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
