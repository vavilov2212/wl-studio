abstract class StartupService {
  Future<void> enable();
  Future<void> disable();
  Future<bool> isEnabled();
}
