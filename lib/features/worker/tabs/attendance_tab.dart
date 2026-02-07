import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

enum AttendanceStatus { checkedOut, checkedIn }
enum ReportType { voice, text }

class AttendanceEntry {
  final DateTime checkInTime;
  final DateTime checkOutTime;
  final ReportType reportType;

  AttendanceEntry({
    required this.checkInTime,
    required this.checkOutTime,
    required this.reportType,
  });
}

/// Attendance tab — check-in, daily report (checkout), and history.
/// Implements a mock GeoFence check: if isInsideSite is false,
/// the Mark Attendance button is disabled with a 'Not on Site' warning.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  AttendanceStatus _status = AttendanceStatus.checkedOut;
  DateTime? _checkInTime;
  final List<AttendanceEntry> _history = [];
  final AudioRecorderService _recorderService = AudioRecorderService();

  // Mock geofence — in production, this would come from location services
  bool _isInsideSite = true;

  void _handleCheckIn() {
    setState(() {
      _status = AttendanceStatus.checkedIn;
      _checkInTime = DateTime.now();
    });
  }

  void _handleSendDailyReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DailyReportSheet(
        recorderService: _recorderService,
        onReportSent: (reportType) {
          Navigator.pop(context);
          setState(() {
            _history.insert(
              0,
              AttendanceEntry(
                checkInTime: _checkInTime!,
                checkOutTime: DateTime.now(),
                reportType: reportType,
              ),
            );
            _status = AttendanceStatus.checkedOut;
            _checkInTime = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Daily report sent! You are checked out.'),
              backgroundColor: Colors.green,
            ),
          );
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status card
        _buildStatusCard(),

        const SizedBox(height: 24),

        // GeoFence toggle (mock — for demo/testing)
        _buildGeofenceToggle(),

        const SizedBox(height: 24),

        // History header
        if (_history.isNotEmpty) ...[
          Text('HISTORY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1,
            )),
          const SizedBox(height: 12),

          // History cards
          ..._history.map((entry) => _buildHistoryCard(entry)),
        ],
      ],
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

            // Action button
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
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  Widget _buildHistoryCard(AttendanceEntry entry) {
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
                color: entry.reportType == ReportType.voice
                    ? const Color(0xFFE8EAF6)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                entry.reportType == ReportType.voice
                    ? LucideIcons.volume2
                    : LucideIcons.edit3,
                size: 20,
                color: entry.reportType == ReportType.voice
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
                    _formatDate(entry.checkInTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(entry.checkInTime)} — ${_formatTime(entry.checkOutTime)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Text(
              entry.reportType == ReportType.voice ? 'Voice' : 'Text',
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
  final Function(ReportType) onReportSent;

  const _DailyReportSheet({
    required this.recorderService,
    required this.onReportSent,
  });

  @override
  State<_DailyReportSheet> createState() => _DailyReportSheetState();
}

class _DailyReportSheetState extends State<_DailyReportSheet> {
  bool _isRecording = false;
  final _textController = TextEditingController();
  bool _showTextInput = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceReport() async {
    if (_isRecording) {
      await widget.recorderService.stopRecording();
      setState(() => _isRecording = false);
      widget.onReportSent(ReportType.voice);
    } else {
      final hasPermission = await widget.recorderService.checkPermission();
      if (!hasPermission) return;
      await widget.recorderService.startRecording();
      setState(() => _isRecording = true);
    }
  }

  void _handleTextReport() {
    if (_textController.text.trim().isEmpty) return;
    widget.onReportSent(ReportType.text);
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

          // Voice record button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: Icon(
                _isRecording ? LucideIcons.square : LucideIcons.mic,
                size: 20,
              ),
              label: Text(
                _isRecording ? 'STOP & SEND VOICE REPORT' : 'RECORD VOICE REPORT',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleVoiceReport,
            ),
          ),

          const SizedBox(height: 16),

          // Divider with OR
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

          // Text report toggle
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
