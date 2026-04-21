import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/substitution_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';

class FacultyDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String facultyId;

  const FacultyDashboard({super.key, required this.userData, required this.facultyId});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> with SingleTickerProviderStateMixin {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _subService = SubstitutionService();

  Map<String, dynamic> _timetable = {};
  Map<String, dynamic> _attendance = {};
  Map<String, dynamic> _notifications = {};
  Map<String, dynamic> _myAvailability = {};
  Map<String, dynamic> _facultyData = {};
  bool _isLoading = true;
  String _todayDate = '';
  StreamSubscription? _notifSub;
  StreamSubscription? _attendanceSub;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _tabController = TabController(length: 3, vsync: this);
    _facultyData = Map<String, dynamic>.from(widget.userData);
    _loadData();
    _setupListeners();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _attendanceSub?.cancel();
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
    _notifSub = _dbService.notificationsStream(widget.facultyId).listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          _notifications = _deepConvert(event.snapshot.value as Map);
        });
      }
    });
    _attendanceSub = _dbService.attendanceStream(_todayDate).listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          _attendance = _deepConvert(event.snapshot.value as Map);
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
        _dbService.getNotificationsForFaculty(widget.facultyId),
        _dbService.getFacultyAvailability(widget.facultyId, _todayDate),
        _dbService.getFaculty(widget.facultyId),
      ]);
      if (mounted) {
        setState(() {
          _timetable = results[0] as Map<String, dynamic>;
          _attendance = results[1] as Map<String, dynamic>;
          _notifications = results[2] as Map<String, dynamic>;
          _myAvailability = results[3] as Map<String, dynamic>;
          if (results[4] != null) _facultyData = results[4] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<MapEntry<String, dynamic>> _getMySchedule() {
    return _timetable.entries
        .where((e) => e.value is Map && (e.value as Map)['facultyId'] == widget.facultyId)
        .toList()
      ..sort((a, b) {
        final aTime = (a.value as Map)['time'] ?? '';
        final bTime = (b.value as Map)['time'] ?? '';
        return aTime.toString().compareTo(bTime.toString());
      });
  }

  List<MapEntry<String, dynamic>> _getMySubstitutions() {
    return _attendance.entries
        .where((e) => e.value is Map && (e.value as Map)['substituteId'] == widget.facultyId)
        .toList();
  }

  // ─── SELF MARK ABSENT ───
  Future<void> _markSelfAbsent(String periodId, Map<String, dynamic> periodData) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark Absent?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You are marking yourself absent for:', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${periodData['subjectName']} (${periodData['subject']})',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('${periodData['time']} • ${periodData['room']} • ${periodData['batch']}',
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('⚡ A substitute will be auto-assigned based on skills and availability.',
              style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text('Confirm Absent', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show processing dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(height: 16),
            Text('Finding substitute...', style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 14)),
            const SizedBox(height: 8),
          ]),
        ),
      );
    }

    try {
      final result = await _subService.autoAssignSubstitute(
        date: _todayDate,
        periodId: periodId,
        absentFacultyId: widget.facultyId,
        periodData: periodData,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: AppTheme.success),
              const SizedBox(width: 8),
              Expanded(child: Text('✅ ${result['substituteName']} assigned as substitute!')),
            ]),
            backgroundColor: AppTheme.cardDark,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Marked absent but no substitute found. Admin will be notified.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // ─── MARK PRESENT ───
  Future<void> _markSelfPresent(String periodId) async {
    try {
      await _dbService.updateAttendance(_todayDate, periodId, {
        'status': 'present',
        'substituteId': null,
        'substituteName': null,
        'autoAssigned': false,
        'assignedAt': null,
        'substitutionStatus': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Marked present'), backgroundColor: AppTheme.success),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // ─── ACCEPT SUBSTITUTION ───
  Future<void> _acceptSubstitution(String notifId, Map<String, dynamic> notifData) async {
    try {
      await _dbService.updateNotification(notifId, {
        'isRead': true,
        'status': 'accepted',
      });

      _attendance.forEach((periodId, attData) {
        if (attData is Map && attData['substituteId'] == widget.facultyId) {
          _dbService.updateAttendance(_todayDate, periodId, {
            'substitutionStatus': 'accepted',
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Substitution accepted!'), backgroundColor: AppTheme.success),
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

  // ─── REPORT ISSUE ───
  Future<void> _reportIssue(String notifId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Report Issue', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller, maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Describe the issue...',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text('Submit', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _dbService.updateNotification(notifId, {
        'isRead': true, 'status': 'reported', 'reportMessage': result,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported to admin.'), backgroundColor: AppTheme.info),
        );
      }
    }
  }

  // ─── MANAGE SKILLS ───
  Future<void> _manageSkills() async {
    final currentSkills = List<String>.from(_facultyData['skills'] ?? []);
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Manage Skills', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a skill...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true, fillColor: AppTheme.primaryDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                )),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppTheme.accent),
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setDialogState(() => currentSkills.add(controller.text.trim()));
                      controller.clear();
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(shrinkWrap: true, children: currentSkills.map((skill) => ListTile(
                  dense: true,
                  title: Text(skill, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: AppTheme.danger, size: 20),
                    onPressed: () => setDialogState(() => currentSkills.remove(skill)),
                  ),
                )).toList()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted))),
            ElevatedButton(
              onPressed: () async {
                await _dbService.updateFacultyData(widget.facultyId, {'skills': currentSkills});
                if (mounted) {
                  setState(() => _facultyData['skills'] = currentSkills);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Skills updated!'), backgroundColor: AppTheme.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: Text('Save', style: GoogleFonts.inter(color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark, elevation: 0,
        title: Text('SUBSTITUTE AUTO',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.info.withValues(alpha: 0.2), AppTheme.info.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('👨‍🏫', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('FACULTY', style: GoogleFonts.inter(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.accent), onPressed: _loadData),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(children: [
              // Greeting area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('👋 Hello, ${_facultyData['name'] ?? 'Faculty'}',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                  ])),
                  // Unread notification badge
                  Stack(children: [
                    IconButton(
                      icon: const Icon(Icons.notifications, color: AppTheme.textSecondary),
                      onPressed: () => _tabController.animateTo(2),
                    ),
                    if (_notifications.entries.any((e) => e.value is Map && (e.value as Map)['isRead'] == false))
                      Positioned(right: 6, top: 6, child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                      )),
                  ]),
                ]),
              ),
              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(10)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppTheme.primaryDark,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                  unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
                  tabs: const [Tab(text: 'My Schedule'), Tab(text: 'Assignments'), Tab(text: 'Alerts')],
                ),
              ),
              Expanded(child: TabBarView(controller: _tabController, children: [
                _buildScheduleTab(),
                _buildAssignmentsTab(),
                _buildAlertsTab(),
              ])),
            ]),
    );
  }

  // ─── TAB 1: MY SCHEDULE (with absent/present) ───
  Widget _buildScheduleTab() {
    final mySchedule = _getMySchedule();

    if (mySchedule.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.event_available, color: AppTheme.textMuted, size: 64),
        const SizedBox(height: 16),
        Text('No classes scheduled for today', style: GoogleFonts.inter(color: AppTheme.textMuted)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadData, color: AppTheme.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mySchedule.length,
        itemBuilder: (context, index) {
          final periodId = mySchedule[index].key;
          final data = Map<String, dynamic>.from(mySchedule[index].value as Map);
          final attEntry = _attendance[periodId];
          final isAbsent = attEntry is Map && attEntry['status'] == 'absent' && attEntry['facultyId'] == widget.facultyId;
          final hasSubstitute = attEntry is Map && attEntry['substituteName'] != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAbsent ? AppTheme.danger.withValues(alpha: 0.4) : AppTheme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text(data['time'] ?? '',
                        style: GoogleFonts.inter(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(data['endTime'] ?? '',
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['subjectName'] ?? '',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('${data['room'] ?? ''} • ${data['batch'] ?? ''} • Sem ${data['semester'] ?? ''}',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                ])),
                // Status badge
                if (isAbsent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('ABSENT', style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('PRESENT', style: GoogleFonts.inter(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ]),

              // Substitute info if absent
              if (isAbsent && hasSubstitute) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.swap_horiz, color: AppTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Text('Covered by ${attEntry['substituteName']}',
                        style: GoogleFonts.inter(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ],

              // Action buttons
              const SizedBox(height: 12),
              Row(children: [
                if (!isAbsent)
                  Expanded(child: SizedBox(height: 38, child: ElevatedButton.icon(
                    onPressed: () => _markSelfAbsent(periodId, data),
                    icon: const Icon(Icons.person_off, size: 16),
                    label: Text('Mark Absent', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                      foregroundColor: AppTheme.danger, elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                    ),
                  )))
                else
                  Expanded(child: SizedBox(height: 38, child: ElevatedButton.icon(
                    onPressed: () => _markSelfPresent(periodId),
                    icon: const Icon(Icons.person, size: 16),
                    label: Text('Mark Present', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success.withValues(alpha: 0.15),
                      foregroundColor: AppTheme.success, elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppTheme.success.withValues(alpha: 0.3)),
                      ),
                    ),
                  ))),
              ]),
            ]),
          );
        },
      ),
    );
  }

  // ─── TAB 2: MY ASSIGNMENTS (substitutions I'm covering) ───
  Widget _buildAssignmentsTab() {
    final mySubstitutions = _getMySubstitutions();

    return RefreshIndicator(
      onRefresh: _loadData, color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CLASSES I\'M COVERING',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (mySubstitutions.isEmpty)
            _emptyCard('No substitution assignments', Icons.swap_horiz)
          else
            ...mySubstitutions.map((entry) {
              final data = Map<String, dynamic>.from(entry.value as Map);
              final periodData = _timetable[entry.key];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(periodData != null ? periodData['time'] ?? '' : '',
                          style: GoogleFonts.inter(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Covering for ${data['facultyName']}',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                  ]),
                  const SizedBox(height: 6),
                  Text('${data['subject']} • ${periodData?['room'] ?? ''} • ${periodData?['batch'] ?? ''}',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                  Row(children: [
                    Text('Status: ', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (data['substitutionStatus'] == 'accepted' ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${data['substitutionStatus'] ?? 'pending'}'.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: data['substitutionStatus'] == 'accepted' ? AppTheme.success : AppTheme.warning,
                          fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ]),
              );
            }),

          const SizedBox(height: 24),

          // History Button
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: _showHistory,
              icon: const Icon(Icons.history),
              label: Text('VIEW FULL HISTORY', style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── TAB 3: NOTIFICATIONS / ALERTS ───
  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: _loadData, color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NOTIFICATIONS',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_notifications.isEmpty)
            _emptyCard('No notifications', Icons.notifications_none)
          else
            ..._notifications.entries.map((entry) {
              final notif = Map<String, dynamic>.from(entry.value as Map);
              final isRead = notif['isRead'] == true;
              final isAccepted = notif['status'] == 'accepted';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isRead ? AppTheme.cardDark : AppTheme.cardMid,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isRead ? AppTheme.dividerColor.withValues(alpha: 0.3) : AppTheme.accent.withValues(alpha: 0.4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(isRead ? Icons.notifications_none : Icons.notifications_active,
                        color: isRead ? AppTheme.textMuted : AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(notif['title'] ?? '',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
                    if (!isRead)
                      Container(width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 8),
                  Text(notif['message'] ?? '', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
                  if (notif['status'] != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isAccepted ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(notif['status'].toString().toUpperCase(),
                          style: GoogleFonts.inter(
                            color: isAccepted ? AppTheme.success : AppTheme.warning,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  if (!isRead && !isAccepted) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: SizedBox(height: 38, child: ElevatedButton.icon(
                        onPressed: () => _acceptSubstitution(entry.key, notif),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text('Accept', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success, foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ))),
                      const SizedBox(width: 10),
                      Expanded(child: SizedBox(height: 38, child: OutlinedButton.icon(
                        onPressed: () => _reportIssue(entry.key),
                        icon: const Icon(Icons.flag_outlined, size: 16),
                        label: Text('Report', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ))),
                    ]),
                  ],
                ]),
              );
            }),
        ]),
      ),
    );
  }

  Widget _emptyCard(String text, IconData icon) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: AppTheme.textMuted, size: 36),
        const SizedBox(height: 8),
        Text(text, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
      ]),
    );
  }

  void _showHistory() async {
    final logs = await _dbService.getSubstitutionLogs();
    final myLogs = logs.entries
        .where((e) => e.value is Map && (e.value as Map)['substituteFacultyId'] == widget.facultyId)
        .toList()
      ..sort((a, b) {
        final aDate = (a.value as Map)['assignedAt'] ?? '';
        final bDate = (b.value as Map)['assignedAt'] ?? '';
        return bDate.toString().compareTo(aDate.toString());
      });

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.primaryDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (_, controller) => Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16),
            child: Text('My Substitution History',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
          Expanded(child: myLogs.isEmpty
              ? Center(child: Text('No history yet', style: GoogleFonts.inter(color: AppTheme.textMuted)))
              : ListView.builder(
                  controller: controller, padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: myLogs.length,
                  itemBuilder: (_, index) {
                    final log = Map<String, dynamic>.from(myLogs[index].value as Map);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(log['date'] ?? '', style: GoogleFonts.inter(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 12)),
                          const Spacer(),
                          Text(log['time'] ?? '', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                        ]),
                        const SizedBox(height: 6),
                        Text('Substituted ${log['absentFacultyName']}',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('${log['subjectName']} • ${log['room']}',
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                      ]),
                    );
                  },
                ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDrawer() {
    final skills = List<String>.from(_facultyData['skills'] ?? []);
    final subjects = List<String>.from(_facultyData['subjects'] ?? []);

    return Drawer(
      backgroundColor: AppTheme.primaryDark,
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.cardDark, AppTheme.primaryDark],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.info, Color(0xFF2196F3)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(
                (_facultyData['name'] as String? ?? '?')[0],
                style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              )),
            ),
            const SizedBox(height: 12),
            Text(_facultyData['name'] ?? 'Faculty',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            Text(_facultyData['email'] ?? '',
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
          ]),
        ),
        ListTile(
          leading: const Icon(Icons.school, color: AppTheme.info),
          title: Text('Department: ${_facultyData['department'] ?? 'N/A'}',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        ),
        ListTile(
          leading: const Icon(Icons.phone, color: AppTheme.textMuted),
          title: Text(_facultyData['phone'] ?? '',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        ),
        const Divider(color: AppTheme.dividerColor),

        // Skills section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            Text('MY SKILLS', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const Spacer(),
            GestureDetector(
              onTap: _manageSkills,
              child: Text('EDIT', style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 6, runSpacing: 6, children: skills.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Text(s, style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 11)),
          )).toList()),
        ),
        const SizedBox(height: 12),

        // Subjects section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            const Icon(Icons.book, color: AppTheme.info, size: 18),
            const SizedBox(width: 8),
            Text('MY SUBJECTS', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 6, runSpacing: 6, children: subjects.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
            ),
            child: Text(s, style: GoogleFonts.inter(color: AppTheme.info, fontSize: 11)),
          )).toList()),
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
}
