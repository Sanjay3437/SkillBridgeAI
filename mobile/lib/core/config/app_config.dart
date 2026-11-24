/// Build-time configuration.
///
/// Android emulator reaches the host machine via 10.0.2.2.
/// Override for a physical device or desktop:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const appName = 'SkillBridge AI';
  static const disclaimer =
      'Coverage scores describe documented skill coverage. They are not a '
      'hiring probability or a verified assessment of ability.';
}
