import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/pattern_app_bar.dart';

class RequestClassPage extends StatefulWidget {
  const RequestClassPage({super.key});

  @override
  _RequestClassPageState createState() => _RequestClassPageState();
}

class _RequestClassPageState extends State<RequestClassPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Set<DateTime> _selectedDays = {};
  DateTime _focusedDay = DateTime.now();
  late final DateTime _today;

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void initState() {
    super.initState();
    _today = _normalizeDate(DateTime.now());
  }

  Future<void> _submitRequest() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty || _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields and select at least one date.")),
      );
      return;
    }

    await db.collection("requestedEvents").add({
      "title": _titleController.text.trim(),
      "description": _descriptionController.text.trim(),
      "availableDays": _selectedDays.map((date) => Timestamp.fromDate(date)).toList(),
      "timestamp": FieldValue.serverTimestamp(),
    });

    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _selectedDays.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Class request submitted!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: const PatternAppBar(title: 'Request a Class'),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Class Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLength: 500,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(
                  labelText: "Brief Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Calendar for Selecting Available Days
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : const Color.fromARGB(255, 245, 240, 250),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  selectedDayPredicate: (day) => _selectedDays.contains(day),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!selectedDay.isBefore(_today)) {
                      setState(() {
                        if (_selectedDays.contains(selectedDay)) {
                          _selectedDays.remove(selectedDay);
                        } else {
                          _selectedDays.add(selectedDay);
                        }
                        _focusedDay = focusedDay;
                      });
                    } else {
                      Future.delayed(Duration.zero, () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please select today or a future date.")),
                        );
                      });
                    }
                  },
                  enabledDayPredicate: (day) => !day.isBefore(_today),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
                    rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
                    headerPadding: EdgeInsets.all(0),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: const BoxDecoration(
                      color: Color.fromARGB(255, 69, 148, 214),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Color.fromARGB(255, 69, 148, 214),
                      shape: BoxShape.circle,
                    ),
                    disabledTextStyle: TextStyle(color: textColor.withOpacity(0.3)),
                    weekendTextStyle: TextStyle(color: textColor),
                    defaultTextStyle: TextStyle(color: textColor),
                  ),
                  rowHeight: 40,
                ),
              ),

              const SizedBox(height: 5),

              // Display Selected Days
              if (_selectedDays.isNotEmpty)
                const SizedBox(height: 0),
                SizedBox(
                  height: 140,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Wrap(
                      spacing: 8.0,
                      children: _selectedDays.map((day) {
                        return SizedBox(
                          width: 115,
                          child: Chip(
                            label: Text(DateFormat.MMMd().format(day)),
                            deleteIcon: Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedDays.remove(day);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

              // Submit Button
              Center(
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  child: const Text("Submit Request"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}