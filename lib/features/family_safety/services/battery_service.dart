import 'package:battery_plus/battery_plus.dart';

import '../models/family_models.dart';

class BatteryService {
  BatteryService({Battery? battery}) : _battery = battery ?? Battery();

  final Battery _battery;

  Future<BatteryAssessment> read() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return BatteryAssessment(
        level: level,
        state: state,
        observedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      return BatteryAssessment(
        level: -1,
        state: BatteryState.unknown,
        observedAt: DateTime.now().toUtc(),
      );
    }
  }

  Stream<BatteryState> watchState() => _battery.onBatteryStateChanged;
}
