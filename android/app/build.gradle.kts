import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Khoá ký phát hành: mỗi app một file `android/key.<flavor>.properties` (KHÔNG commit, đã .gitignore) gồm
// storeFile (đường dẫn tuyệt đối hoặc tương đối so với thư mục android/app), storePassword, keyAlias, keyPassword.
// Xem docs/RELEASE.md.
fun loadKeyProps(flavor: String): Properties? {
    val f = rootProject.file("key.$flavor.properties")
    if (!f.exists()) return null
    return Properties().also { p -> FileInputStream(f).use { p.load(it) } }
}

val allowDebugSigning = System.getenv("ALLOW_DEBUG_SIGNING") == "1"

android {
    namespace = "vn.corecd.core_cd_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        listOf("staff", "customer").forEach { flavor ->
            val props = loadKeyProps(flavor) ?: return@forEach
            create("${flavor}Release") {
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    // Khoá phát hành của flavor (chỉ áp cho build `release`: build type `debug` luôn dùng khoá debug).
    // Thiếu file khoá → null; việc chặn phát hành nằm ở `taskGraph.whenReady` bên dưới.
    fun releaseSigning(flavor: String) =
        signingConfigs.findByName("${flavor}Release")
            ?: if (allowDebugSigning) signingConfigs.getByName("debug") else null

    // Hai app từ một codebase: `staff` (lib/main.dart) và `customer` (lib/main_customer.dart).
    // Chạy: flutter run --flavor customer -t lib/main_customer.dart --dart-define-from-file=env/dev.json
    flavorDimensions += "app"
    productFlavors {
        create("staff") {
            dimension = "app"
            // Giữ nguyên id cũ để không mất liên tục phiên bản/kênh phát hành đã có.
            applicationId = "vn.corecd.core_cd_mobile"
            manifestPlaceholders["appName"] = "CCTG Nhân viên"
            signingConfig = releaseSigning("staff")
        }
        create("customer") {
            dimension = "app"
            applicationId = "vn.corecd.customer"
            manifestPlaceholders["appName"] = "CCTG"
            signingConfig = releaseSigning("customer")
        }
    }
}

// Không có khoá phát hành thì không cho đóng gói bản release (tránh lỡ phát hành bản ký bằng khoá debug).
// Để thử `--release` trên máy dev: ALLOW_DEBUG_SIGNING=1 flutter build apk --release --flavor customer ...
gradle.taskGraph.whenReady {
    val unsigned = allTasks
        .filter { it.project == project }
        .mapNotNull { Regex("^(assemble|bundle|package)(Staff|Customer)Release$").find(it.name) }
        .map { it.groupValues[2].lowercase() }
        .filter { loadKeyProps(it) == null }
        .distinct()
    if (unsigned.isNotEmpty() && !allowDebugSigning) {
        throw GradleException(
            "Thiếu android/key.${unsigned.first()}.properties — không thể ký bản release. " +
                "Xem docs/RELEASE.md (hoặc đặt ALLOW_DEBUG_SIGNING=1 chỉ để thử trên máy dev).",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
