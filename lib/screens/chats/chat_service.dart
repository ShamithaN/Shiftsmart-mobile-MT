import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shiftsmart/models/chat_list_item.dart';
import 'package:shiftsmart/models/message.dart';
import 'package:shiftsmart/models/search_employee.dart';
import 'package:shiftsmart/models/employee.dart';
import 'package:shiftsmart/services/api_client.dart';
import 'package:shiftsmart/services/employee_service.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient();

  // Standard Base URL
  final String baseUrl = dotenv.env['BASE_URL']!;

  //  SPECIAL URL FOR MESSAGES (From your Master List & .env)
  // If MESSAGE_BASE_URL is missing in .env, fallback to baseUrl
  String get messageBaseUrl =>
      dotenv.env['MESSAGE_BASE_URL'] ?? baseUrl;

  // Keys
  String get searchEmpKey => dotenv.env['CHAT_SEARCH_EMPLOYEES_KEY'] ?? '';
  String get partiKey => dotenv.env['CHAT_GET_BY_EMPLOYEE_KEY'] ?? '';
  String get fetchMsgKey => dotenv.env['CHAT_GET_MESSAGES_KEY'] ?? '';
  String get sendMsgKey => dotenv.env['CHAT_SEND_MESSAGE_KEY'] ?? '';
  String get createChatKey => dotenv.env['CHAT_CREATE_KEY'] ?? '';
  String get chatAllKey => dotenv.env['CHAT_GET_ALL_KEY'] ?? '';

  // --- 1. FETCH CHAT LIST ---
  Future<List<ChatListItem>> fetchChatList() async {
    final url = '$messageBaseUrl/chat/all?code=$chatAllKey';
    debugPrint(" Fetching Chat List"); // Log added

    try {
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => ChatListItem.fromJson(item)).toList();
      }
      debugPrint(" Chat List Error: ${response.statusCode}");
      return [];
    } catch (e) {
      debugPrint(" Error fetching chats: $e");
      return [];
    }
  }

  // --- 2. SEARCH EMPLOYEES ---
  Future<List<SearchEmployee>> searchEmployees(String query) async {
    // If query is empty, show all active employees by default
    if (query.isEmpty) {
      debugPrint(" ChatService: Query empty, fetching all active employees as default list.");
      final employeeService = EmployeeService();
      final employees = await employeeService.fetchAllEmployees(includeAdminsAndManagers: true);
      
      return employees.map((e) => SearchEmployee(
        employeeId: e.employeeId,
        firstName: e.firstName,
        lastName: e.lastName ?? "",
        email: e.email,
        profilePicture: e.profilePicture,
        role: e.userRole ?? "Employee",
      )).toList();
    }

    final encodedQuery = Uri.encodeComponent(query);
    // Updated endpoint back to /chat/search as /chat/employees was likely incorrect
    final url = '$messageBaseUrl/chat/search?query=$encodedQuery&code=$searchEmpKey';

    debugPrint(" ChatService: Searching employees at $url");

    try {
      final response = await _apiClient.get(url, useAuth: true);
      debugPrint(" ChatService Search Status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint(" ChatService: Found ${data.length} employees.");
        return data.map((e) => SearchEmployee.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint(" Error searching employees: $e");
      return [];
    }
  }

  // --- 3. FETCH MESSAGES (FIXED URL & LOGS) ---
  Future<List<Message>> fetchMessages(int chatParticipantId) async {
    //  USE THE SPECIAL MESSAGE URL HERE
    final url = '$messageBaseUrl/chat/messages/$chatParticipantId?code=$fetchMsgKey';

    // debugPrint(" Fetching Messages from: $url"); // Uncomment to see full URL if needed

    try {
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((m) => Message.fromJson(m)).toList();
      } else {
        debugPrint(" Message Status: ${response.statusCode}");
        debugPrint(" Failed to load messages. Body: ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint(" Error fetching messages: $e");
      return [];
    }
  }

  // --- 4. SEND MESSAGE (Added Logs) ---
  Future<bool> sendMessage({
    required int chatParticipantId,
    required int senderId,
    required int receiverId,
    required String text,
  }) async {
    final url = '$messageBaseUrl/chat/send/$chatParticipantId?code=$sendMsgKey';

    final body = {
      'SenderId': senderId,
      'ReceiverId': receiverId,
      'Message': text,
    };

    debugPrint(" Sending Message to $url");

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);

      if (response.statusCode == 200) {
        debugPrint(" Message Sent!");
        return true;
      } else {
        debugPrint(" Send Failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint(" Error sending message: $e");
      return false;
    }
  }

  // --- 5. CREATE CHAT ---
  Future<bool> createChat({
    required int senderId,
    required int receiverId,
    required String message,
  }) async {
    final url = '$messageBaseUrl/chat/create?code=$createChatKey';
    final body = {
      'SenderId': senderId,
      'ReceiverId': receiverId,
      'Message': message,
    };
    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      debugPrint(" Create Chat Status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(" Error creating chat: $e");
      return false;
    }
  }
}
