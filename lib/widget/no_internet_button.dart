import 'package:flutter/material.dart';

class NoInternetWidget extends StatefulWidget {
  final Future<void> Function() onRetry;

  const NoInternetWidget({super.key, required this.onRetry});

  @override
  State<NoInternetWidget> createState() => _NoInternetWidgetState();
}

class _NoInternetWidgetState extends State<NoInternetWidget> {
  bool _isRetrying = false;
  bool _cooldownActive = false;

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _cooldownActive = true;
        });
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _cooldownActive = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            const Text(
              'Open your WiFi to cache the map',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isRetrying || _cooldownActive ? null : _handleRetry,
                icon:
                    _isRetrying || _cooldownActive
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh, size: 16),
                label: Text(
                  _isRetrying
                      ? 'Checking...'
                      : _cooldownActive
                      ? 'Wait...'
                      : 'Retry',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
