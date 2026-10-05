package com.isan.isan_flutter

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * ════════════════════════════════════════════════════════════════════
 *  PEMUTAR INTRO ISAN — DENGAN DECODER PERANGKAT LUNAK
 * ════════════════════════════════════════════════════════════════════
 *
 *  KENAPA PEMUTAR SENDIRI, BUKAN video_player?
 *  ──────────────────────────────────────────
 *  Paket `video_player` membuat ExoPlayer TANPA memberi cara mengatur
 *  pabrik perendernya (lihat TextureVideoPlayer.java baris 60-82:
 *  `new ExoPlayer.Builder(context)` lalu langsung `.build()`).
 *
 *  Padahal HP ini (Infinix X655C / MediaTek MT6765 / Android 10)
 *  punya decoder perangkat keras yang RUSAK:
 *
 *      Decoder init failed: OMX.MTK.VIDEO.DECODER.AVC
 *      OMXNodeInstance: !!! Observer died
 *
 *  Semua ukuran video gagal di sana — sudah diuji 720x1280@60fps,
 *  854x480@30fps, dan 320x240@24fps. Jadi bukan soal berkas videonya.
 *
 *  Karena itu pemutar intro ini dibuat SENDIRI di sisi Android, supaya
 *  bisa memakai dua opsi resmi media3 yang menyelesaikan masalah itu:
 *
 *      setEnableDecoderFallback(true)
 *      setMediaCodecSelector(MediaCodecSelector.PREFER_SOFTWARE)
 *
 *  Pemutar ini HANYA dipakai untuk intro. Pemutar film/series milik
 *  aplikasi (Hydrax/WebView) TIDAK disentuh sama sekali.
 */
class PemutarIntroFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return PemutarIntroView(context, messenger, viewId)
    }
}

class PemutarIntroView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView {

    private val TAG = "ISAN_INTRO"

    private val wadah = FrameLayout(context)
    private val playerView = PlayerView(context)
    private var player: ExoPlayer? = null
    private val kanal = MethodChannel(messenger, "isan/intro_video_$viewId")

    init {
        wadah.addView(
            playerView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        // Latar hitam supaya tidak ada kedipan saat video dimuat.
        wadah.setBackgroundColor(android.graphics.Color.BLACK)

        kanal.setMethodCallHandler { call, result ->
            when (call.method) {
                "putar" -> {
                    val jalurAset = call.argument<String>("aset")
                    val modeGagal = call.argument<Boolean>("paksaSoftware") ?: true
                    try {
                        putarVideo(jalurAset, modeGagal)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "gagal memutar: ${e.message}", e)
                        result.error("GAGAL_PUTAR", e.message, null)
                    }
                }
                "berhenti" -> {
                    player?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Buat ExoPlayer dengan pabrik perender yang MENDAHULUKAN
     * decoder perangkat lunak, plus fallback otomatis.
     */
    private fun putarVideo(jalurAset: String?, paksaSoftware: Boolean) {
        player?.release()

        val pabrik = DefaultRenderersFactory(wadah.context)
            // Kalau kodek pertama gagal, coba kodek berikutnya.
            .setEnableDecoderFallback(true)

        if (paksaSoftware) {
            // Dahulukan kodek perangkat lunak (murni CPU), yang tidak
            // bergantung pada chipset MediaTek yang rusak.
            pabrik.setMediaCodecSelector(MediaCodecSelector.PREFER_SOFTWARE)
            Log.d(TAG, "memakai PREFER_SOFTWARE + fallback aktif")
        }

        val exo = ExoPlayer.Builder(wadah.context, pabrik).build()
        player = exo

        playerView.player = exo
        playerView.useController = false
        playerView.setShutterBackgroundColor(android.graphics.Color.BLACK)

        // Aset dibaca dari bundle Flutter lewat kunci asetnya.
        val kunci = wadah.context.assets.let {
            "flutter_assets/" + (jalurAset ?: "assets/video/isan_intro.mp4")
        }
        Log.d(TAG, "memuat aset: $kunci")

        exo.setMediaItem(MediaItem.fromUri("asset:///$kunci"))
        exo.repeatMode = Player.REPEAT_MODE_OFF
        exo.volume = 0f
        exo.prepare()
        exo.playWhenReady = true
    }

    override fun getView(): View = wadah

    override fun dispose() {
        player?.release()
        player = null
    }
}
