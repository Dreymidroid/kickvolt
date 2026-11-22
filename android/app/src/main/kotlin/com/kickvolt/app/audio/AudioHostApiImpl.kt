package com.kickvolt.app.audio

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/** Asks the user for a runtime permission; implemented by MainActivity. */
interface PermissionRequester {
    suspend fun request(permission: String): Boolean
}

class AudioHostApiImpl(
    private val context: Context,
    private val progressApi: AudioProgressApi,
    private val permissions: PermissionRequester,
) : AudioHostApi {
    private val jobs = ConcurrentHashMap<String, AtomicBoolean>()
    private val mainScope = CoroutineScope(Dispatchers.Main)

    override suspend fun decodeToWav(jobId: String, inputPath: String, outputPath: String): DecodeResult {
        val flag = AtomicBoolean(false)
        jobs[jobId] = flag
        try {
            return withContext(Dispatchers.IO) {
                WavDecoder(context, flag) { p -> reportProgress(jobId, p) }.decode(inputPath, outputPath)
            }
        } finally {
            jobs.remove(jobId)
        }
    }

    override fun cancelJob(jobId: String) {
        jobs[jobId]?.set(true)
    }

    override suspend fun pickFromMusicLibrary(): LibraryTrack? =
        throw FlutterError("unsupported", "Use listMusicLibrary on Android.")

    override suspend fun listMusicLibrary(): List<LibraryTrack> {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (!permissions.request(permission)) {
            throw FlutterError("permission_denied", "KickVolt needs access to your music to list songs.")
        }
        return withContext(Dispatchers.IO) { queryMediaStore() }
    }

    override suspend fun copyContentUri(uri: String, destPath: String) {
        withContext(Dispatchers.IO) {
            val dest = File(destPath)
            dest.parentFile?.mkdirs()
            try {
                val input = context.contentResolver.openInputStream(Uri.parse(uri))
                    ?: throw FlutterError("unsupported_format", "Can't open this song.")
                input.use { i -> dest.outputStream().use { o -> i.copyTo(o) } }
            } catch (e: FlutterError) {
                dest.delete()
                throw e
            } catch (e: SecurityException) {
                dest.delete()
                throw FlutterError("permission_denied", e.message)
            } catch (e: IOException) {
                dest.delete()
                val full = e.message?.contains("ENOSPC") == true ||
                    e.message?.contains("No space left", ignoreCase = true) == true
                throw FlutterError(if (full) "disk_full" else "decode_failed", e.message)
            }
        }
    }

    override fun freeDiskBytes(path: String): Long = WavDecoder.freeBytes(path)

    private fun reportProgress(jobId: String, fraction: Double) {
        // FlutterApi calls must happen on the platform main thread.
        mainScope.launch {
            try {
                progressApi.onProgress(jobId, fraction)
            } catch (_: Throwable) {
                // Progress is best-effort; the Dart side may have gone away.
            }
        }
    }

    private fun queryMediaStore(): List<LibraryTrack> {
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.AudioColumns.DURATION,
        )
        val tracks = mutableListOf<LibraryTrack>()
        context.contentResolver.query(
            collection,
            projection,
            "${MediaStore.Audio.Media.IS_MUSIC} != 0",
            null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        )?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val durCol = c.getColumnIndexOrThrow(MediaStore.Audio.AudioColumns.DURATION)
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val artist = c.getString(artistCol)
                tracks += LibraryTrack(
                    id = id.toString(),
                    title = c.getString(titleCol) ?: "Untitled",
                    artist = if (artist == null || artist == MediaStore.UNKNOWN_STRING) null else artist,
                    durationMs = c.getLong(durCol),
                    uri = ContentUris.withAppendedId(collection, id).toString(),
                )
            }
        }
        return tracks
    }
}
