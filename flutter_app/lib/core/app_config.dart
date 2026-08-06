class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.fastApiBaseUrl,
    required this.useMockLogin,
    required this.useMockApi,
    required this.mapProvider,
    required this.kakaoMapAppKey,
    required this.googleMapApiKey,
    required this.googleOAuthClientId,
    required this.kakaoNativeAppKey,
    required this.kakaoJavaScriptKey,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://halftrip-springboot.onrender.com/api',
      ),
      fastApiBaseUrl: String.fromEnvironment(
        'FASTAPI_BASE_URL',
        defaultValue: 'https://halftrip-fastapi.onrender.com',
      ),
      useMockLogin: bool.fromEnvironment('USE_MOCK_LOGIN', defaultValue: true),
      useMockApi: bool.fromEnvironment('USE_MOCK_API', defaultValue: false),
      mapProvider: String.fromEnvironment('MAP_PROVIDER', defaultValue: 'mock'),
      kakaoMapAppKey: String.fromEnvironment(
        'KAKAO_MAP_APP_KEY',
        defaultValue: '',
      ),
      googleMapApiKey: String.fromEnvironment(
        'GOOGLE_MAP_API_KEY',
        defaultValue: '',
      ),
      googleOAuthClientId: String.fromEnvironment(
        'GOOGLE_OAUTH_CLIENT_ID',
        defaultValue: '',
      ),
      kakaoNativeAppKey: String.fromEnvironment(
        'KAKAO_NATIVE_APP_KEY',
        defaultValue: '',
      ),
      kakaoJavaScriptKey: String.fromEnvironment(
        'KAKAO_JAVASCRIPT_KEY',
        defaultValue: '',
      ),
    );
  }

  final String apiBaseUrl;
  final String fastApiBaseUrl;
  final bool useMockLogin;
  final bool useMockApi;
  final String mapProvider;
  final String kakaoMapAppKey;
  final String googleMapApiKey;
  final String googleOAuthClientId;
  final String kakaoNativeAppKey;
  final String kakaoJavaScriptKey;

  bool get canUseKakaoMap =>
      mapProvider.toLowerCase() == 'kakao' && kakaoMapAppKey.isNotEmpty;

  bool get canUseGoogleMap =>
      mapProvider.toLowerCase() == 'google' && googleMapApiKey.isNotEmpty;

  /// 카카오 로그인 SDK 초기화 가능 여부 — 개발자 앱 키 발급 전에는 안내만 띄운다.
  bool get kakaoLoginConfigured =>
      kakaoNativeAppKey.isNotEmpty || kakaoJavaScriptKey.isNotEmpty;
}
