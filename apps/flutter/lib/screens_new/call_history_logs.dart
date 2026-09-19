import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';
import '../state/session_controller.dart';

class CallHistoryLogs extends StatefulWidget {
  const CallHistoryLogs({super.key});

  @override
  State<CallHistoryLogs> createState() => _CallHistoryLogsState();
}

class _CallHistoryLogsState extends State<CallHistoryLogs> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final callHistory = session.callHistory;
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: PgColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Call History & Logs',
          style: TextStyle(
            color: PgColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: PgColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: PgSpace.sm),
        ],
      ),
      body: AppBackground(
        child: callHistory.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call_end_rounded, size: 64,
                        color: PgColors.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: PgSpace.lg),
                    const Text(
                      'No calls analyzed yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: PgColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: PgSpace.sm),
                    const Text(
                      'Incoming calls will appear here\nafter PhaseGuard analyzes them',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: PgColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(PgSpace.lg),
                itemCount: callHistory.length,
                itemBuilder: (context, index) {
                  final call = callHistory[index];
                  return _buildCallCard(call);
                },
              ),
      ),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> call) {
    Color verdictColor;
    switch (call['verdict']) {
      case 'SAFE':
        verdictColor = PgColors.safe;
        break;
      case 'SCAM':
        verdictColor = PgColors.scam;
        break;
      case 'SUSPICIOUS':
        verdictColor = PgColors.suspicious;
        break;
      default:
        verdictColor = PgColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: PgSpace.md),
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call['phoneNumber'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: PgColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: PgSpace.xs),
                    Text(
                      '${call['date']} at ${call['time']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PgColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.15),
                  border: Border.all(color: verdictColor),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                ),
                child: Text(
                  call['verdict'],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: verdictColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            children: [
              _buildStatChip('Duration', call['duration']),
              const SizedBox(width: PgSpace.sm),
              _buildStatChip('Peak PDI', (call['peakPdi'] as double).toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          Container(
            padding: const EdgeInsets.all(PgSpace.md),
            decoration: BoxDecoration(
              color: PgColors.bgElevated,
              borderRadius: BorderRadius.circular(PgRadii.bar),
            ),
            child: Text(
              call['transcript'],
              style: const TextStyle(
                fontSize: 12,
                color: PgColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showCallDetails(call);
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PgColors.accent,
                    side: BorderSide(color: PgColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: PgSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Report'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PgColors.textSecondary,
                    side: BorderSide(color: PgColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PgColors.bgElevated,
        borderRadius: BorderRadius.circular(PgRadii.bar),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.textMuted,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCallDetails(Map<String, dynamic> call) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PgColors.bgSecondary,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(PgSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Call Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PgColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: PgColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: PgSpace.lg),
            _buildDetailRow('Phone Number', call['phoneNumber']),
            const SizedBox(height: PgSpace.md),
            _buildDetailRow('Date & Time', '${call['date']} at ${call['time']}'),
            const SizedBox(height: PgSpace.md),
            _buildDetailRow('Duration', call['duration']),
            const SizedBox(height: PgSpace.md),
            _buildDetailRow('Verdict', call['verdict']),
            const SizedBox(height: PgSpace.md),
            _buildDetailRow('Peak PDI', (call['peakPdi'] as double).toStringAsFixed(2)),
            const SizedBox(height: PgSpace.lg),
            const Text(
              'Full Transcript',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PgColors.textSecondary,
              ),
            ),
            const SizedBox(height: PgSpace.md),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(PgSpace.md),
                decoration: BoxDecoration(
                  color: PgColors.bgElevated,
                  borderRadius: BorderRadius.circular(PgRadii.card),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    call['transcript'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: PgColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: PgColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PgColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}