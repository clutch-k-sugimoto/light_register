plugins {
    id("com.android.application")
    // AGP provides built-in Kotlin; apply the Flutter plugin after AGP.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "jp.lightregister.light_register"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // Replace with the organization's registered application ID before distribution.
        applicationId = "jp.lightregister.light_register"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Distribution requires a separately configured release signing key.
            // Do not ship a release build signed with the development key.
        }
    }
}

flutter {
    source = "../.."
}
