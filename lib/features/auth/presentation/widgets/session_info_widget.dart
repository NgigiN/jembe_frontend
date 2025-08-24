import 'package:flutter/material.dart';
import '../../data/services/user_storage_service.dart';

class SessionInfoWidget extends StatefulWidget {
  const SessionInfoWidget({super.key});

  @override
  State<SessionInfoWidget> createState() => _SessionInfoWidgetState();
}

class _SessionInfoWidgetState extends State<SessionInfoWidget> {
  int _remainingHours = 0;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    final remainingHours = await UserStorageService.getSessionRemainingHours();
    if (mounted) {
      setState(() {
        _remainingHours = remainingHours;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingHours <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You will stay logged in for $_remainingHours more hour${_remainingHours == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            onPressed: _loadSessionInfo,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.blue[700],
          ),
        ],
      ),
    );
  }
}
