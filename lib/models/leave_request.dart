import 'package:shiftsmart/utils/date_time_parser.dart';

class LeaveRequest {
  final int leaveRequestId;
  final int employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  String status;
  final DateTime requestedAt;

  LeaveRequest({
    required this.leaveRequestId,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.requestedAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is num) return val.toInt();
      return 0;
    }

    return LeaveRequest(
      leaveRequestId: parseId(json['LeaveRequestId'] ??
          json['leaveRequestId'] ??
          json['leave_request_id'] ??
          json['id'] ??
          json['Id']),
      employeeId: parseId(json['EmployeeId'] ??
          json['employeeId'] ??
          json['employee_id'] ??
          json['userId'] ??
          json['UserId']),
      leaveType:
          json['LeaveType'] ?? json['leaveType'] ?? json['leave_type'] ?? '',
      startDate: parseServerDateTime(json['StartDate']?.toString() ??
              json['startDate']?.toString() ??
              json['start_date']?.toString() ??
              '') ??
          DateTime.now(),
      endDate: parseServerDateTime(json['EndDate']?.toString() ??
              json['endDate']?.toString() ??
              json['end_date']?.toString() ??
              '') ??
          DateTime.now(),
      reason: json['Reason'] ?? json['reason'] ?? '',
      status: json['Status'] ?? json['status'] ?? 'Pending',
      requestedAt: parseServerDateTime(json['RequestedAt']?.toString() ??
              json['requestedAt']?.toString() ??
              json['requested_at']?.toString() ??
              '') ??
          DateTime.now(),
    );
  }
  bool get isPending {
    return status.toLowerCase() == 'pending';
  }

  bool get isAcceptedOrRejected {
    return status.toLowerCase() == 'approved' ||
        status.toLowerCase() == 'rejected' ||
        status.toLowerCase() == 'denied';
  }
}
