import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/substitution_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String facultyId;

  const AdminDashboard({super.key, required this.userData, required this.facultyId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final _dbService = DatabaseService();
  final _subService = SubstitutionService();
  final _authService = AuthService();

  Map<String, dynamic> _timetable = {};
  Map<String, dynamic> _attendance = {};
  Map<String, dynamic> _allFaculty = {};
  Map<String, dynamic> _substitutionLogs = {};
  Map<String, dynamic> _reports = {};
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _notifications = {};
  Map<String, dynamic> _facultyAvailability = {};
  Map<String, dynamic> _subjectsDatabase = {};
  bool _isLoading = true;
  String _todayDate = '';
  StreamSubscription? _attendanceSub;
  StreamSubscription? _logsSub;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _setupListeners();
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _logsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

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

  void _setupListeners() {
    _attendanceSub = _dbService.attendanceStream(_todayDate).listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          _attendance = _deepConvert(event.snapshot.value as Map);
        });
      }
    });
    _logsSub = _dbService.substitutionLogsStream().listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          _substitutionLogs = _deepConvert(event.snapshot.value as Map);
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _dbService.getTimetableForDate(_todayDate),
        _dbService.getAttendanceForDate(_todayDate),
        _dbService.getAllFaculty(),
        _dbService.getSubstitutionLogs(),
        _dbService.getReports(),
        _dbService.getSettings(),
        _dbService.getAllNotifications(),
        _dbService.getAllFacultyAvailability(_todayDate),
        _dbService.getSubjectsDatabase(),
      ]);
      if (mounted) {
        setState(() {
          _timetable = results[0];
          _attendance = results[1];
          _allFaculty = results[2];
          _substitutionLogs = results[3];
          _reports = results[4];
          _settings = results[5];
          _notifications = results[6];
          _facultyAvailability = results[7];
          _subjectsDatabase = results[8];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _markAbsent(String periodId, Map<String, dynamic> periodData) async {
    final facultyId = periodData['facultyId'] as String;
    final facultyName = periodData['facultyName'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AbsentDialog(
        facultyName: facultyName,
        subjectName: periodData['subjectName'] ?? '',
        subjectCode: periodData['subject'] ?? '',
      ),
    );

    try {
      final result = await _subService.autoAssignSubstitute(
        date: _todayDate,
        periodId: periodId,
        absentFacultyId: facultyId,
        periodData: periodData,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result != null) {
        _showResultDialog(
          facultyName: facultyName,
          subjectName: periodData['subjectName'] ?? '',
          subjectCode: periodData['subject'] ?? '',
          substituteName: result['substituteName'],
          matchReason: result['matchReason'],
          time: periodData['time'] ?? '',
        );
        // Refresh data after assignment
        _loadData();
      } else {
        _showNoSubstituteDialog(facultyName);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _undoAbsence(String periodId) async {
    try {
      await _dbService.updateAttendance(_todayDate, periodId, {
        'status': 'present',
        'substituteId': null,
        'substituteName': null,
        'autoAssigned': null,
        'assignedAt': null,
        'substitutionStatus': null,
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Absence & substitution removed.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showResultDialog({
    required String facultyName,
    required String subjectName,
    required String subjectCode,
    required String substituteName,
    required String matchReason,
    required String time,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Substitute Assigned!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.person_off, 'Absent', facultyName),
            const SizedBox(height: 12),
            _infoRow(Icons.book, 'Subject', '$subjectName ($subjectCode)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.person, color: AppTheme.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(substituteName,
                        style: GoogleFonts.inter(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 16))),
                  ]),
                  const SizedBox(height: 6),
                  Text(matchReason, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('✅ Assigned automatically at $time',
                      style: GoogleFonts.inter(color: AppTheme.success, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.inter(color: AppTheme.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showNoSubstituteDialog(String facultyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text('No Substitute Found',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white))),
        ]),
        content: Text('No qualified and available faculty found to substitute for $facultyName.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: GoogleFonts.inter(color: AppTheme.accent))),
        ],
      ),
    );
  }

  void _showManualAssignDialog(String periodId, Map<String, dynamic> periodData) {
    showDialog(
      context: context,
      builder: (ctx) {
        final absentFacultyId = periodData['facultyId'] as String;
        final allFacultyList = _allFaculty.entries
            .where((e) => e.value is Map && (e.value as Map)['role'] == 'faculty' && e.key != absentFacultyId)
            .toList();

        return AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: Text('Manual Assignment', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allFacultyList.length,
              itemBuilder: (context, index) {
                final entry = allFacultyList[index];
                final fId = entry.key;
                final fData = Map<String, dynamic>.from(entry.value as Map);
                
                final avail = _facultyAvailability[fId] is Map ? _facultyAvailability[fId] as Map : {};
                final isFree = avail[periodId] == 'free';

                return ListTile(
                  title: Text(fData['name'] ?? '', style: GoogleFonts.inter(color: Colors.white)),
                  subtitle: Text(isFree ? 'Free for this period' : 'Busy',
                      style: GoogleFonts.inter(color: isFree ? AppTheme.success : AppTheme.danger, fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: isFree ? () async {
                      Navigator.pop(ctx);
                      try {
                        await _subService.manualAssignSubstitute(
                          date: _todayDate,
                          periodId: periodId,
                          absentFacultyId: absentFacultyId,
                          substituteId: fId,
                          periodData: periodData,
                        );
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Manual assignment successful'), backgroundColor: AppTheme.success),
                          );
                        }
                      } catch (e) {
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
                            );
                         }
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFree ? AppTheme.accent : AppTheme.cardMid,
                      foregroundColor: AppTheme.primaryDark,
                    ),
                    child: const Text('Assign'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppTheme.textMuted, size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
    ]);
  }

  String _getStatusForPeriod(String periodId) {
    if (_attendance.containsKey(periodId)) {
      final att = _attendance[periodId];
      if (att is Map && att['status'] == 'absent') return 'absent';
    }
    return 'present';
  }

  String? _getSubstituteForPeriod(String periodId) {
    if (_attendance.containsKey(periodId)) {
      final att = _attendance[periodId];
      if (att is Map && att['substituteName'] != null) {
        return att['substituteName'] as String?;
      }
    }
  }

  Widget _buildAbsentAlertBanner() {
    final absentEntries = _attendance.entries
        .where((e) => e.value is Map && (e.value as Map)['status'] == 'absent')
        .toList();

    if (absentEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.danger.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
              const SizedBox(width: 8),
              Text('LIVE ALERT: FACULTY ABSENT',
                  style: GoogleFonts.inter(
                      color: AppTheme.danger, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          ...absentEntries.map((entry) {
            final data = Map<String, dynamic>.from(entry.value as Map);
            final substituteStr = data['substituteName'] != null
                ? '→ Covered by ${data['substituteName']} (${data['substitutionStatus'] ?? 'pending'})'
                : '→ Pending auto-assignment';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${data['facultyName']} (${data['subject']}) $substituteStr',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        title: Text('SUBSTITUTE AUTO',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accentOrange.withValues(alpha: 0.2), AppTheme.accentOrange.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('👑', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('ADMIN', style: GoogleFonts.inter(color: AppTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.accent), onPressed: _loadData),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(children: [
              // ── FORCEFUL ABSENT ALERT BANNER (real-time) ──
              _buildAbsentAlertBanner(),
              // Date bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(10)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppTheme.primaryDark,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                  unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
                  tabs: const [
                    Tab(text: 'Timetable'),
                    Tab(text: 'Status'),
                    Tab(text: 'Logs'),
                    Tab(text: 'Reports'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(controller: _tabController, children: [
                  _buildTimetableTab(),
                  _buildStatusTab(),
                  _buildLogsTab(),
                  _buildReportsTab(),
                ]),
              ),
            ]),
    );
  }

  Widget _buildDrawer() {
    final collegeInfo = _settings['collegeInfo'] is Map ? Map<String, dynamic>.from(_settings['collegeInfo'] as Map) : <String, dynamic>{};
    final autoSubSettings = _settings['autoSubstitution'] is Map ? Map<String, dynamic>.from(_settings['autoSubstitution'] as Map) : <String, dynamic>{};

    return Drawer(
      backgroundColor: AppTheme.primaryDark,
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.cardDark, AppTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryDark, size: 32),
            ),
            const SizedBox(height: 12),
            Text(widget.userData['name'] ?? 'Admin',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            Text(widget.userData['email'] ?? '',
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
          ]),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard, color: AppTheme.accent),
          title: Text('Dashboard', style: GoogleFonts.inter(color: Colors.white)),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: const Icon(Icons.history, color: AppTheme.info),
          title: Text('View All Logs', style: GoogleFonts.inter(color: Colors.white)),
          onTap: () { Navigator.pop(context); _tabController.animateTo(2); },
        ),
        ListTile(
          leading: const Icon(Icons.assessment, color: AppTheme.success),
          title: Text('Reports', style: GoogleFonts.inter(color: Colors.white)),
          onTap: () { Navigator.pop(context); _tabController.animateTo(3); },
        ),
        const Divider(color: AppTheme.dividerColor),
        // Settings section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('SETTINGS', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        ),
        ListTile(
          leading: const Icon(Icons.school, color: AppTheme.textMuted),
          title: Text(collegeInfo['name'] ?? 'College', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
          subtitle: Text('${collegeInfo['academicYear'] ?? ''} • ${collegeInfo['semester'] ?? ''} Sem',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
        ),
        ListTile(
          leading: Icon(
            autoSubSettings['enabled'] == true ? Icons.auto_fix_high : Icons.auto_fix_off,
            color: autoSubSettings['enabled'] == true ? AppTheme.success : AppTheme.danger,
          ),
          title: Text('Auto-Substitution', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
          subtitle: Text(
            'Algorithm: ${autoSubSettings['matchAlgorithm'] ?? 'N/A'} • Max/day: ${autoSubSettings['maxSubstitutionsPerDay'] ?? 'N/A'}',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (autoSubSettings['enabled'] == true ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              autoSubSettings['enabled'] == true ? 'ON' : 'OFF',
              style: GoogleFonts.inter(
                color: autoSubSettings['enabled'] == true ? AppTheme.success : AppTheme.danger,
                fontSize: 10, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const Divider(color: AppTheme.dividerColor),
        // Faculty count
        ListTile(
          leading: const Icon(Icons.people, color: AppTheme.info),
          title: Text(
            '${_allFaculty.entries.where((e) => e.value is Map && (e.value as Map)['role'] == 'faculty').length} Faculty Members',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
          subtitle: Text('${_subjectsDatabase.length} Subjects registered',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
        ),
        const Divider(color: AppTheme.dividerColor),
        ListTile(
          leading: const Icon(Icons.logout, color: AppTheme.danger),
          title: Text('Logout', style: GoogleFonts.inter(color: AppTheme.danger)),
          onTap: () async {
            await _authService.signOut();
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            }
          },
        ),
      ]),
    );
  }

  // ─── Timetable Tab ───
  Widget _buildTimetableTab() {
    final sortedPeriods = _timetable.entries.toList()
      ..sort((a, b) {
        final aTime = (a.value as Map)['time'] ?? '';
        final bTime = (b.value as Map)['time'] ?? '';
        return aTime.toString().compareTo(bTime.toString());
      });

    if (sortedPeriods.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.event_busy, color: AppTheme.textMuted, size: 64),
        const SizedBox(height: 16),
        Text('No timetable for today', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedPeriods.length,
        itemBuilder: (context, index) {
          final periodId = sortedPeriods[index].key;
          final periodData = Map<String, dynamic>.from(sortedPeriods[index].value as Map);
          final status = _getStatusForPeriod(periodId);
          final substitute = _getSubstituteForPeriod(periodId);
          final substStatus = _attendance[periodId] is Map ? (_attendance[periodId] as Map)['substitutionStatus'] : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: status == 'absent' ? AppTheme.danger.withValues(alpha: 0.4) : AppTheme.dividerColor.withValues(alpha: 0.3),
              ),
              boxShadow: status == 'absent'
                  ? [BoxShadow(color: AppTheme.danger.withValues(alpha: 0.1), blurRadius: 12)]
                  : null,
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Text(periodData['time'] ?? '', style: GoogleFonts.inter(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(periodData['endTime'] ?? '', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(periodData['subjectName'] ?? periodData['subject'] ?? '',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${periodData['facultyName'] ?? ''} • ${periodData['room'] ?? ''}',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                  Text('${periodData['batch'] ?? ''} • Sem ${periodData['semester'] ?? ''}',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                ])),
                if (status == 'absent')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('ABSENT', style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.undo, color: AppTheme.textSecondary, size: 20),
                        tooltip: 'Cancel Absence & Remove Substitute',
                        onPressed: () => _undoAbsence(periodId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1, color: AppTheme.accent, size: 20),
                        tooltip: 'Assign Substitute Manually',
                        onPressed: () => _showManualAssignDialog(periodId, periodData),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => _markAbsent(periodId, periodData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.danger,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: Text('ABSENT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
              if (substitute != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.swap_horiz, color: AppTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('🔄 Substituted by $substitute',
                          style: GoogleFonts.inter(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w500)),
                      if (substStatus != null)
                        Text('Status: $substStatus',
                            style: GoogleFonts.inter(
                              color: substStatus == 'accepted' ? AppTheme.success : AppTheme.warning,
                              fontSize: 10, fontWeight: FontWeight.w600)),
                    ])),
                  ]),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  // ─── Status Tab ───
  Widget _buildStatusTab() {
    final absentEntries = _attendance.entries
        .where((e) => e.value is Map && (e.value as Map)['status'] == 'absent')
        .toList();

    final facultyOnly = _allFaculty.entries
        .where((e) => e.value is Map && (e.value as Map)['role'] == 'faculty')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Quick Action chips
        Text('MARK ABSENT (Quick Action)',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: facultyOnly.map((entry) {
            final fData = Map<String, dynamic>.from(entry.value as Map);
            return ActionChip(
              avatar: CircleAvatar(
                backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                child: Text((fData['name'] as String? ?? '?')[0], style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
              ),
              label: Text(fData['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
              backgroundColor: AppTheme.cardDark,
              side: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
              onPressed: () {
                _timetable.forEach((periodId, periodData) {
                  if (periodData is Map && periodData['facultyId'] == entry.key) {
                    if (_getStatusForPeriod(periodId) != 'absent') {
                      _markAbsent(periodId, Map<String, dynamic>.from(periodData));
                      return;
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Faculty Availability
        Text('FACULTY AVAILABILITY TODAY',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 12),
        ..._facultyAvailability.entries.map((entry) {
          final fId = entry.key;
          final avail = Map<String, dynamic>.from(entry.value as Map);
          final fInfo = _allFaculty[fId];
          final fName = fInfo is Map ? fInfo['name'] ?? fId : fId;
          final freeCount = avail.values.where((v) => v == 'free').length;
          final busyCount = avail.values.where((v) => v == 'busy').length;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$freeCount Free', style: GoogleFonts.inter(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$busyCount Busy', style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ])),
              // Period dots
              Row(children: avail.entries.map((p) {
                return Container(
                  width: 18, height: 18,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: p.value == 'free'
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : AppTheme.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(child: Text(
                    p.key.toString().replaceAll('period_', ''),
                    style: TextStyle(
                      color: p.value == 'free' ? AppTheme.success : AppTheme.danger,
                      fontSize: 9, fontWeight: FontWeight.w700),
                  )),
                );
              }).toList()),
            ]),
          );
        }),
        const SizedBox(height: 24),

        // Auto-substitute status
        Text('AUTO-SUBSTITUTE STATUS',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 12),
        if (absentEntries.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 48),
              const SizedBox(height: 12),
              Text('All faculty present today', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 15)),
            ]),
          )
        else
          ...absentEntries.map((entry) {
            final data = Map<String, dynamic>.from(entry.value as Map);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person_off, color: AppTheme.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${data['facultyName']} - ${data['subject']}',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('Absent', style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
                if (data['substituteName'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Substituted by ${data['substituteName']}',
                            style: GoogleFonts.inter(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Status: ${data['substitutionStatus'] ?? 'pending'} • Auto: ${data['autoAssigned'] == true ? 'Yes' : 'No'}',
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                        if (data['assignedAt'] != null)
                          Text('Assigned: ${data['assignedAt']}',
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                      ])),
                    ]),
                  ),
                ],
              ]),
            );
          }),

        const SizedBox(height: 24),

        // Notifications overview
        Text('NOTIFICATIONS SENT',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 12),
        if (_notifications.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: Text('No notifications sent', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
          )
        else
          ..._notifications.entries.map((entry) {
            final notif = Map<String, dynamic>.from(entry.value as Map);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(notif['isRead'] == true ? Icons.mark_email_read : Icons.mark_email_unread,
                    color: notif['isRead'] == true ? AppTheme.textMuted : AppTheme.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(notif['title'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(notif['message'] ?? '', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                  Text('To: ${notif['toFacultyEmail'] ?? ''} • Read: ${notif['isRead'] == true ? 'Yes' : 'No'}',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                ])),
              ]),
            );
          }),
      ]),
    );
  }

  // ─── Logs Tab ───
  Widget _buildLogsTab() {
    final logs = _substitutionLogs.entries.toList()
      ..sort((a, b) {
        final aDate = (a.value as Map)['assignedAt'] ?? '';
        final bDate = (b.value as Map)['assignedAt'] ?? '';
        return bDate.toString().compareTo(aDate.toString());
      });

    if (logs.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.history, color: AppTheme.textMuted, size: 64),
        const SizedBox(height: 16),
        Text('No substitution logs yet', style: GoogleFonts.inter(color: AppTheme.textMuted)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final logData = Map<String, dynamic>.from(logs[index].value as Map);
        final status = logData['status'] ?? 'pending';
        final statusColor = status == 'accepted' ? AppTheme.success
            : status == 'rejected' ? AppTheme.danger : AppTheme.warning;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(status.toString().toUpperCase(),
                    style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(logData['subjectName'] ?? '',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600))),
              Text(logData['time'] ?? '',
                  style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text('${logData['absentFacultyName']} → ${logData['substituteFacultyName']}',
                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('📚 ${logData['subject']} • 🏫 ${logData['room']} • 👥 ${logData['batch']}',
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
            Text(logData['matchReason'] ?? '', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
            Text('Method: ${logData['method']} • By: ${logData['assignedBy']} • Date: ${logData['date']}',
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
            if (logData['acceptedAt'] != null)
              Text('Accepted at: ${logData['acceptedAt']}',
                  style: GoogleFonts.inter(color: AppTheme.success, fontSize: 10)),
          ]),
        );
      },
    );
  }

  // ─── Reports Tab ───
  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.assessment, color: AppTheme.textMuted, size: 64),
        const SizedBox(height: 16),
        Text('No reports yet', style: GoogleFonts.inter(color: AppTheme.textMuted)),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Subjects database
        Text('SUBJECTS DATABASE',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 12),
        ..._subjectsDatabase.entries.map((entry) {
          final subj = Map<String, dynamic>.from(entry.value as Map);
          final qualifiedCount = (subj['qualifiedFaculty'] as List?)?.length ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(entry.key, style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subj['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${subj['department']} • Sem ${subj['semester']} • ${subj['credits']} credits',
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('$qualifiedCount Faculty',
                    style: GoogleFonts.inter(color: AppTheme.info, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }),
        const SizedBox(height: 24),

        // Daily reports
        Text('DAILY REPORTS',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 12),
        ..._reports.entries.map((entry) {
          final report = Map<String, dynamic>.from(entry.value as Map);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.calendar_today, color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text(entry.key, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
              const SizedBox(height: 16),
              // Stats grid
              Row(children: [
                _statCard('Total Absent', '${report['totalAbsent'] ?? 0}', AppTheme.danger),
                const SizedBox(width: 8),
                _statCard('Substitutions', '${report['totalSubstitutions'] ?? 0}', AppTheme.info),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _statCard('Auto Assigned', '${report['autoAssigned'] ?? 0}', AppTheme.accent),
                const SizedBox(width: 8),
                _statCard('Manual', '${report['manualAssigned'] ?? 0}', AppTheme.accentOrange),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _statCard('Accepted', '${report['acceptedCount'] ?? 0}', AppTheme.success),
                const SizedBox(width: 8),
                _statCard('Pending', '${report['pendingCount'] ?? 0}', AppTheme.warning),
                const SizedBox(width: 8),
                _statCard('Rejected', '${report['rejectedCount'] ?? 0}', AppTheme.danger),
              ]),
              if (report['generatedAt'] != null) ...[
                const SizedBox(height: 8),
                Text('Generated: ${report['generatedAt']}',
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
              ],
            ]),
          );
        }),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(value, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── Scanning Dialog ───
class _AbsentDialog extends StatelessWidget {
  final String facultyName;
  final String subjectName;
  final String subjectCode;

  const _AbsentDialog({required this.facultyName, required this.subjectName, required this.subjectCode});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Text('⚠️ MARKING ABSENT',
            style: GoogleFonts.inter(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text(facultyName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        Text('$subjectName ($subjectCode)', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: AppTheme.accent),
        const SizedBox(height: 16),
        Text('🔍 Scanning for matching skill...', style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 13)),
        const SizedBox(height: 8),
      ]),
    );
  }
}
