/// Backend base URL (Laravel API, see ../backend/README.md).
///
/// Default targets the Android emulator, where 10.0.2.2 is the host machine.
/// Override at build/run time:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);
