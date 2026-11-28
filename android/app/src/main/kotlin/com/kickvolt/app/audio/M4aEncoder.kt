package com.kickvolt.app.audio

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Encodes a 16-bit little-endian PCM WAV file to AAC-LC in an MPEG-4 container
 * (.m4a) using [MediaCodec] and [MediaMuxer], preserving sample rate and
 * channel count.
 */
class M4aEncoder(
    private val cancelled: AtomicBoolean,
    private val onProgress: (Double) -> Unit,
) {
    fun encode(wavPath: String, outPath: String, bitrate: Int): MediaInfo {
        val outFile = File(outPath)
        try {
            return encodeInternal(File(wavPath), outFile, bitrate)
        } catch (e: Throwable) {
            outFile.delete()
            throw mapError(e)
        }
    }

    private fun encodeInternal(wavFile: File, outFile: File, bitrate: Int): MediaInfo {
        if (!wavFile.exists()) {
            throw FlutterError("encode_failed", "Source WAV file is missing.")
        }
        val wav = readWavHeader(wavFile)
        val bytesPerFrame = wav.channels * 2
        val totalFrames = wav.dataBytes / bytesPerFrame

        val format = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            wav.sampleRate,
            wav.channels,
        ).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, CHUNK_BYTES)
        }

        val codec = try {
            MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        } catch (e: Exception) {
            throw FlutterError("encode_failed", "No AAC encoder available: ${e.message}")
        }

        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
        } catch (e: Exception) {
            codec.release()
            throw FlutterError("encode_failed", "AAC encoder refused ${wav.sampleRate} Hz / ${wav.channels} ch: ${e.message}")
        }

        outFile.parentFile?.mkdirs()
        if (outFile.exists()) outFile.delete()

        val muxer = try {
            MediaMuxer(outFile.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        } catch (e: Exception) {
            try { codec.stop() } catch (_: Exception) {}
            codec.release()
            throw mapError(e)
        }

        var muxerStarted = false
        var trackIndex = -1

        try {
            FileInputStream(wavFile).channel.use { channel ->
                channel.position(wav.dataOffset)
                val readBuf = ByteBuffer.allocate(CHUNK_BYTES)
                val info = MediaCodec.BufferInfo()
                var framesFed = 0L
                var bytesRemaining = wav.dataBytes
                var inputDone = false
                var outputDone = false
                var lastReported = -1.0

                while (!outputDone) {
                    if (cancelled.get()) {
                        throw FlutterError("cancelled", "Export cancelled.")
                    }

                    if (!inputDone) {
                        val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                        if (inIndex >= 0) {
                            val inBuf = codec.getInputBuffer(inIndex)!!
                            inBuf.clear()
                            val maxRead = minOf(
                                inBuf.remaining().toLong(),
                                bytesRemaining,
                                CHUNK_BYTES.toLong(),
                            ).toInt()
                            // Align to whole frames.
                            val alignedMax = (maxRead / bytesPerFrame) * bytesPerFrame
                            if (alignedMax <= 0 || bytesRemaining <= 0L) {
                                val ptsUs = framesFed * 1_000_000L / wav.sampleRate
                                codec.queueInputBuffer(
                                    inIndex,
                                    0,
                                    0,
                                    ptsUs,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputDone = true
                            } else {
                                readBuf.clear()
                                readBuf.limit(alignedMax)
                                val n = channel.read(readBuf)
                                if (n <= 0) {
                                    val ptsUs = framesFed * 1_000_000L / wav.sampleRate
                                    codec.queueInputBuffer(
                                        inIndex,
                                        0,
                                        0,
                                        ptsUs,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                    )
                                    inputDone = true
                                } else {
                                    val alignedN = (n / bytesPerFrame) * bytesPerFrame
                                    readBuf.flip()
                                    readBuf.limit(alignedN)
                                    inBuf.put(readBuf)
                                    val ptsUs = framesFed * 1_000_000L / wav.sampleRate
                                    codec.queueInputBuffer(inIndex, 0, alignedN, ptsUs, 0)
                                    framesFed += alignedN / bytesPerFrame
                                    bytesRemaining -= alignedN
                                }
                            }
                        }
                    }

                    val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (muxerStarted) {
                            throw FlutterError("encode_failed", "Encoder output format changed twice.")
                        }
                        trackIndex = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    } else if (outIndex >= 0) {
                        val outBuf = codec.getOutputBuffer(outIndex)
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                            info.size = 0
                        }
                        if (outBuf != null && info.size > 0) {
                            if (!muxerStarted) {
                                trackIndex = muxer.addTrack(codec.outputFormat)
                                muxer.start()
                                muxerStarted = true
                            }
                            outBuf.position(info.offset)
                            outBuf.limit(info.offset + info.size)
                            muxer.writeSampleData(trackIndex, outBuf, info)
                        }
                        codec.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                        if (totalFrames > 0) {
                            val p = (framesFed.toDouble() / totalFrames).coerceIn(0.0, 1.0)
                            if (p - lastReported >= 0.01) {
                                lastReported = p
                                onProgress(p)
                            }
                        }
                    }
                }
            }
        } finally {
            try { codec.stop() } catch (_: Exception) {}
            codec.release()
            try {
                if (muxerStarted) muxer.stop()
            } finally {
                muxer.release()
            }
        }

        onProgress(1.0)
        return probeMedia(outFile.path)
    }

    private fun mapError(e: Throwable): Throwable = when {
        e is FlutterError -> e
        e is IOException && isNoSpace(e) -> FlutterError("disk_full", "Your phone ran out of space.")
        else -> {
            val msg = e.message ?: e.toString()
            if (msg.contains("ENOSPC") || msg.contains("No space left", ignoreCase = true)) {
                FlutterError("disk_full", "Your phone ran out of space.")
            } else {
                FlutterError("encode_failed", msg)
            }
        }
    }

    private fun isNoSpace(e: IOException): Boolean {
        val m = e.message ?: return false
        return m.contains("ENOSPC") || m.contains("No space left", ignoreCase = true)
    }

    private data class WavHeader(
        val sampleRate: Int,
        val channels: Int,
        val bitsPerSample: Int,
        val dataOffset: Long,
        val dataBytes: Long,
    )

    companion object {
        private const val TIMEOUT_US = 10_000L
        private const val CHUNK_BYTES = 16_384

        private fun readWavHeader(file: File): WavHeader {
            FileInputStream(file).channel.use { ch ->
                val fileLen = ch.size()
                val riff = ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN)
                if (ch.read(riff) < 12) throw FlutterError("encode_failed", "Truncated WAV header.")
                riff.flip()
                val riffTag = ByteArray(4).also { riff.get(it) }.toString(Charsets.US_ASCII)
                riff.int // size
                val waveTag = ByteArray(4).also { riff.get(it) }.toString(Charsets.US_ASCII)
                if (riffTag != "RIFF" || waveTag != "WAVE") {
                    throw FlutterError("encode_failed", "Not a RIFF/WAVE file.")
                }

                var pos = 12L
                var sampleRate = 0
                var channels = 0
                var bits = 0
                val head = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN)
                while (pos + 8 <= fileLen) {
                    ch.position(pos)
                    head.clear()
                    if (ch.read(head) < 8) break
                    head.flip()
                    val id = ByteArray(4).also { head.get(it) }.toString(Charsets.US_ASCII)
                    val size = head.int.toLong() and 0xFFFF_FFFFL
                    val body = pos + 8
                    if (id == "fmt ") {
                        val fmt = ByteBuffer.allocate(16).order(ByteOrder.LITTLE_ENDIAN)
                        if (ch.read(fmt) < 16) throw FlutterError("encode_failed", "Truncated fmt chunk.")
                        fmt.flip()
                        val formatTag = fmt.short.toInt() and 0xFFFF
                        if (formatTag != 1 && formatTag != 0xFFFE) {
                            throw FlutterError("encode_failed", "Unsupported WAV format tag $formatTag")
                        }
                        channels = fmt.short.toInt() and 0xFFFF
                        sampleRate = fmt.int
                        fmt.int // byteRate
                        fmt.short // blockAlign
                        bits = fmt.short.toInt() and 0xFFFF
                    } else if (id == "data") {
                        if (sampleRate <= 0 || channels <= 0 || bits != 16) {
                            throw FlutterError("encode_failed", "Expected 16-bit PCM WAV.")
                        }
                        val dataBytes = minOf(size, fileLen - body)
                        return WavHeader(sampleRate, channels, bits, body, dataBytes)
                    }
                    pos = body + size + (if (size % 2L == 1L) 1L else 0L)
                }
                throw FlutterError("encode_failed", "No data chunk in WAV.")
            }
        }

        /**
         * Probes duration and audio track format of [path] via WAV header or
         * [MediaExtractor].
         */
        fun probeMedia(path: String): MediaInfo {
            val file = File(path)
            if (!file.exists()) {
                throw FlutterError("encode_failed", "Audio file not found: $path")
            }
            if (path.endsWith(".wav", ignoreCase = true)) {
                val wav = readWavHeader(file)
                val frames = wav.dataBytes / (wav.channels * 2)
                val durationUs = if (wav.sampleRate > 0) frames * 1_000_000L / wav.sampleRate else 0L
                return MediaInfo(
                    sampleRate = wav.sampleRate.toLong(),
                    channels = wav.channels.toLong(),
                    durationUs = durationUs,
                    frameCount = frames,
                )
            }
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(path)
                val track = (0 until extractor.trackCount).firstOrNull {
                    extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                        ?.startsWith("audio/") == true
                } ?: throw FlutterError("no_audio_track", "No audio track in $path")
                val format = extractor.getTrackFormat(track)
                val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE).toLong()
                val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT).toLong()
                val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                    format.getLong(MediaFormat.KEY_DURATION)
                } else {
                    0L
                }
                val frameCount = if (durationUs > 0 && sampleRate > 0) {
                    (durationUs * sampleRate + 500_000L) / 1_000_000L
                } else {
                    null
                }
                // M7: a video track (the guide video). Frames are counted by
                // stepping through the track's samples (no decoding).
                val videoTrack = (0 until extractor.trackCount).firstOrNull {
                    extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                        ?.startsWith("video/") == true
                }
                if (videoTrack != null) {
                    val vf = extractor.getTrackFormat(videoTrack)
                    val videoDurationUs = if (vf.containsKey(MediaFormat.KEY_DURATION)) {
                        vf.getLong(MediaFormat.KEY_DURATION)
                    } else {
                        null
                    }
                    extractor.selectTrack(videoTrack)
                    var videoFrames = 0L
                    while (extractor.sampleTime >= 0) {
                        videoFrames++
                        if (!extractor.advance()) break
                    }
                    return MediaInfo(
                        sampleRate = sampleRate,
                        channels = channels,
                        durationUs = durationUs,
                        frameCount = frameCount,
                        hasVideo = true,
                        videoWidth = vf.getInteger(MediaFormat.KEY_WIDTH).toLong(),
                        videoHeight = vf.getInteger(MediaFormat.KEY_HEIGHT).toLong(),
                        videoFrameCount = videoFrames,
                        videoDurationUs = videoDurationUs,
                    )
                }
                return MediaInfo(
                    sampleRate = sampleRate,
                    channels = channels,
                    durationUs = durationUs,
                    frameCount = frameCount,
                    hasVideo = false,
                )
            } catch (e: FlutterError) {
                throw e
            } catch (e: Exception) {
                throw FlutterError("encode_failed", "Cannot probe media: ${e.message}")
            } finally {
                extractor.release()
            }
        }
    }
}
