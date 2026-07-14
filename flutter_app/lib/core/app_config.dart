class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.fastApiBaseUrl,
    required this.useMockLogin,
    required this.useMockApi,
    required this.mapProvider,
    required this.kakaoMapAppKey,
    required this.googleMapApiKey,
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
      kakaoMapAppKey: String.fromEnvironment('KAKAO_MAP_APP_KEY', defaultValue: ''),
      googleMapApiKey:
          String.fromEnvironment('GOOGLE_MAP_API_KEY', defaultValue: ''),
    );
  }

  final String apiBaseUrl;
  final String fastApiBaseUrl;
  final bool useMockLogin;
  final bool useMockApi;
  final String mapProvider;
  final String kakaoMapAppKey;
  final String googleMapApiKey;

  bool get canUseKakaoMap =>
      mapProvider.toLowerCase() == 'kakao' && kakaoMapAppKey.isNotEmpty;

  bool get canUseGoogleMap =>
      mapProvider.toLowerCase() == 'google' && googleMapApiKey.isNotEmpty;
}
