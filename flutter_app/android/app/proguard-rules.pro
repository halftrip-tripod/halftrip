# okhttp(카카오·네이버 SDK 의존)가 참조하는 선택적 TLS 라이브러리 — 미포함이 정상이라 경고만 억제.
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE

# ── 소셜 로그인 R8 픽스 (릴리즈에서만 나는 오류들) ─────────────────────────────
# 네이버 SDK: 난독화되면 토큰 요청이 깨져 no_catagorized_error (naveridlogin-sdk-android#88)
-keep class com.navercorp.nid.** { *; }
-keep class com.nhn.android.naverlogin.** { *; }

# Retrofit 공식 룰 (네이버 SDK 의존) — R8 full mode의 제네릭 제거 방지 포함
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn retrofit2.KotlinExtensions
-dontwarn retrofit2.KotlinExtensions$*
-if interface * { @retrofit2.http.* <methods>; }
-keep,allowobfuscation interface <1>
-if interface * { @retrofit2.http.* <methods>; }
-keep,allowobfuscation interface * extends <1>
-keep,allowoptimization,allowshrinking,allowobfuscation class kotlin.coroutines.Continuation
-if interface * { @retrofit2.http.* public *** *(...); }
-keep,allowoptimization,allowshrinking,allowobfuscation class <3>
# "Response must include generic type" 방지 — Response<T> 제네릭 유지
-keep,allowobfuscation,allowshrinking class retrofit2.Response
