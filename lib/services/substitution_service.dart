import 'package:intl/intl.dart';
import 'database_service.dart';

class SubstitutionService {
  final DatabaseService _dbService = DatabaseService();

  /// Core auto-substitution algorithm.
  /// Called when admin marks a faculty as absent for a specific period.
  Future<Map<String, dynamic>?> autoAssignSubstitute({
    required String date,
    required String periodId,
    required String absentFacultyId,
    required Map<String, dynamic> periodData,
  }) async {
    final subjectCode = periodData['subject'] as String;

    // Step 1: Get subjects database to find qualified faculty
    final subjectsDb = await _dbService.getSubjectsDatabase();
    final subjectInfo = subjectsDb[subjectCode];

    List<String> qualifiedFacultyIds = [];
    if (subjectInfo != null && subjectInfo['qualifiedFaculty'] != null) {
      qualifiedFacultyIds = List<String>.from(subjectInfo['qualifiedFaculty']);
    } else {
      // Fallback: find faculty with matching skills
      final allFaculty = await _dbService.getAllFaculty();
      final subjectName = periodData['subjectName'] as String? ?? '';
      allFaculty.forEach((id, data) {
        if (id == absentFacultyId) return;
        if (data['role'] == 'admin') return;
        final skills = List<String>.from(data['skills'] ?? []);
        if (skills.any((s) => subjectName.toLowerCase().contains(s.toLowerCase()) ||
            s.toLowerCase().contains(subjectName.toLowerCase()))) {
          qualifiedFacultyIds.add(id);
        }
      });
    }

    // Step 2: Remove absent faculty from candidates
    qualifiedFacultyIds.remove(absentFacultyId);

    if (qualifiedFacultyIds.isEmpty) {
      return null; // No qualified substitute found
    }

    // Step 3: Check availability of each candidate
    final availability = await _dbService.getAllFacultyAvailability(date);
    final attendance = await _dbService.getAttendanceForDate(date);
    final timetable = await _dbService.getTimetableForDate(date);

    // Step 4: Score each candidate (lower is better - fewer classes that day)
    String? bestCandidateId;
    int bestScore = 999;

    for (final candidateId in qualifiedFacultyIds) {
      // Check if candidate is available for this period
      final candidateAvail = availability[candidateId];
      if (candidateAvail != null) {
        final periodStatus = candidateAvail[periodId];
        if (periodStatus == 'busy') continue;
      }

      // Check if candidate is not already absent
      bool isAbsent = false;
      attendance.forEach((pId, aData) {
        if (aData is Map &&
            aData['facultyId'] == candidateId &&
            aData['status'] == 'absent') {
          isAbsent = true;
        }
      });
      if (isAbsent) continue;

      // Check candidate isn't already teaching at this time
      bool isBusyInTimetable = false;
      timetable.forEach((pId, pData) {
        if (pId == periodId) return; // skip the absent faculty's period
        if (pData is Map && pData['facultyId'] == candidateId) {
          // Check if it's the same time slot
          if (pData['time'] == periodData['time']) {
            isBusyInTimetable = true;
          }
        }
      });
      if (isBusyInTimetable) continue;

      // Count how many classes the candidate has today (lower = better)
      int classCount = 0;
      timetable.forEach((pId, pData) {
        if (pData is Map && pData['facultyId'] == candidateId) {
          classCount++;
        }
      });

      // Count existing substitutions today
      attendance.forEach((pId, aData) {
        if (aData is Map && aData['substituteId'] == candidateId) {
          classCount++;
        }
      });

      if (classCount < bestScore) {
        bestScore = classCount;
        bestCandidateId = candidateId;
      }
    }

    if (bestCandidateId == null) {
      return null; // No available substitute found
    }

    // Step 5: Get substitute faculty info
    final substituteFaculty = await _dbService.getFaculty(bestCandidateId);
    if (substituteFaculty == null) return null;

    final absentFaculty = await _dbService.getFaculty(absentFacultyId);
    final now = DateTime.now().toUtc().toIso8601String();

    // Step 6: Update attendance record
    final attendanceData = {
      'facultyId': absentFacultyId,
      'facultyName': absentFaculty?['name'] ?? periodData['facultyName'],
      'subject': subjectCode,
      'status': 'absent',
      'substituteId': bestCandidateId,
      'substituteName': substituteFaculty['name'],
      'autoAssigned': true,
      'assignedAt': now,
      'substitutionStatus': 'pending',
      'remarks': '',
    };
    await _dbService.setAttendance(date, periodId, attendanceData);

    // Step 7: Create substitution log
    final logId = 'auto_${date.replaceAll('-', '')}_${DateTime.now().millisecondsSinceEpoch}';
    final logData = {
      'id': logId,
      'date': date,
      'period': periodId,
      'time': periodData['time'],
      'absentFacultyId': absentFacultyId,
      'absentFacultyName': absentFaculty?['name'] ?? periodData['facultyName'],
      'absentFacultyEmail': absentFaculty?['email'] ?? '',
      'substituteFacultyId': bestCandidateId,
      'substituteFacultyName': substituteFaculty['name'],
      'substituteFacultyEmail': substituteFaculty['email'] ?? '',
      'subject': subjectCode,
      'subjectName': periodData['subjectName'] ?? subjectInfo?['name'] ?? subjectCode,
      'room': periodData['room'] ?? '',
      'batch': periodData['batch'] ?? '',
      'method': 'auto-skill-match',
      'matchReason': 'Same subject skill (${periodData['subjectName']}), Least busy ($bestScore classes)',
      'assignedBy': 'system',
      'assignedAt': now,
      'status': 'pending',
      'acceptedAt': null,
    };
    await _dbService.addSubstitutionLog(logId, logData);

    // Step 8: Create notification for substitute
    final notifId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final notifData = {
      'id': notifId,
      'toFacultyId': bestCandidateId,
      'toFacultyEmail': substituteFaculty['email'] ?? '',
      'title': 'Substitution Assignment',
      'message': 'You have been assigned to substitute for ${absentFaculty?['name'] ?? periodData['facultyName']} (${periodData['subjectName']}) at ${periodData['time']} in ${periodData['room']}',
      'type': 'substitution',
      'relatedLogId': logId,
      'isRead': false,
      'createdAt': now,
      'actions': ['accept', 'report'],
    };
    await _dbService.addNotification(notifId, notifData);

    return {
      'substituteId': bestCandidateId,
      'substituteName': substituteFaculty['name'],
      'substituteEmail': substituteFaculty['email'],
      'logId': logId,
      'matchReason': logData['matchReason'],
    };
  }

