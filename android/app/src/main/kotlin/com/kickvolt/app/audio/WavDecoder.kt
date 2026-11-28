package com.kickvolt.app.audio

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.StatFs
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Decodes the first audio track of a file (audio or video) to a 16-bit
 * little-endian interleaved PCM WAV with MediaExtractor + MediaCodec.
 * Output is streamed to disk; memory use is a few codec buffers.
 */
class WavDecoder(
    private val context: Context,
    private val cancelled: AtomicBoolean,
    private val onProgress: (Double) -> Unit,
) {
    fun decode(inputPath: String, outputPath: String): DecodeResult {
        val output = File(outputPath)
        try {
            return decodeInternal(inputPath, output)
        } catch (e: Throwable) {
            output.delete()
            throw mapError(e)
        }
    }

    private fun decodeInternal(inputPath: String, output: File): DecodeResult {
        val extractor = MediaExtractor()
        try {
            try {
                if (inputPath.startsWith("content://")) {
                    extractor.setDataSource(context, Uri.parse(inputPath), null)
                } else {
                    extractor.setDataSource(inputPath)
                }
            } catch (e: Exception) {
                throw FlutterError("unsupported_format", "Can't read this file: ${e.message}")
            }

            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: throw FlutterError("no_audio_track", "This file has no audio track.")
            if (extractor.drmInitData != null) {
                throw FlutterError("drm_protected", "This song is copy-protected.")
            }
            extractor.selectTrack(track)
            val inFormat = extractor.getTrackFormat(track)
            val mime = inFormat.getString(MediaFormat.KEY_MIME)!!
            val durationUs =
                if (inFormat.containsKey(MediaFormat.KEY_DURATION)) inFormat.getLong(MediaFormat.KEY_DURATION) else 0L
            // Gapless metadata: MPEG4Extractor turns an MP4 edit list (or
            // iTunSMPB) into encoder-delay / encoder-padding, in frames.
            // Whether MediaCodec trims them depends on the release and codec
            // (Codec2's AAC decoder on Android 14 does; older/vendor ones may
            // not), so we zero them for the codec and trim exactly once here.
            val encoderDelay = inFormat.getIntegerOrNull(KEY_ENCODER_DELAY)?.coerceAtLeast(0) ?: 0
            val encoderPadding = inFormat.getIntegerOrNull(KEY_ENCODER_PADDING)?.coerceAtLeast(0) ?: 0
            inFormat.setInteger(KEY_ENCODER_DELAY, 0)
            inFormat.setInteger(KEY_ENCODER_PADDING, 0)

            checkFreeSpace(output, inFormat, durationUs)

            val codec = try {
                MediaCodec.createDecoderByType(mime)
            } catch (e: Exception) {
                throw FlutterError("unsupported_format", "No decoder for $mime.")
            }
            // Ask for 16-bit output. Some decoders ignore this and emit float,
            // which is handled below from the actual output format.
            inFormat.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            try {
                codec.configure(inFormat, null, null, 0)
                codec.start()
            } catch (e: Exception) {
                codec.release()
                throw FlutterError("unsupported_format", "Can't decode $mime: ${e.message}")
            }

            output.parentFile?.mkdirs()
            return FileOutputStream(output).channel.use { channel ->
                try {
                    pump(extractor, codec, channel, durationUs, mime, encoderDelay, encoderPadding)
                } finally {
                    try { codec.stop() } catch (_: Exception) {}
                    codec.release()
                }
            }
        } finally {
            extractor.release()
        }
    }

    private fun pump(
        extractor: MediaExtractor,
        codec: MediaCodec,
        channel: FileChannel,
        durationUs: Long,
        mime: String,
        encoderDelay: Int,
        encoderPadding: Int,
    ): DecodeResult {
        channel.write(ByteBuffer.allocate(WAV_HEADER_BYTES))

        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        var sampleRate = 0
        var srcChannels = 0
        var outChannels = 0
        var isFloat = false
        var dataBytes = 0L
        var decodedFrames = 0L
        var framesToSkip = encoderDelay.toLong()
        var lastReported = -1.0
        var scratch = ByteBuffer.allocate(0).order(ByteOrder.LITTLE_ENDIAN)

        fun readFormat(f: MediaFormat) {
            if (sampleRate != 0) return // keep the first format; the timebase can't change mid-file
            sampleRate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            srcChannels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            outChannels = srcChannels.coerceIn(1, 2)
            isFloat = f.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                f.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
        }

        while (!outputDone) {
            if (cancelled.get()) throw FlutterError("cancelled", "Import cancelled.")

            if (!inputDone) {
                val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inIndex >= 0) {
                    val buf = codec.getInputBuffer(inIndex)!!
                    val n = extractor.readSampleData(buf, 0)
                    if (n < 0) {
                        codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inIndex, 0, n, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }

            val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                readFormat(codec.outputFormat)
            } else if (outIndex >= 0) {
                if (sampleRate == 0) readFormat(codec.getOutputFormat(outIndex))
                val buf = codec.getOutputBuffer(outIndex)
                if (buf != null && info.size > 0) {
                    buf.position(info.offset)
                    buf.limit(info.offset + info.size)
                    val src = buf.slice().order(ByteOrder.nativeOrder())
                    val bytesPerSample = if (isFloat) 4 else 2
                    val frames = info.size / (bytesPerSample * srcChannels)
                    decodedFrames += frames
                    // Drop the encoder delay at the start.
                    val skip = minOf(framesToSkip, frames.toLong()).toInt()
                    framesToSkip -= skip
                    val needed = (frames - skip) * outChannels * 2
                    if (scratch.capacity() < needed) {
                        scratch = ByteBuffer.allocate(needed).order(ByteOrder.LITTLE_ENDIAN)
                    }
                    scratch.clear()
                    // >2 channels: keep the first two (front left/right).
                    for (f in skip until frames) {
                        for (c in 0 until outChannels) {
                            val i = f * srcChannels + c
                            val s = if (isFloat) {
                                (src.getFloat(i * 4).coerceIn(-1f, 1f) * 32767f).toInt().toShort()
                            } else {
                                src.getShort(i * 2)
                            }
                            scratch.putShort(s)
                        }
                    }
                    scratch.flip()
                    while (scratch.hasRemaining()) channel.write(scratch)
                    dataBytes += needed
                }
                codec.releaseOutputBuffer(outIndex, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true

                if (durationUs > 0) {
                    val p = (info.presentationTimeUs.toDouble() / durationUs).coerceIn(0.0, 1.0)
                    if (p - lastReported >= 0.01) {
                        lastReported = p
                        onProgress(p)
                    }
                }
            }
        }

        // Drop the encoder padding at the end (never below one frame).
        val frameBytes = 2L * maxOf(outChannels, 1)
        val padBytes = minOf(encoderPadding.toLong() * frameBytes, maxOf(dataBytes - frameBytes, 0L))
        if (padBytes > 0) {
            dataBytes -= padBytes
            channel.truncate(WAV_HEADER_BYTES + dataBytes)
        }
        Log.i(
            TAG,
            "decoded $mime: $decodedFrames frames, encoder-delay=$encoderDelay " +
                "encoder-padding=$encoderPadding, wrote ${dataBytes / frameBytes} frames",
        )

        if (sampleRate == 0 || dataBytes == 0L) {
            throw FlutterError("decode_failed", "The decoder produced no audio.")
        }
        channel.position(0)
        channel.write(wavHeader(sampleRate, outChannels, dataBytes))
        onProgress(1.0)
        return DecodeResult(
            sampleRate = sampleRate.toLong(),
            channels = outChannels.toLong(),
            frameCount = dataBytes / (2L * outChannels),
        )
    }

    private fun checkFreeSpace(output: File, format: MediaFormat, durationUs: Long) {
        if (durationUs <= 0) return
        val rate = format.getIntegerOrNull(MediaFormat.KEY_SAMPLE_RATE) ?: 48000
        val ch = (format.getIntegerOrNull(MediaFormat.KEY_CHANNEL_COUNT) ?: 2).coerceIn(1, 2)
        val needed = durationUs * rate / 1_000_000L * ch * 2 + SPACE_MARGIN
        if (freeBytes(output.path) < needed) {
            throw FlutterError("disk_full", "Not enough free space to import this song.", needed)
        }
    }

    private fun mapError(e: Throwable): Throwable = when {
        e is FlutterError -> e
        e is IOException && isNoSpace(e) -> FlutterError("disk_full", "Your phone ran out of space.")
        e is MediaCodec.CodecException -> FlutterError("decode_failed", e.message)
        e is IllegalStateException -> FlutterError("decode_failed", e.message)
        else -> FlutterError("decode_failed", e.message ?: e.toString())
    }

    private fun isNoSpace(e: IOException): Boolean {
        val m = e.message ?: return false
        return m.contains("ENOSPC") || m.contains("No space left", ignoreCase = true)
    }

    private fun MediaFormat.getIntegerOrNull(key: String): Int? =
        if (containsKey(key)) getInteger(key) else null

    companion object {
        private const val TAG = "KvWavDecoder"
        private const val TIMEOUT_US = 10_000L

        // MediaFormat.KEY_ENCODER_DELAY / KEY_ENCODER_PADDING (API 30). The
        // extractor sets the same string keys on older releases too.
        private const val KEY_ENCODER_DELAY = "encoder-delay"
        private const val KEY_ENCODER_PADDING = "encoder-padding"
        private const val WAV_HEADER_BYTES = 44
        private const val SPACE_MARGIN = 20L * 1024 * 1024

        fun freeBytes(path: String): Long {
            var f: File? = File(path)
            while (f != null && !f.exists()) f = f.parentFile
            return StatFs((f ?: File("/")).path).availableBytes
        }

        /** Canonical 44-byte PCM WAV header (16-bit). */
        fun wavHeader(sampleRate: Int, channels: Int, dataBytes: Long): ByteBuffer {
            val blockAlign = channels * 2
            return ByteBuffer.allocate(WAV_HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN).apply {
                put("RIFF".toByteArray(Charsets.US_ASCII))
                putInt((36 + dataBytes).toInt())
                put("WAVE".toByteArray(Charsets.US_ASCII))
                put("fmt ".toByteArray(Charsets.US_ASCII))
                putInt(16)
                putShort(1) // PCM
                putShort(channels.toShort())
                putInt(sampleRate)
                putInt(sampleRate * blockAlign)
                putShort(blockAlign.toShort())
                putShort(16)
                put("data".toByteArray(Charsets.US_ASCII))
                putInt(dataBytes.toInt())
                flip()
            }
        }
    }
}
