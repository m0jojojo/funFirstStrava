/// Base URL for the backend.
/// For LOCAL testing: flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:3000 ...
/// For PRODUCTION: use default (Railway). Do not push API_BASE_URL override.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://funfirststrava-dev.up.railway.app',
);
///const String apiBaseUrl = 'http://192.168.1.2:3000';