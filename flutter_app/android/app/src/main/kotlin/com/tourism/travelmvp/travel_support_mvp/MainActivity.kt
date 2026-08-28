package com.tourism.travelmvp.travel_support_mvp

// flutter_naver_login이 결과 콜백에 FragmentActivity를 요구한다(README 명시).
// FlutterActivity면 네이버 로그인 결과가 조용히 유실된다.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
