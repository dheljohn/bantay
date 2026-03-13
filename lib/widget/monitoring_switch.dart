import 'package:bantay/helpers/route_contact.dart';
import 'package:bantay/helpers/status_color.dart';
import 'package:bantay/models/monitoring_state.dart';
import 'package:bantay/services/monitoring_service.dart';
import 'package:bantay/widget/password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MonitoringSwitch extends StatefulWidget {
  const MonitoringSwitch({super.key});

  @override
  State<MonitoringSwitch> createState() => _MonitoringSwitchState();
}

class _MonitoringSwitchState extends State<MonitoringSwitch> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MonitoringService>(
      builder: (context, service, child) {
        final state = service.state;

        return Switch(
          value: state.isEnabled,
          activeColor: const Color.fromRGBO(10, 17, 26, 1),
          inactiveTrackColor: const Color.fromRGBO(31, 38, 54, 1),
          activeTrackColor: getStatusColor(state.status),
          trackOutlineColor: WidgetStateProperty.all(
            state.isEnabled
                ? getStatusColor(state.status)
                : const Color.fromRGBO(31, 38, 54, 1),
          ),
          inactiveThumbColor: const Color.fromRGBO(136, 152, 177, 1),
          onChanged:
              service.isSwitchInteractable
                  ? (_) async {
                    final missing = await service.getMissingPermissions();
                    if (missing.isNotEmpty) {
                      await service.checkPermissionsAndGuide(context);
                      return;
                    }

                    final canEnable = await canEnableProtection(context);
                    if (!canEnable) return;

                    if (state.isEnabled &&
                        state.status == MonitoringStatus.heightenedEmergency) {
                      final correct = await PasswordDialog.show(
                        context,
                        correctPassword: "1010",
                      );
                      if (!correct) return;
                    }

                    await service.toggleMonitoring();
                  }
                  : null,
        );
      },
    );
  }
}
