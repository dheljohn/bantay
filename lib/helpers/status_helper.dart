import '../models/monitoring_state.dart';

String getStatusText(MonitoringStatus status) {
  switch (status) {
    case MonitoringStatus.inactive:
      return 'Monitoring Disabled';
    case MonitoringStatus.active:
      return 'On Safe Route';
    case MonitoringStatus.offRoute:
      return 'Off Route Warning';
    case MonitoringStatus.alertCountdown:
      return 'Alert Countdown';
    case MonitoringStatus.heightenedEmergency:
      return 'EMERGENCY MODE';
    case MonitoringStatus.heightenedMonitoring:
      return 'Enhanced Monitoring';
    case MonitoringStatus.state:
      // TODO: Handle this case.
      throw UnimplementedError();
  }
}
