import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:craft_stash/screens/request_class_page.dart';
import 'package:craft_stash/widgets/pattern_app_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _isWeeklyView = false;
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};

  String _selectedFilter = "All";
  final List<String> _filterOptions = ["All", "Free", "Paid"];

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    final coll = await db.collection('events').get();
    for (var event in coll.docs) {
      final data = event.data();
      final eventDate = (data['date'] as Timestamp).toDate();
      final title = data['title'] as String;
      _events.putIfAbsent(_normalizeDate(eventDate), () => []).add({
        'title': title,
        'description': data['description'],
        'price': data['price'],
        'time': eventDate,
        'link': data['link'],
      });
    }
    setState(() {});
  }

  List<MapEntry<DateTime, List<Map<String, dynamic>>>> _getUpcomingEvents() {
    DateTime today = _normalizeDate(DateTime.now().subtract(const Duration(days: 1)));
    DateTime threeWeeksLater = today.add(const Duration(days: 31));

    List<MapEntry<DateTime, List<Map<String, dynamic>>>> filteredEvents;

    filteredEvents = _events.entries
        .where((entry) => entry.key.isAfter(today) && entry.key.isBefore(threeWeeksLater))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (_selectedFilter == "Free") {
      filteredEvents = filteredEvents
          .where((entry) => entry.value.any((event) => event['price'] == 0))
          .toList();
    } else if (_selectedFilter == "Paid") {
      filteredEvents = filteredEvents
          .where((entry) => entry.value.any((event) => event['price'] > 0))
          .toList();
    }

    return filteredEvents;
  }

  void _showEventDetails(Map<String, dynamic> event, DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (DateTime.now().compareTo(date) > 0)
              Column(
                children: [
                  Text("This event has already passed",
                    style: TextStyle(color: Colors.red, fontSize: 16, background: Paint()..color = Colors.yellow),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            Text("Date: ${date.month}/${date.day}/${date.year}"),
            Text("Time: ${DateFormat.jm().format(event['time'])}"),
            Text(event['price'] == 0 ? "Price: Free" : "Price: \$${event['price']}"),
            const SizedBox(height: 10),
            Text("Description: \n${event['description']}"),
            const SizedBox(height: 10),
            if (event['link'] != null && event['link'].isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse(event['link']);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Could not open link"))
                    );
                  }
                },
                icon: const Icon(Icons.open_in_browser, color: Color.fromARGB(255, 69, 148, 214)),
                label: const Text("Purchase Tickets"),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final surfaceColor = theme.colorScheme.surfaceContainerHighest;

    final List<MapEntry<DateTime, List<Map<String, dynamic>>>> upcomingEvents = _getUpcomingEvents();

    return Scaffold(
      appBar: PatternAppBar(
        title: 'Calendar',
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list),
          onSelected: (value) {
            setState(() {
              _selectedFilter = value;
            });
          },
          itemBuilder: (context) {
            return _filterOptions
                .map((option) => PopupMenuItem(value: option, child: Text(option)))
                .toList();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              setState(() {
                _isWeeklyView = !_isWeeklyView;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(1.0),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : const Color.fromARGB(255, 245, 240, 250),
            ),
            child: TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime.now().subtract(const Duration(days: 90)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              calendarFormat: _isWeeklyView ? CalendarFormat.week : CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
                CalendarFormat.week: 'Week',
              },
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                selectedDay = _normalizeDate(selectedDay);
                setState(() {
                  if (_events.containsKey(selectedDay)) {
                    final event = _events[selectedDay]!.first;
                    _showEventDetails(event, selectedDay);
                  }
                });
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: isDark
                      ? Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.5), Colors.black)
                      : theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                defaultTextStyle: TextStyle(color: textColor, fontSize: 14),
                outsideTextStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 14),
                weekendTextStyle: TextStyle(color: textColor, fontSize: 14),
                cellMargin: const EdgeInsets.all(3),
              ),
              rowHeight: 45,
              eventLoader: (day) {
                DateTime normalizedDay = _normalizeDate(day);
                return _events[normalizedDay] ?? [];
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      right: 23,
                      bottom: 5,
                      child: Container(
                        width: 10,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Upcoming Events",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: upcomingEvents.isEmpty
                ? Center(child: Text("No upcoming events.", style: TextStyle(color: textColor)))
                : ListView.builder(
                    itemCount: upcomingEvents.fold<int>(0, (count, entry) => count + entry.value.length),
                    itemBuilder: (context, index) {
                      int eventIndex = 0;
                      for (var entry in upcomingEvents) {
                        if (index < eventIndex + entry.value.length) {
                          final event = entry.value[index - eventIndex];
                          return Card(
                            color: surfaceColor,
                            child: ListTile(
                              title: Text(event['title'], style: TextStyle(color: textColor)),
                              subtitle: Text(
                                "${entry.key.month}/${entry.key.day}/${entry.key.year}",
                                style: TextStyle(color: textColor.withOpacity(0.7)),
                              ),
                              trailing: Text(event['price'] == 0 ? "Free" : "\$${event['price']}", style: TextStyle(color: textColor)),
                              onTap: () => _showEventDetails(event, entry.key),
                            ),
                          );
                        }
                        eventIndex += entry.value.length;
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 10),
              child: Column(
                children: [
                  Text("Not interested in these events?", style: TextStyle(color: textColor)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    onPressed: () {
                      FocusScope.of(context).requestFocus(FocusNode());
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RequestClassPage()),
                      );
                    },
                    child: const Text("Request Class"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}