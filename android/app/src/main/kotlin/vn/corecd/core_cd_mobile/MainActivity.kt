package vn.corecd.core_cd_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (BiometricPrompt) cần FragmentActivity, không dùng được với FlutterActivity thường.
class MainActivity : FlutterFragmentActivity()
