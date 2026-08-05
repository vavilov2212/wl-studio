abstract class IdleEvent {
  const IdleEvent();
}

class IdleThresholdReached extends IdleEvent {
  final int idleSeconds;
  final DateTime timestamp;

  IdleThresholdReached({
    required this.idleSeconds,
    required this.timestamp,
  }) : super();
}

class UserReturnedFromIdle extends IdleEvent {
  const UserReturnedFromIdle();
}