  /// Manual assignment bypasses algorithm and forces assignment
  Future<void> manualAssignSubstitute({
    required String date,
    required String periodId,
    required String absentFacultyId,
    required String substituteId,
    required Map<String, dynamic> periodData,
  }) async {
    final substituteFaculty = await _dbService.getFaculty(substituteId);
    if (substituteFaculty == null) throw Exception("Substitute faculty not found");

    final absentFaculty = await _dbService.getFaculty(absentFacultyId);
    final now = DateTime.now().toUtc().toIso8601String();
    final subjectCode = periodData['subject'] as String;
    
    final subjectsDb = await _dbService.getSubjectsDatabase();
    final subjectInfo = subjectsDb[subjectCode];

    // Update attendance record
    final attendanceData = {
      'facultyId': absentFacultyId,
      'facultyName': absentFaculty?['name'] ?? periodData['facultyName'],
      'subject': subjectCode,
      'status': 'absent',
      'substituteId': substituteId,
      'substituteName': substituteFaculty['name'],
      'autoAssigned': false,
      'assignedAt': now,
      'substitutionStatus': 'pending',
      'remarks': 'Manually assigned by Admin',
    };
    await _dbService.setAttendance(date, periodId, attendanceData);

    // Create substitution log
    final logId = 'manual_${date.replaceAll('-', '')}_${DateTime.now().millisecondsSinceEpoch}';
    final logData = {
      'id': logId,
      'date': date,
      'period': periodId,
      'time': periodData['time'],
      'absentFacultyId': absentFacultyId,
      'absentFacultyName': absentFaculty?['name'] ?? periodData['facultyName'],
      'absentFacultyEmail': absentFaculty?['email'] ?? '',
      'substituteFacultyId': substituteId,
      'substituteFacultyName': substituteFaculty['name'],
      'substituteFacultyEmail': substituteFaculty['email'] ?? '',
      'subject': subjectCode,
      'subjectName': periodData['subjectName'] ?? subjectInfo?['name'] ?? subjectCode,
      'room': periodData['room'] ?? '',
      'batch': periodData['batch'] ?? '',
      'method': 'manual-override',
      'matchReason': 'Admin manually selected substitute',
      'assignedBy': 'admin',
      'assignedAt': now,
      'status': 'pending',
      'acceptedAt': null,
    };
    await _dbService.addSubstitutionLog(logId, logData);

    // Create notification for substitute
    final notifId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final notifData = {
      'id': notifId,
      'toFacultyId': substituteId,
      'toFacultyEmail': substituteFaculty['email'] ?? '',
      'title': 'Manual Substitution Assignment',
      'message': 'You have been manually assigned by Admin to substitute for ${absentFaculty?['name'] ?? periodData['facultyName']} (${periodData['subjectName']}) at ${periodData['time']} in ${periodData['room']}',
      'type': 'substitution',
      'relatedLogId': logId,
      'isRead': false,
      'createdAt': now,
      'actions': ['accept', 'report'],
    };
    await _dbService.addNotification(notifId, notifData);
  }

  /// Accept a substitution assignment
  Future<void> acceptSubstitution(String logId, String date, String periodId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    // Update substitution log
    await _dbService.addSubstitutionLog(logId, {
      'status': 'accepted',
      'acceptedAt': now,
    });
    // Update attendance
    await _dbService.updateAttendance(date, periodId, {
      'substitutionStatus': 'accepted',
    });
  }

  /// Get today's date formatted
  String getTodayDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}
