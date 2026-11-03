import org.jetbrains.compose.desktop.application.dsl.TargetFormat

plugins {
    id("org.jetbrains.kotlin.jvm")
    id("org.jetbrains.compose")
    id("org.jetbrains.kotlin.plugin.compose")
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":shared"))
    implementation(project(":sharedUi"))
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.10.2")

    // The shared analysis engine uses ONNX at runtime on the JVM.
    runtimeOnly("com.microsoft.onnxruntime:onnxruntime:1.20.0")
}

compose.desktop {
    application {
        mainClass = "com.music.bitchord.desktop.MainKt"
        nativeDistributions {
            targetFormats(TargetFormat.AppImage)
            packageName = "BitWave"
            packageVersion = "1.0.0"
            description = "BitWave music player"
            vendor = "BitWave"
            linux {
                appCategory = "AudioVideo"
                packageName = "bitwave"
            }
        }
    }
}
