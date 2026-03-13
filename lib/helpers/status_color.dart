import 'package:flutter/material.dart';
import '../models/monitoring_state.dart';

Color getStatusColor(MonitoringStatus status, {double opacity = 1.0}) {
  Color baseColor;
  switch (status) {
    case MonitoringStatus.inactive:
      baseColor = Color.fromRGBO(18, 26, 44, 1);
      break;
    case MonitoringStatus.active:
      baseColor = Colors.green;
      break;
    case MonitoringStatus.offRoute:
      baseColor = Colors.yellow;
      break;
    case MonitoringStatus.alertCountdown:
      baseColor = Colors.orange;
      break;
    case MonitoringStatus.heightenedEmergency:
      baseColor = Colors.red.shade900;
      break;
    case MonitoringStatus.heightenedMonitoring:
      baseColor = Colors.orange.shade700;
      break;
    case MonitoringStatus.state:
      // TODO: Handle this case.
      throw UnimplementedError();
  }
  return baseColor.withAlpha((opacity * 255).toInt());
}
