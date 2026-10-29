import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/services/company_service.dart';
import 'package:shiftsmart/services/project_service.dart';
import 'package:shiftsmart/widgets/custom_date_picker.dart';
import 'package:shiftsmart/models/company.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradient_button.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/models/project.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';

class Managercreateproject2 extends StatefulWidget {
  final String name;
  final String description;
  final String additionalRemark;
  final String projectDue;
  final Project? project;

  const Managercreateproject2({
    super.key,
    required this.name,
    required this.description,
    required this.additionalRemark,
    required this.projectDue,
    this.project,
  });

  @override
  State<Managercreateproject2> createState() => _Managercreateproject2State();
}

class _Managercreateproject2State extends State<Managercreateproject2> {
  // Controllers
  final TextEditingController _startdateController = TextEditingController();
  final TextEditingController _enddateController = TextEditingController();
  final TextEditingController _comController = TextEditingController();

  // Data
  List<Company> allCom = [];
  int? _selectedComId; // Track ID instead of Name String
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    fetchCompanies().then((_) {
      if (widget.project != null) {
        _startdateController.text = widget.project!.startDate;
        _enddateController.text = widget.project!.endDate;

        // Find the company ID that matches the company name
        final existingCom = allCom
            .where((c) => c.name == widget.project!.companyName)
            .firstOrNull;
        if (existingCom != null) {
          setState(() {
            _selectedComId = existingCom.id;
          });
        }
      }
    });
  }

  // --- Fetch Companies ---
  Future<void> fetchCompanies() async {
    try {
      final companies = await CompanyService().fetchCompanies();
      if (mounted) {
        setState(() {
          allCom = companies;
        });
      }
    } catch (e) {
      debugPrint("Error fetching companies: $e");
    }
  }

  // --- Date Picker Logic ---
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: datePickerThemeBuilder);
    if (pickedDate != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
      setState(() => controller.text = formattedDate);
    }
  }

  // --- Submit Logic ---
  Future<void> _submitProjectData() async {
    // 1. Validation
    if (_startdateController.text.isEmpty ||
        _enddateController.text.isEmpty ||
        _selectedComId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final projectData = {
      "Name": widget.name, // Capitalized Keys
      "CompanyId": _selectedComId, // Capitalized Keys
      "Description": widget.description,
      "AdditionalRemarks": widget.additionalRemark,
      "ProjectDue": "${widget.projectDue}T00:00:00Z", // Added Z
      "StartDate": "${_startdateController.text.trim()}T00:00:00Z", // Added Z
      "EndDate": "${_enddateController.text.trim()}T00:00:00Z", // Added Z
    };

    bool success;

    // 2. API Call
    if (widget.project != null) {
      success = await ProjectService()
          .updateProject(widget.project!.projectId, projectData);
    } else {
      success = await ProjectService().addProject(projectData);
    }

    setState(() => _isLoading = false);

    // 3. Success Handling
    if (mounted) {
      if (success) {
        SuccessDialog.show(
          context,
          title: widget.project != null ? "Project Updated" : "Project Created",
          message: widget.project != null
              ? "Project details have been successfully updated."
              : "New project has been created successfully.",
          buttonText: "Ok",
          onPressed: () {
            // Because you came from Step 1, we just need to pop backward twice.
            // This preserves the state of the BottomNavbar, keeping you exactly on the "PROJECTS" tab!
            int count = 0;
            Navigator.of(context).popUntil((route) {
              return count++ >= 2;
            });
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit project")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidenav(),
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(
        showBackButton: true,
      ),
      body: Stack(
        children: [
          const Background(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Gradienthorizontal(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20.0),
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            widget.project != null
                                ? "UPDATE PROJECT (Step 2/2)"
                                : "CREATE PROJECT (Step 2/2)",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form Fields
                        _buildDateField("Start Date", _startdateController),
                        const SizedBox(height: 10),
                        _buildDateField("End Date", _enddateController),
                        const SizedBox(height: 10),
                        _buildDropdownCompany(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GradientButton(
                            text: "Back",
                            onPressed: () => Navigator.pop(context),
                            isCancel: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GradientButton(
                            text: widget.project != null ? "Update" : "Create",
                            onPressed: _submitProjectData,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- UI Helper: Date Field ---
  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_month_outlined,
                    color: Colors.white70, size: 20),
                onPressed: () => _selectDate(context, controller),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Company Dropdown ---
  Widget _buildDropdownCompany() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Company",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              // Change String to int
              dropdownColor: const Color(0xFF2A3243),
              value: _selectedComId,
              isExpanded: true,
              items: allCom.map((company) {
                return DropdownMenuItem<int>(
                  // Change String to int
                  value: company.id, // Value is now the ID
                  child: Text(
                    company.name, // Display text is still the Name
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedComId = value; // Update ID
                });
              },
              hint: const Text(
                "Choose a Company",
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
