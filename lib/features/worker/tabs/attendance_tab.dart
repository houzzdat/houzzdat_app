import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

enum AttendanceStatus { checkedOut, checkedIn }
enum ReportType { voice, text }

/// Attendance tab — check-in, daily report (checkout), and history.
/// All data persisted to the Supabase `attendance` table.
class AttendanceTab extends StatefulWidget {
  final String accountId;
  final String userId;
  final String? projectId;

  const AttendanceTab({
    super.key,
    required this.accountId,
    required this.userId,
    this.projectId,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();

  AttendanceStatus _status = AttendanceStatus.checkedOut;
  String? _activeAttendanceId;
  DateTime? _checkInTime;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  // Mock geofence
  bool _isInsideSite = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      // Check for an open session (checked in but not out)
      final openSession = await _supabase
          .from('attendance')
          .select()
          .eq('user_id', widget.userId)
          .isFilter('check_out_at', null)
          .order('check_in_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (openSession != null) {
        _status = AttendanceStatus.checkedIn;
        _activeAttendanceId = openSession['id'].toString();
        _checkInTime = DateTime.parse(openSession['check_in_at']);
      } else {
        _status = AttendanceStatus.checkedOut;
        _activeAttendanceId = null;
        _checkInTime = null;
      }

      // Load completed sessions for history
      final historyData = await _supabase
          .from('attendance')
          .select()
          .eq('user_id', widget.userId)
          .not('check_out_at', 'is', null)
          .order('check_in_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _history = (historyData as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckIn() async {
    try {
      final result = await _supabase.from('attendance').insert({
        'user_id': widget.userId,
        'account_id': widget.accountId,
        'project_id': widget.projectId,
        'check_in_at': DateTime.now().toIso8601String(),
      }).select().single();

      if (mounted) {
        setState(() {
          _status = AttendanceStatus.checkedIn;
          _activeAttendanceId = result['id'].toString();
          _checkInTime = DateTime.parse(result['check_in_at']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e')),
        );
      }
    }
  }

  void _handleSendDailyReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _DailyReportSheet(
        recorderService: _recorderService,
        accountId: widget.accountId,
        userId: widget.userId,
        projectId: widget.projectId,
        onReportSent: (reportType, {String? reportText, String? voiceNoteId}) async {
          Navigator.pop(sheetContext);

          try {
            await _supabase.from('attendance').update({
              'check_out_at': DateTime.now().toIso8601String(),
              'report_type': reportType == ReportType.voice ? 'voice' : 'text',
              'report_text': reportText,
              'report_voice_note_id': voiceNoteId,
            }).eq('id', _activeAttendanceId!);

            if (mounted) {
              setState(() {
                _status = AttendanceStatus.checkedOut;
                _activeAttendanceId = null;
                _checkInTime = null;
              });

              _loadAttendance();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Daily report sent! You are checked out.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to check out: $e')),
              );
            }
          }
        },
      ),
    );
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);
  String _formatDate(DateTime dt) => DateFormat('EEE, MMM d').format(dt);

  String _elapsedSinceCheckIn() {
    if (_checkInTime == null) return '';
    final diff = DateTime.now().difference(_checkInTime!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}h ${m}m on site';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A237E)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 24),
          _buildGeofenceToggle(),
          const SizedBox(height: 24),
          if (_history.isNotEmpty) ...[
            Text('HISTORY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1,
              )),
            const SizedBox(height: 12),
            ..._history.map((entry) => _buildHistoryCard(entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              _status == AttendanceStatus.checkedIn
                  ? LucideIcons.hardHat
                  : LucideIcons.logIn,
              size: 48,
              color: _status == AttendanceStatus.checkedIn
                  ? Colors.green
                  : const Color(0xFF1A237E),
            ),
            const SizedBox(height: 12),
            Text(
              _status == AttendanceStatus.checkedIn
                  ? 'You are ON SITE'
                  : 'You are CHECKED OUT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _status == AttendanceStatus.checkedIn
                    ? Colors.green.shade700
                    : const Color(0xFF424242),
              ),
            ),
            if (_status == AttendanceStatus.checkedIn && _checkInTime != null) ...[
              const SizedBox(height: 6),
              Text(
                'Checked in at ${_formatTime(_checkInTime!)} — ${_elapsedSinceCheckIn()}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 20),
            if (_status == AttendanceStatus.checkedOut) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.logIn, size: 20),
                  label: const Text('MARK ATTENDANCE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isInsideSite ? _handleCheckIn : null,
                ),
              ),
              if (!_isInsideSite) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.mapPinOff, size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 6),
                    Text('Not on Site — move to the job site to check in',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                  ],
                ),
              ],
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.send, size: 20),
                  label: const Text('SEND DAILY REPORT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCA28),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: _handleSendDailyReport,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceToggle() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Icon(
          _isInsideSite ? LucideIcons.mapPin : LucideIcons.mapPinOff,
          color: _isInsideSite ? Colors.green : Colors.red,
        ),
        title: Text(
          _isInsideSite ? 'On Site (Mock)' : 'Off Site (Mock)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Toggle to simulate geofence', style: TextStyle(fontSize: 11)),
        value: _isInsideSite,
        activeColor: Colors.green,
        onChanged: (val) => setState(() => _isInsideSite = val),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final checkIn = DateTime.parse(entry['check_in_at']);
    final checkOut = DateTime.parse(entry['check_out_at']);
    final reportType = entry['report_type'];
    final isVoice = reportType == 'voice';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isVoice
                    ? const Color(0xFFE8EAF6)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isVoice ? LucideIcons.volume2 : LucideIcons.edit3,
                size: 20,
                color: isVoice
                    ? const Color(0xFF1A237E)
                    : const Color(0xFFFFCA28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(checkIn),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(checkIn)} — ${_formatTime(checkOut)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Text(
              isVoice ? 'Voice' : 'Text',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for sending a daily report — voice or text.
class _DailyReportSheet extends StatefulWidget {
  final AudioRecorderService recorderService;
  final String accountId;
  final String userId;
  final String? projectId;
  final Function(ReportType, {String? reportText, String? voiceNoteId}) onReportSent;

  const _DailyReportSheet({
    required this.recorderService,
    required this.accountId,
    required this.userId,
    this.projectId,
    required this.onReportSent,
  });

  @override
  State<_DailyReportSheet> createState() => _DailyReportSheetState();
}

class _DailyReportSheetState extends State<_DailyReportSheet> {
  bool _isRecording = false;
  bool _isSending = false;
  final _textController = TextEditingController();
  bool _showTextInput = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceReport() async {
    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _isSending = true;
      });

      try {
        final audioBytes = await widget.recorderService.stopRecording();
        if (audioBytes != null && widget.projectId != null) {
          final url = await widget.recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: widget.projectId!,
            userId: widget.userId,
            accountId: widget.accountId,
          );

          String? voiceNoteId;
          if (url != null) {
            try {
              final note = await Supabase.instance.client
                  .from('voice_notes')
                  .select('id')
                  .eq('audio_url', url)
                  .single();
              voiceNoteId = note['id']?.toString();
            } catch (_) {}
          }

          widget.onReportSent(ReportType.voice, voiceNoteId: voiceNoteId);
        } else {
          setState(() => _isSending = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload: $e')),
          );
        }
      }
    } else {
      final hasPermission = await widget.recorderService.checkPermission();
      if (!hasPermission) return;
      await widget.recorderService.startRecording();
      setState(() => _isRecording = true);
    }
  }

  void _handleTextReport() {
    if (_textController.text.trim().isEmpty) return;
    widget.onReportSent(ReportType.text, reportText: _textController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAILY REPORT',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            )),
          const SizedBox(height: 4),
          Text('Record a voice note or type your report',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isRecording ? LucideIcons.square : LucideIcons.mic, size: 20),
              label: Text(
                _isSending
                    ? 'SENDING...'
                    : _isRecording
                        ? 'STOP & SEND VOICE REPORT'
                        : 'RECORD VOICE REPORT',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSending ? null : _handleVoiceReport,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 16),

          if (!_showTextInput)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.edit3, size: 18),
                label: const Text('TYPE TEXT REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A237E),
                  side: const BorderSide(color: Color(0xFF1A237E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _showTextInput = true),
              ),
            )
          else ...[
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your daily report...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(LucideIcons.send, size: 18),
                label: const Text('SEND TEXT REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCA28),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleTextReport,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
