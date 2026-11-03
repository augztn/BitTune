package com.music.bitchord.desktop

import androidx.compose.runtime.CompositionLocalProvider
import com.music.bitchord.ui.player.PlayerPlatform
import com.music.bitchord.data.DebugLog
import com.music.bitchord.data.TrackLog
import com.music.bitchord.data.innertube.InnerTubeXResolver
import com.music.bitchord.data.innertube.StreamResolver
import com.music.bitchord.data.innertube.potoken.PoTokenGenerator
import com.music.bitchord.data.lyrics.LyricsTranslation
import com.music.bitchord.data.spotify.SpotifyLibrary
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import bitchord.desktopapp.generated.resources.Res
import bitchord.desktopapp.generated.resources.logo
import java.awt.Dimension
import java.awt.Rectangle
import java.awt.Toolkit
import kotlin.math.roundToInt
import org.jetbrains.compose.resources.painterResource

fun main() {
    // Before any WebView exists, so the sign-in window can start over with an empty jar.
    DesktopWebCookies.install()
    DesktopWindowVisibility.install()
    PlayerPlatform.install(DesktopPlayerHost)
    com.music.bitchord.ui.AppUi.install(DesktopAppUiHost)
    DebugLog.sink = DebugLog.Sink { level, tag, message, error ->
        DesktopTrackLog.log("$tag/$level: $message" + (error?.let { " (${it.message})" } ?: ""))
    }
    LyricsTranslation.cacheDir = DesktopMediaCache.directory.toFile()
    SpotifyLibrary.auth = SpotifyLibrary.Auth {
        DesktopSpotifyToken.accessToken()?.let { SpotifyLibrary.Tokens(it, DesktopSpotifyToken.clientToken()) }
    }
    com.music.bitchord.data.innertube.Innertube.appLanguage = { DesktopStrings.resolvedTag() }
    TrackLog.echo = { level, tag, message, error ->
        DesktopTrackLog.log("$tag/$level: $message" + (error?.let { " (${it.message})" } ?: ""))
    }
    StreamResolver.maxKbps = {
        DesktopStreamClient.ceiling.get() ?: DesktopSourceRegistry.ceiling(null).maxKbps
    }
    InnerTubeXResolver.init(
        filesDir = DesktopMediaCache.directory.toFile(),
        store = DesktopInnerTubeXStore,
        poTokenProvider = PoTokenGenerator(
            createMinter = { DesktopPoTokenWebView.getNewPoTokenGenerator() },
            available = { DesktopPoTokenWebView.available },
        ).asTokenProvider(),
    )
    DesktopPresence.install()
    desktopMain()
}

private fun desktopMain() = application {
    val visible by DesktopWindowVisibility.visible.collectAsState()
    val state = rememberWindowState(width = 1_220.dp, height = 780.dp)
    LaunchedEffect(visible) {
        if (visible && state.isMinimized) state.isMinimized = false
    }
    val placement by DesktopWindowMode.placement.collectAsState()
    LaunchedEffect(placement) { state.placement = placement }
    LaunchedEffect(state) { snapshotFlow { state.placement }.collect(DesktopWindowMode::adopt) }
    val maximized by DesktopWindowMode.maximized.collectAsState()
    LaunchedEffect(maximized) {
        if (DesktopPlatform.isMac) DesktopMacFrame.updateCornerRadius(maximized)
    }
    Window(
        onCloseRequest = { if (DesktopWindowVisibility.onCloseRequest()) exitApplication() },
        visible = visible,
        title = "BitWave",
        icon = painterResource(Res.drawable.logo),
        state = state,
        undecorated = DesktopPlatform.drawsOwnWindowFrame,
        transparent = DesktopWindowBackdrop.available,
        resizable = true,
    ) {
        val composeWindow = window
        val openingSize = remember { state.size }
        LaunchedEffect(composeWindow) {
            DesktopWindowVisibility.attachWindow(composeWindow)
            if (!DesktopWindowBackdrop.available) {
                composeWindow.background = java.awt.Color.BLACK
                composeWindow.contentPane.background = java.awt.Color.BLACK
            } else {
                composeWindow.background = java.awt.Color(0, 0, 0, 0)
                composeWindow.contentPane.background = java.awt.Color(0, 0, 0, 0)
                (composeWindow.contentPane as? javax.swing.JComponent)?.isOpaque = false
                composeWindow.rootPane.isOpaque = false
            }
            val transform = composeWindow.graphicsConfiguration.defaultTransform
            composeWindow.minimumSize = Dimension(
                (MIN_WINDOW_WIDTH_DP * transform.scaleX).roundToInt(),
                (MIN_WINDOW_HEIGHT_DP * transform.scaleY).roundToInt(),
            )
            composeWindow.size = Dimension(
                (openingSize.width.value * transform.scaleX).roundToInt(),
                (openingSize.height.value * transform.scaleY).roundToInt(),
            )
            if (DesktopPlatform.isWindows && DesktopWindowsFrame.install("BitWave")) {
                DesktopWindowBackdrop.apply()
            } else if (DesktopPlatform.isMac && DesktopMacFrame.install(composeWindow)) {
                DesktopWindowBackdrop.apply()
            }
            // Linux: keep the native decorated AWT frame. Compositors such as Niri need the
            // window manager to own resize borders and maximize requests; do not make this
            // window undecorated or emulate maximize in application code.
        }
        val actions = remember {
            DesktopWindowActions(
                minimize = {
                    if (!DesktopWindowsFrame.minimize()) state.isMinimized = true
                },
                toggleMaximize = {
                    if (!DesktopWindowsFrame.toggleMaximize()) {
                        if (DesktopPlatform.isWindows && !DesktopWindowMode.maximized.value) {
                            val screen = composeWindow.graphicsConfiguration.bounds
                            val insets = Toolkit.getDefaultToolkit().getScreenInsets(composeWindow.graphicsConfiguration)
                            composeWindow.maximizedBounds = Rectangle(
                                screen.x + insets.left, screen.y + insets.top,
                                screen.width - insets.left - insets.right,
                                screen.height - insets.top - insets.bottom,
                            )
                        }
                        DesktopWindowMode.toggleMaximized()
                    }
                },
                close = { if (DesktopWindowVisibility.onCloseRequest()) exitApplication() },
            )
        }
        CompositionLocalProvider(
            LocalDesktopWindowActions provides actions,
            LocalDesktopWindowScope provides this,
        ) {
            BitChordDesktopApp()
        }
    }
}

private const val MIN_WINDOW_WIDTH_DP = 900.0
private const val MIN_WINDOW_HEIGHT_DP = 600.0
