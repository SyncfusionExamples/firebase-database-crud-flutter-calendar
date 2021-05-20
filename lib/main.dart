// @dart=2.9
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

void main() => runApp(LoadDataFromFireBase());

class LoadDataFromFireBase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FireBase',
      home: LoadDataFromFireStore(),
    );
  }
}

class LoadDataFromFireStore extends StatefulWidget {
  @override
  LoadDataFromFireStoreState createState() => LoadDataFromFireStoreState();
}

class LoadDataFromFireStoreState extends State<LoadDataFromFireStore> {
  DataSnapshot querySnapshot;
  List<Color> _colorCollection;
  Query meetingQuery;
  MeetingDataSource events;
  final List<String> options = <String>['Add', 'Delete', 'Update'];
  var fireBaseInstance = FirebaseDatabase.instance.reference();
  StreamSubscription onMeetingAddedSubscription,
      onMeetingDeletedSubscription,
      onMeetingUpdatedSubscription;

  @override
  void initState() {
    _initializeEventColor();
    meetingQuery = fireBaseInstance
        .child("CalendarAppointmentCollection")
        .orderByChild('Subject');
    getDataFromDatabase().then((results) {
      setState(() {
        if (results != null) {
          querySnapshot = results;
          var collection = <Meeting>[];

          Map<dynamic, dynamic> values = querySnapshot.value;
          List<dynamic> key = values.keys.toList();
          if (values != null) {
            for (int i = 0; i < key.length; i++) {
              var data = values[key[i]];
              final Random random = new Random();
              collection.add(Meeting.map(
                  data, _colorCollection[random.nextInt(9)], key[i]));
            }
          }
          events = _getCalendarDataSource(collection);
        }
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    onMeetingAddedSubscription.cancel();
    onMeetingDeletedSubscription.cancel();
    onMeetingUpdatedSubscription.cancel();
    super.dispose();
  }

  getDataFromDatabase() async {
    var getValue = await meetingQuery.once();
    wireEvents(meetingQuery);
    return getValue;
  }

  bool isInitialLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: PopupMenuButton<String>(
        icon: Icon(Icons.settings),
        itemBuilder: (BuildContext context) => options.map((String choice) {
          return PopupMenuItem<String>(
            value: choice,
            child: Text(choice),
          );
        }).toList(),
        onSelected: (String value) {
          if (value == 'Add') {
            final dbRef =
                fireBaseInstance.child("CalendarAppointmentCollection");
            dbRef.push().set({
              "StartTime": '07/04/2020 07:00:00',
              "EndTime": '07/04/2020 08:00:00',
              "Subject": 'NewMeeting',
            }).then((_) {
              Scaffold.of(context)
                  .showSnackBar(SnackBar(content: Text('Successfully Added')));
            }).catchError((onError) {
              print(onError);
            });
          } else if (value == 'Delete') {
            String key =
                events.appointments[events.appointments.length - 1].key;
            fireBaseInstance
                .child("CalendarAppointmentCollection")
                .child(key)
                .remove();
          } else {
            String key = events.appointments[0].key;
            fireBaseInstance
                .child("CalendarAppointmentCollection")
                .child(key)
                .update({
              'Subject': 'Meetings',
              'StartTime': '07/04/2020 09:00:00',
              'EndTime': '07/04/2020 10:00:00'
            });
          }
        },
      )),
      body: _showCalendar(),
    );
  }

  _showCalendar() {
    if (querySnapshot != null) {
      isInitialLoaded = true;
      if (querySnapshot.value == null) {
        return Center(
          child: CircularProgressIndicator(),
        );
      }

      return SafeArea(
        child: SfCalendar(
          view: CalendarView.month,
          initialDisplayDate: DateTime(2020, 4, 5, 9, 0, 0),
          dataSource: events,
          monthViewSettings: MonthViewSettings(showAgenda: true),
        ),
      );
    }
  }

  void _initializeEventColor() {
    this._colorCollection = <Color>[];
    _colorCollection.add(const Color(0xFF0F8644));
    _colorCollection.add(const Color(0xFF8B1FA9));
    _colorCollection.add(const Color(0xFFD20100));
    _colorCollection.add(const Color(0xFFFC571D));
    _colorCollection.add(const Color(0xFF36B37B));
    _colorCollection.add(const Color(0xFF01A1EF));
    _colorCollection.add(const Color(0xFF3D4FB5));
    _colorCollection.add(const Color(0xFFE47C73));
    _colorCollection.add(const Color(0xFF636363));
    _colorCollection.add(const Color(0xFF0A8043));
  }

  wireEvents(Query meetingQuery) {
    onMeetingAddedSubscription =
        meetingQuery.onChildAdded.listen(onMeetingAdded);
    onMeetingDeletedSubscription =
        meetingQuery.onChildRemoved.listen(onMeetingRemoved);
    onMeetingUpdatedSubscription =
        meetingQuery.onChildChanged.listen(onMeetingChanged);
  }

  onMeetingAdded(Event event) {
    if (!isInitialLoaded) {
      return;
    }
    if (event.snapshot.value != null) {
      final Random random = new Random();
      Meeting meeting = Meeting.fromSnapShot(
          event.snapshot, _colorCollection[random.nextInt(9)]);
      events.appointments.add(meeting);
      events.notifyListeners(CalendarDataSourceAction.add, [meeting]);
    }
  }

  onMeetingRemoved(Event event) {
    if (!isInitialLoaded) {
      return;
    }
    if (event.snapshot.value != null) {
      int index = events.appointments
          .indexWhere((element) => element.key == event.snapshot.key);
      Meeting meeting = events.appointments[index];
      events.appointments.remove(meeting);
      events.notifyListeners(CalendarDataSourceAction.remove, [meeting]);
    }
  }

  onMeetingChanged(Event event) {
    if (!isInitialLoaded) {
      return;
    }
    if (event.snapshot.value != null) {
      final Random random = new Random();
      Meeting meeting = Meeting.fromSnapShot(
          event.snapshot, _colorCollection[random.nextInt(9)]);
      events.appointments.remove(meeting);
      events.notifyListeners(CalendarDataSourceAction.remove, [meeting]);
      events.appointments.add(meeting);
      events.notifyListeners(CalendarDataSourceAction.add, [meeting]);
    }
  }

  MeetingDataSource _getCalendarDataSource([List<Meeting> collection]) {
    List<Meeting> meetings = collection ?? <Meeting>[];
    return MeetingDataSource(meetings);
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return appointments[index].from;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments[index].to;
  }

  @override
  bool isAllDay(int index) {
    return appointments[index].isAllDay;
  }

  @override
  String getSubject(int index) {
    return appointments[index].eventName;
  }

  @override
  Color getColor(int index) {
    return appointments[index].background;
  }
}

class Meeting {
  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;
  String key;

  Meeting(
      {this.eventName,
      this.from,
      this.to,
      this.background,
      this.isAllDay,
      this.key});

  static Meeting fromSnapShot(DataSnapshot dataSnapshot, Color color) {
    return Meeting(
        eventName: dataSnapshot.value['Subject'],
        from: DateFormat('dd/MM/yyyy HH:mm:ss')
            .parse(dataSnapshot.value['StartTime']),
        to: DateFormat('dd/MM/yyyy HH:mm:ss')
            .parse(dataSnapshot.value['EndTime']),
        background: color,
        key: dataSnapshot.key,
        isAllDay: false);
  }

  static Meeting map(dynamic data, Color color, String key) {
    return Meeting(
        eventName: data['Subject'],
        from: DateFormat('dd/MM/yyyy HH:mm:ss').parse(data['StartTime']),
        to: DateFormat('dd/MM/yyyy HH:mm:ss').parse(data['EndTime']),
        background: color,
        key: key,
        isAllDay: false);
  }
}
