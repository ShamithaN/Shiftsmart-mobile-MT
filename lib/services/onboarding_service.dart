import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'api_client.dart';

class OnboardingService {
  final ApiClient _apiClient = ApiClient();
  
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';
  final String fetchInviteKey = dotenv.env['FETCH_INVITE_KEY'] ?? '';
  final String onboardingKey = dotenv.env['SUBMIT_ONBOARD_KEY'] ?? '';
  final String empResubmitKey = dotenv.env['RESUBMIT_KEY'] ?? '';
  final String resubmitDocKey = dotenv.env['DOCUMENT_RESUBMIT_KEY'] ?? '';

  // Step A: Fetch Invitation
  Future<Map<String, dynamic>?> fetchInvitation(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    String url = '$baseUrl/employee/invitation/$encodedEmail';
    if (fetchInviteKey.isNotEmpty) {
      url += '?code=$fetchInviteKey';
    }

    try {
      print(" Fetching Invitation: $url");
      // Use ApiClient to ensure headers (like Bearer token) are sent if available
      final response = await _apiClient.get(url, useAuth: true);

      print(" Fetch Status: ${response.statusCode}");
      print(" Fetch Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print(" Fetch failed. Status: ${response.statusCode}. Body: ${response.body}");
      }
      return null;
    } catch (e) {
      print(" Fetch Error: $e");
      return null;
    }
  }

  // Step B: Submit Form
  Future<http.Response> submitOnboardingForm({
    required File profilePicture,
    required Map<String, File> uploadedCertificates,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> nextOfKins,
    required String password,
    bool isResubmission = false,
  }) async {
    String url;

    // 1. DETERMINE URL
    if (isResubmission) {
      url = '$baseUrl/employee/resubmit';
      if (empResubmitKey.isNotEmpty) {
        url += '?code=$empResubmitKey';
      }
    } else {
      url = '$baseUrl/employee/onboarding-complete';
      if (onboardingKey.isNotEmpty) {
        url += '?code=$onboardingKey';
      }
    }

    print(" Submitting Multipart Request to: $url");
    print(
        " Mode: ${isResubmission ? 'RESUBMISSION (Partial)' : 'NEW ONBOARDING (Full)'}");

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // 2. AUTH TOKEN  read from FlutterSecureStorage (same place auth_service.dart writes it)
      const storage = FlutterSecureStorage();
      final String? token = await storage.read(key: 'appToken');

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        print(
            " Warning: No Auth Token found. Proceeding without it (as allowed by backend).");
      }

      // 3. ADD DATA FIELDS
      request.fields['profile'] = jsonEncode(profile);

      // Add 'employeeId' as a standalone field
      var empId = profile['employeeId'];
      if (empId != null) {
        request.fields['employeeId'] = empId.toString();
      }

      if (!isResubmission) {
        request.fields['nextOfKins'] = jsonEncode(nextOfKins);
        request.fields['password'] = password;
      }

      // 4. ADD PROFILE PICTURE
      if (profilePicture.existsSync()) {
        final mimeType = lookupMimeType(profilePicture.path) ?? 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'profilePicture',
          profilePicture.path,
          contentType: MediaType.parse(mimeType),
        ));
      }

      // 5. ADD DOCUMENTS
      for (var entry in uploadedCertificates.entries) {
        if (entry.value.existsSync()) {
          final mimeType =
              lookupMimeType(entry.value.path) ?? 'application/pdf';

          print(" Attaching File: ${entry.key}");

          request.files.add(await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      // 6. SEND REQUEST
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(" Submit Status: ${response.statusCode}");
      print(" Submit Body: ${response.body}");

      return response;
    } catch (e) {
      print(" Submit Error: $e");
      return http.Response('Error: $e', 500);
    }
  }

  Future<String?> resubmitDocument({
    required int documentId,
    required File file,
    required String documentType,
  }) async {
    String url = '$baseUrl/document/resubmit';
    if (resubmitDocKey.isNotEmpty) {
      url += '?code=$resubmitDocKey';
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));

      final token = await _apiClient.getAppToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['DocumentId'] = documentId.toString();
      request.fields['DocumentType'] = documentType;

      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }

      return 'Document update failed: ${response.statusCode}. ${response.body}';
    } catch (e) {
      return 'Document update error: $e';
    }
  }
}
