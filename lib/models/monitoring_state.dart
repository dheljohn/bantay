enum MonitoringStatus {
  inactive, // Not monitoring
  active, // On safe route, monitoring normally
  offRoute, // Off all routes, warning
  alertCountdown, // Countdown before SMS (waiting for user response)
  heightenedEmergency, // SMS sent, minute updates
  heightenedMonitoring,
  state, // User confirmed safe, still monitoring closely
}

class MonitoringState {
  final bool isEnabled;
  final MonitoringStatus status;
  final int offRouteConsecutiveCount;
  final DateTime? lastCheckTime;
  final DateTime? offRouteSince;
  final int updatesSent;
  final int? alertCountdownSeconds; // ✅ remaining seconds during countdown

  MonitoringState({
    required this.isEnabled,
    required this.status,
    this.offRouteConsecutiveCount = 0,
    this.lastCheckTime,
    this.offRouteSince,
    this.updatesSent = 0,
    this.alertCountdownSeconds,
  });

  // ✅ Standardized to .name — matches BantayTaskHandler sendDataToMain
  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'status': status.name, // ✅ "active" not "MonitoringStatus.active"
      'offRouteConsecutiveCount': offRouteConsecutiveCount,
      'lastCheckTime': lastCheckTime?.toIso8601String(),
      'offRouteSince': offRouteSince?.toIso8601String(),
      'updatesSent': updatesSent,
      'alertCountdownSeconds': alertCountdownSeconds,
    };
  }

  // ✅ Standardized to .name — matches toJson
  factory MonitoringState.fromJson(Map<String, dynamic> json) {
    return MonitoringState(
      isEnabled: json['isEnabled'] ?? false,
      status: MonitoringStatus.values.firstWhere(
        (e) => e.name == json['status'], // ✅ matches .name
        orElse: () => MonitoringStatus.inactive,
      ),
      offRouteConsecutiveCount: json['offRouteConsecutiveCount'] ?? 0,
      lastCheckTime:
          json['lastCheckTime'] != null
              ? DateTime.tryParse(
                json['lastCheckTime'],
              ) // ✅ tryParse safer than parse
              : null,
      offRouteSince:
          json['offRouteSince'] != null
              ? DateTime.tryParse(json['offRouteSince'])
              : null,
      updatesSent: json['updatesSent'] ?? 0,
      alertCountdownSeconds: json['alertCountdownSeconds'],
    );
  }

  MonitoringState copyWith({
    bool? isEnabled,
    MonitoringStatus? status,
    int? offRouteConsecutiveCount,
    DateTime? lastCheckTime,
    DateTime? offRouteSince,
    int? updatesSent,
    int? alertCountdownSeconds,
  }) {
    return MonitoringState(
      isEnabled: isEnabled ?? this.isEnabled,
      status: status ?? this.status,
      offRouteConsecutiveCount:
          offRouteConsecutiveCount ?? this.offRouteConsecutiveCount,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      offRouteSince: offRouteSince ?? this.offRouteSince,
      updatesSent: updatesSent ?? this.updatesSent,
      alertCountdownSeconds:
          alertCountdownSeconds ?? this.alertCountdownSeconds,
    );
  }

  //new added
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MonitoringState &&
        other.isEnabled == isEnabled &&
        other.status == status &&
        other.offRouteConsecutiveCount == offRouteConsecutiveCount &&
        other.lastCheckTime == lastCheckTime &&
        other.offRouteSince == offRouteSince &&
        other.updatesSent == updatesSent &&
        other.alertCountdownSeconds == alertCountdownSeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      isEnabled,
      status,
      offRouteConsecutiveCount,
      lastCheckTime,
      offRouteSince,
      updatesSent,
      alertCountdownSeconds,
    );
  }
}
