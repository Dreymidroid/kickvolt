package com.kickvolt.app.audio

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.view.Surface
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Encodes the M7 guide video: H.264 (constant [GuideVideoSpec.fps]) with the
 * guide WAV as AAC, muxed into an MPEG-4 file.
 *
 * Input path: **Surface input + EGL/GLES** (the AOSP/Grafika encoder pattern).
 * The encoder's input [Surface] gets an EGL window surface; every frame is
 * drawn with GLES and stamped with [EGLExt.eglPresentationTimeANDROID] set to
 * exactly `frameIndex * 1e9 / fps` ns before [EGL14.eglSwapBuffers], so the
 * timing comes only from the frame index (never from a clock, never from
 * `Surface.lockCanvas`). Frame looks are drawn once into a [Bitmap] with
 * [Canvas] and uploaded as a texture only when the look changes.
 *
 * Audio: the guide WAV is AAC-encoded with [M4aEncoder] (M6's code path) into
 * a temporary .m4a, whose samples are copied into the muxer with their own
 * presentation times, interleaved with the video.
 */
class GuideVideoEncoder(
    private val cancelled: AtomicBoolean,
    private val onProgress: (Double) -> Unit,
) {
    fun encode(spec: GuideVideoSpec): MediaInfo {
        val outFile = File(spec.outPath)
        val tmpAudio = File(outFile.parentFile, ".${outFile.name}.audio.m4a")
        try {
            return encodeInternal(spec, outFile, tmpAudio)
        } catch (e: Throwable) {
            outFile.delete()
            throw mapError(e)
        } finally {
            tmpAudio.delete()
        }
    }

    private fun checkCancelled() {
        if (cancelled.get()) throw FlutterError("cancelled", "Export cancelled.")
    }

    private fun encodeInternal(spec: GuideVideoSpec, outFile: File, tmpAudio: File): MediaInfo {
        val fps = spec.fps.toInt()
        val totalFrames = spec.totalFrames.toInt()
        val flashFrames = IntArray(spec.flashFrames.size) { spec.flashFrames[it].toInt() }
        val beatNumbers = IntArray(spec.beatNumbers.size) { spec.beatNumbers[it].toInt() }
        if (fps <= 0 || totalFrames < 0 || flashFrames.size != beatNumbers.size) {
            throw FlutterError("encode_failed", "Invalid guide video spec.")
        }
        if (!File(spec.audioWavPath).exists()) {
            throw FlutterError("encode_failed", "Guide track WAV is missing.")
        }
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) outFile.delete()

        // 1. Guide track -> AAC (M6 encoder), 0..10% of the progress.
        M4aEncoder(cancelled) { p -> onProgress(p * AUDIO_SHARE) }
            .encode(spec.audioWavPath, tmpAudio.path, spec.audioBitrate.toInt())
        checkCancelled()

        val extractor = MediaExtractor()
        var encoder: MediaCodec? = null
        var inputSurface: Surface? = null
        var egl: EglSurfaceHolder? = null
        var renderer: FrameRenderer? = null
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var finished = false
        try {
            extractor.setDataSource(tmpAudio.path)
            val audioTrack = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: throw FlutterError("encode_failed", "AAC encode produced no audio track.")
            extractor.selectTrack(audioTrack)
            val audioFormat = extractor.getTrackFormat(audioTrack)
            val audioMaxInput = if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            } else {
                64 * 1024
            }

            // 2. H.264 encoder with Surface input; fall back to 720 x 1280.
            val (codec, width, height) = createVideoEncoder(
                spec.width.toInt(),
                spec.height.toInt(),
                fps,
                spec.videoBitrate.toInt(),
            )
            encoder = codec
            val surface = codec.createInputSurface()
            inputSurface = surface
            codec.start()
            val eglHolder = EglSurfaceHolder(surface)
            egl = eglHolder
            val frameRenderer = FrameRenderer(width, height)
            renderer = frameRenderer

            muxer = MediaMuxer(outFile.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var videoTrackIndex = -1
            var audioTrackIndex = -1
            val audioBuf = ByteBuffer.allocateDirect(audioMaxInput)
            val audioInfo = MediaCodec.BufferInfo()
            var audioDone = false

            // Writes audio samples up to [untilUs] (all if null), keeping the
            // two tracks interleaved in the file.
            fun writeAudioUntil(untilUs: Long?) {
                val m = muxer ?: return
                while (!audioDone) {
                    val t = extractor.sampleTime
                    if (t < 0) {
                        audioDone = true
                        return
                    }
                    if (untilUs != null && t > untilUs) return
                    audioBuf.clear()
                    val size = extractor.readSampleData(audioBuf, 0)
                    if (size < 0) {
                        audioDone = true
                        return
                    }
                    audioInfo.set(
                        0,
                        size,
                        t,
                        if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) {
                            MediaCodec.BUFFER_FLAG_KEY_FRAME
                        } else {
                            0
                        },
                    )
                    m.writeSampleData(audioTrackIndex, audioBuf, audioInfo)
                    extractor.advance()
                }
            }

            val info = MediaCodec.BufferInfo()
            // Drains encoded video into the muxer. With [endOfStream] it
            // waits for the encoder's EOS flag.
            fun drain(endOfStream: Boolean) {
                val enc = encoder ?: return
                val m = muxer ?: return
                var idleTries = 0
                while (true) {
                    checkCancelled()
                    val index = enc.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0L)
                    when {
                        index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            if (!endOfStream) return
                            if (++idleTries > MAX_EOS_WAIT_TRIES) {
                                throw FlutterError("encode_failed", "Video encoder never finished.")
                            }
                        }
                        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            if (muxerStarted) {
                                throw FlutterError("encode_failed", "Video format changed twice.")
                            }
                            videoTrackIndex = m.addTrack(enc.outputFormat)
                            audioTrackIndex = m.addTrack(audioFormat)
                            m.start()
                            muxerStarted = true
                        }
                        index >= 0 -> {
                            val buf = enc.getOutputBuffer(index)
                            if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                                info.size = 0
                            }
                            if (buf != null && info.size > 0) {
                                if (!muxerStarted) {
                                    throw FlutterError("encode_failed", "Video data before format.")
                                }
                                buf.position(info.offset)
                                buf.limit(info.offset + info.size)
                                m.writeSampleData(videoTrackIndex, buf, info)
                                writeAudioUntil(info.presentationTimeUs)
                            }
                            enc.releaseOutputBuffer(index, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                        }
                    }
                }
            }

            // 3. Frames. Frame k is presented at exactly k / fps.
            var flashIdx = -1
            var lastReported = -1.0
            for (k in 0 until totalFrames) {
                checkCancelled()
                while (flashIdx + 1 < flashFrames.size && flashFrames[flashIdx + 1] <= k) {
                    flashIdx++
                }
                val look = if (flashIdx < 0) {
                    FrameLook.BLACK
                } else {
                    val f = flashFrames[flashIdx]
                    val n = beatNumbers[flashIdx]
                    when (k) {
                        f -> FrameLook(FrameLook.KIND_FLASH, n)
                        f + 1 -> FrameLook(FrameLook.KIND_AFTER, n)
                        else -> FrameLook(FrameLook.KIND_DIM, n)
                    }
                }
                drain(false)
                frameRenderer.draw(look)
                eglHolder.setPresentationTime(k.toLong() * 1_000_000_000L / fps)
                eglHolder.swapBuffers()
                val p = (k + 1).toDouble() / totalFrames
                if (p - lastReported >= 0.01) {
                    lastReported = p
                    onProgress(AUDIO_SHARE + p * (1.0 - AUDIO_SHARE))
                }
            }
            codec.signalEndOfInputStream()
            drain(true)
            if (!muxerStarted) {
                // No frames at all (empty song): still need valid tracks.
                throw FlutterError("encode_failed", "No video frames were encoded.")
            }
            writeAudioUntil(null)
            finished = true
        } finally {
            try { renderer?.release() } catch (_: Exception) {}
            try { egl?.release() } catch (_: Exception) {}
            try { encoder?.stop() } catch (_: Exception) {}
            try { encoder?.release() } catch (_: Exception) {}
            try { inputSurface?.release() } catch (_: Exception) {}
            try {
                if (muxerStarted) muxer?.stop()
            } catch (e: Exception) {
                // Only a failed stop of a finished file is an error; after an
                // earlier failure or cancel, keep that error.
                if (finished) throw e
            } finally {
                try { muxer?.release() } catch (_: Exception) {}
                extractor.release()
            }
        }

        onProgress(1.0)
        return M4aEncoder.probeMedia(outFile.path)
    }

    private fun videoFormat(width: Int, height: Int, fps: Int, bitrate: Int): MediaFormat =
        MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

    /** Returns a configured (not started) encoder and the size it accepted. */
    private fun createVideoEncoder(
        width: Int,
        height: Int,
        fps: Int,
        bitrate: Int,
    ): Triple<MediaCodec, Int, Int> {
        val sizes = linkedSetOf(width to height, FALLBACK_WIDTH to FALLBACK_HEIGHT)
        val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        var lastError: Exception? = null
        for ((w, h) in sizes) {
            val format = videoFormat(w, h, fps, bitrate)
            val name = codecs.findEncoderForFormat(format) ?: continue
            val codec = try {
                MediaCodec.createByCodecName(name)
            } catch (e: Exception) {
                lastError = e
                continue
            }
            try {
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                return Triple(codec, w, h)
            } catch (e: Exception) {
                lastError = e
                codec.release()
            }
        }
        throw FlutterError(
            "encode_failed",
            "No H.264 encoder accepted ${width}x$height or " +
                "${FALLBACK_WIDTH}x$FALLBACK_HEIGHT: ${lastError?.message}",
        )
    }

    private fun mapError(e: Throwable): Throwable = when {
        e is FlutterError -> e
        else -> {
            val msg = e.message ?: e.toString()
            if (e is IOException && (msg.contains("ENOSPC") || msg.contains("No space left", true))) {
                FlutterError("disk_full", "Your phone ran out of space.")
            } else if (msg.contains("ENOSPC") || msg.contains("No space left", ignoreCase = true)) {
                FlutterError("disk_full", "Your phone ran out of space.")
            } else {
                FlutterError("encode_failed", msg)
            }
        }
    }

    /** What one frame shows. */
    private data class FrameLook(val kind: Int, val number: Int) {
        companion object {
            const val KIND_BLACK = 0
            const val KIND_FLASH = 1 // white, number in black
            const val KIND_AFTER = 2 // black, number in white
            const val KIND_DIM = 3 // black, number in white at 40%
            val BLACK = FrameLook(KIND_BLACK, 0)
        }
    }

    /** EGL window surface on the encoder's input Surface (EGL14 / EGLExt). */
    private class EglSurfaceHolder(surface: Surface) {
        private val display: EGLDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        private val context: EGLContext
        private val eglSurface: EGLSurface

        init {
            if (display == EGL14.EGL_NO_DISPLAY) eglFail("eglGetDisplay")
            val version = IntArray(2)
            if (!EGL14.eglInitialize(display, version, 0, version, 1)) eglFail("eglInitialize")
            val attribs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL_RECORDABLE_ANDROID, 1,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val count = IntArray(1)
            if (!EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, count, 0) ||
                count[0] == 0
            ) {
                eglFail("eglChooseConfig")
            }
            val config = configs[0]!!
            context = EGL14.eglCreateContext(
                display,
                config,
                EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE),
                0,
            )
            if (context == EGL14.EGL_NO_CONTEXT) eglFail("eglCreateContext")
            eglSurface = EGL14.eglCreateWindowSurface(
                display,
                config,
                surface,
                intArrayOf(EGL14.EGL_NONE),
                0,
            )
            if (eglSurface == EGL14.EGL_NO_SURFACE) eglFail("eglCreateWindowSurface")
            if (!EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)) {
                eglFail("eglMakeCurrent")
            }
        }

        fun setPresentationTime(nanos: Long) {
            if (!EGLExt.eglPresentationTimeANDROID(display, eglSurface, nanos)) {
                eglFail("eglPresentationTimeANDROID")
            }
        }

        fun swapBuffers() {
            if (!EGL14.eglSwapBuffers(display, eglSurface)) eglFail("eglSwapBuffers")
        }

        fun release() {
            EGL14.eglMakeCurrent(
                display,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT,
            )
            EGL14.eglDestroySurface(display, eglSurface)
            EGL14.eglDestroyContext(display, context)
            EGL14.eglReleaseThread()
            EGL14.eglTerminate(display)
        }

        private fun eglFail(what: String): Nothing =
            throw FlutterError(
                "encode_failed",
                "$what failed: 0x${Integer.toHexString(EGL14.eglGetError())}",
            )
    }

    /**
     * Draws frame looks with GLES 2: a full-screen textured quad whose texture
     * is a [Bitmap] drawn with [Canvas], re-uploaded only when the look
     * changes. Plain black frames are just a clear.
     */
    private class FrameRenderer(private val width: Int, private val height: Int) {
        private val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        private val canvas = Canvas(bitmap)
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        private val program: Int
        private val posLoc: Int
        private val texLoc: Int
        private val samplerLoc: Int
        private val texture: Int
        private var textureAllocated = false
        private var uploaded: FrameLook? = null
        private val quad: FloatBuffer

        init {
            GLES20.glViewport(0, 0, width, height)
            program = linkProgram(VERTEX_SHADER, FRAGMENT_SHADER)
            posLoc = GLES20.glGetAttribLocation(program, "aPos")
            texLoc = GLES20.glGetAttribLocation(program, "aTex")
            samplerLoc = GLES20.glGetUniformLocation(program, "uTex")
            val ids = IntArray(1)
            GLES20.glGenTextures(1, ids, 0)
            texture = ids[0]
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            // x, y, s, t. Bitmap row 0 (top) is texture t = 0.
            val verts = floatArrayOf(
                -1f, -1f, 0f, 1f,
                1f, -1f, 1f, 1f,
                -1f, 1f, 0f, 0f,
                1f, 1f, 1f, 0f,
            )
            quad = ByteBuffer.allocateDirect(verts.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .apply { put(verts); position(0) }
        }

        fun draw(look: FrameLook) {
            if (look.kind == FrameLook.KIND_BLACK) {
                GLES20.glClearColor(0f, 0f, 0f, 1f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                return
            }
            if (look != uploaded) {
                paintLook(look)
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
                if (textureAllocated) {
                    GLUtils.texSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, bitmap)
                } else {
                    GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
                    textureAllocated = true
                }
                uploaded = look
            }
            GLES20.glUseProgram(program)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
            GLES20.glUniform1i(samplerLoc, 0)
            quad.position(0)
            GLES20.glVertexAttribPointer(posLoc, 2, GLES20.GL_FLOAT, false, 16, quad)
            GLES20.glEnableVertexAttribArray(posLoc)
            quad.position(2)
            GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 16, quad)
            GLES20.glEnableVertexAttribArray(texLoc)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GLES20.glDisableVertexAttribArray(posLoc)
            GLES20.glDisableVertexAttribArray(texLoc)
            val err = GLES20.glGetError()
            if (err != GLES20.GL_NO_ERROR) {
                throw FlutterError("encode_failed", "GLES error 0x${Integer.toHexString(err)}")
            }
        }

        private fun paintLook(look: FrameLook) {
            val flash = look.kind == FrameLook.KIND_FLASH
            canvas.drawColor(if (flash) Color.WHITE else Color.BLACK)
            paint.color = when (look.kind) {
                FrameLook.KIND_FLASH -> Color.BLACK
                FrameLook.KIND_AFTER -> Color.WHITE
                else -> Color.argb(DIM_ALPHA, 255, 255, 255)
            }
            val text = look.number.toString()
            // ~40% of the frame height, shrunk so the number fits 90% of the
            // width (portrait frames are narrower than three 40% digits).
            paint.textSize = height * 0.4f
            val measured = paint.measureText(text)
            val maxWidth = width * 0.9f
            if (measured > maxWidth) paint.textSize *= maxWidth / measured
            val fm = paint.fontMetrics
            val baseline = height / 2f - (fm.ascent + fm.descent) / 2f
            canvas.drawText(text, width / 2f, baseline, paint)
        }

        fun release() {
            GLES20.glDeleteTextures(1, intArrayOf(texture), 0)
            GLES20.glDeleteProgram(program)
            bitmap.recycle()
        }

        private fun linkProgram(vs: String, fs: String): Int {
            val v = compile(GLES20.GL_VERTEX_SHADER, vs)
            val f = compile(GLES20.GL_FRAGMENT_SHADER, fs)
            val p = GLES20.glCreateProgram()
            GLES20.glAttachShader(p, v)
            GLES20.glAttachShader(p, f)
            GLES20.glLinkProgram(p)
            val status = IntArray(1)
            GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, status, 0)
            GLES20.glDeleteShader(v)
            GLES20.glDeleteShader(f)
            if (status[0] == 0) {
                val log = GLES20.glGetProgramInfoLog(p)
                GLES20.glDeleteProgram(p)
                throw FlutterError("encode_failed", "GL link failed: $log")
            }
            return p
        }

        private fun compile(type: Int, src: String): Int {
            val s = GLES20.glCreateShader(type)
            GLES20.glShaderSource(s, src)
            GLES20.glCompileShader(s)
            val status = IntArray(1)
            GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, status, 0)
            if (status[0] == 0) {
                val log = GLES20.glGetShaderInfoLog(s)
                GLES20.glDeleteShader(s)
                throw FlutterError("encode_failed", "GL shader failed: $log")
            }
            return s
        }
    }

    companion object {
        private const val TIMEOUT_US = 10_000L
        private const val AUDIO_SHARE = 0.1
        private const val MAX_EOS_WAIT_TRIES = 1000 // x 10 ms
        private const val FALLBACK_WIDTH = 720
        private const val FALLBACK_HEIGHT = 1280

        /** 40% white over black. */
        private const val DIM_ALPHA = 102

        /** `EGL_RECORDABLE_ANDROID` (EGLExt constant is API 26+; minSdk is 24). */
        private const val EGL_RECORDABLE_ANDROID = 0x3142

        private const val VERTEX_SHADER = """
            attribute vec4 aPos;
            attribute vec2 aTex;
            varying vec2 vTex;
            void main() {
                gl_Position = aPos;
                vTex = aTex;
            }
        """

        private const val FRAGMENT_SHADER = """
            precision mediump float;
            varying vec2 vTex;
            uniform sampler2D uTex;
            void main() {
                gl_FragColor = texture2D(uTex, vTex);
            }
        """
    }
}
