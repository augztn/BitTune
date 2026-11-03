package com.music.bitchord.desktop

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application

/**
 * Linux desktop entry point.
 *
 * The Android UI is currently hosted by an Activity and relies on Android
 * services, Context-backed stores and Media3. This desktop host deliberately
 * starts as a truthful, buildable native shell rather than pretending those
 * Android services are available on Linux. The shared UI can be migrated
 * behind platform interfaces incrementally without changing Android behavior.
 */
fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "BitWave",
    ) {
        MaterialTheme {
            Surface(modifier = Modifier.fillMaxSize()) {
                DesktopLanding()
            }
        }
    }
}

@Composable
private fun DesktopLanding() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Text("BitWave for Linux")
    }
}
