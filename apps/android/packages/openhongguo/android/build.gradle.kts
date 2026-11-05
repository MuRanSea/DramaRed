group = "dev.openhongguo.flutter"
version = "0.2.0"

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "dev.openhongguo.flutter"

    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        // 原生代码按名字调用 gomobile 的 Java 类，App 混淆时必须保留。
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    // gomobile 编译的 Go core（dev.openhongguo.core 和 go.*）
    implementation(files("libs/core.jar"))
}
