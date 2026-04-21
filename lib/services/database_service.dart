import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ─── Deep convert Firebase snapshot to Map<String, dynamic> ───
  static Map<String, dynamic> _deepConvert(Map data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Map) {
        result[key.toString()] = _deepConvert(value);
      } else if (value is List) {
        result[key.toString()] = value.map((e) => e is Map ? _deepConvert(e) : e).toList();
      } else {
        result[key.toString()] = value;
      }
    });
    return result;
  }

  static Map<String, dynamic> _snapshotToMap(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) return {};
    if (snapshot.value is Map) {
      return _deepConvert(snapshot.value as Map);
    }
    return {};
  }

  // ─── Faculty ───
  Future<Map<String, dynamic>> getAllFaculty() async {
    final snapshot = await _db.child('faculty').get();
    return _snapshotToMap(snapshot);
  }

  Future<Map<String, dynamic>?> getFaculty(String facultyId) async {
    final snapshot = await _db.child('faculty/$facultyId').get();
    if (!snapshot.exists) return null;
    return _deepConvert(snapshot.value as Map);
  }

  Future<void> updateFacultyData(String facultyId, Map<String, dynamic> data) async {
    await _db.child('faculty/$facultyId').update(data);
  }

  // ─── Timetable ───
  Future<Map<String, dynamic>> getTimetableForDate(String date) async {
    final snapshot = await _db.child('timetable/$date').get();
    return _snapshotToMap(snapshot);
  }

  // ─── Attendance ───
  Future<Map<String, dynamic>> getAttendanceForDate(String date) async {
    final snapshot = await _db.child('attendance/$date').get();
    return _snapshotToMap(snapshot);
  }

  Stream<DatabaseEvent> attendanceStream(String date) {
    return _db.child('attendance/$date').onValue;
  }

  Future<void> updateAttendance(String date, String periodId, Map<String, dynamic> data) async {
    await _db.child('attendance/$date/$periodId').update(data);
  }

  Future<void> setAttendance(String date, String periodId, Map<String, dynamic> data) async {
    await _db.child('attendance/$date/$periodId').set(data);
  }

  // ─── Faculty Availability ───
  Future<Map<String, dynamic>> getFacultyAvailability(String facultyId, String date) async {
    final snapshot = await _db.child('facultyAvailability/$facultyId/$date').get();
    return _snapshotToMap(snapshot);
  }

  Future<Map<String, dynamic>> getAllFacultyAvailability(String date) async {
    final snapshot = await _db.child('facultyAvailability').get();
    if (!snapshot.exists) return {};
    final data = _deepConvert(snapshot.value as Map);
    final result = <String, dynamic>{};
    data.forEach((facultyId, dates) {
      if (dates is Map && dates.containsKey(date)) {
        result[facultyId] = dates[date] is Map
            ? Map<String, dynamic>.from(dates[date] as Map)
            : dates[date];
      }
    });
    return result;
  }

  // ─── Subjects Database ───
  Future<Map<String, dynamic>> getSubjectsDatabase() async {
    final snapshot = await _db.child('subjectsDatabase').get();
    return _snapshotToMap(snapshot);
  }

  // ─── Substitution Logs ───
  Future<void> addSubstitutionLog(String logId, Map<String, dynamic> data) async {
    await _db.child('substitutionLogs/$logId').set(data);
  }

  Future<Map<String, dynamic>> getSubstitutionLogs() async {
    final snapshot = await _db.child('substitutionLogs').get();
    return _snapshotToMap(snapshot);
  }

  Stream<DatabaseEvent> substitutionLogsStream() {
    return _db.child('substitutionLogs').onValue;
  }

  // ─── Notifications ───
  Future<void> addNotification(String notifId, Map<String, dynamic> data) async {
    await _db.child('notifications/$notifId').set(data);
  }

  Stream<DatabaseEvent> notificationsStream(String facultyId) {
    return _db
        .child('notifications')
        .orderByChild('toFacultyId')
        .equalTo(facultyId)
        .onValue;
  }

  Future<void> updateNotification(String notifId, Map<String, dynamic> data) async {
    await _db.child('notifications/$notifId').update(data);
  }

  Future<Map<String, dynamic>> getNotificationsForFaculty(String facultyId) async {
    final snapshot = await _db
        .child('notifications')
        .orderByChild('toFacultyId')
        .equalTo(facultyId)
        .get();
    return _snapshotToMap(snapshot);
  }

  // ─── Reports ───
  Future<void> updateReport(String date, Map<String, dynamic> data) async {
    await _db.child('reports/$date').set(data);
  }

  Future<Map<String, dynamic>> getReports() async {
    final snapshot = await _db.child('reports').get();
    return _snapshotToMap(snapshot);
  }

  // ─── Settings ───
  Future<Map<String, dynamic>> getSettings() async {
    final snapshot = await _db.child('settings').get();
    return _snapshotToMap(snapshot);
  }

  // ─── All Notifications (Admin view) ───
  Future<Map<String, dynamic>> getAllNotifications() async {
    final snapshot = await _db.child('notifications').get();
    return _snapshotToMap(snapshot);
  }
}
