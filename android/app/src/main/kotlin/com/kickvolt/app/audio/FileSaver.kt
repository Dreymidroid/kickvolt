package com.kickvolt.app.audio

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import java.io.File
import java.io.IOException

/** Asks the user to pick a directory tree via SAF (`ACTION_OPEN_DOCUMENT_TREE`). */
interface DirectoryTreePicker {
    suspend fun pickDirectoryTree(): Uri?
}

/**
 * Copies exported beat-pack files into a user-picked SAF directory tree using
 * [DocumentsContract.createDocument] and `ContentResolver.openOutputStream`.
 */
class FileSaver(
    private val context: Context,
    private val treePicker: DirectoryTreePicker,
) {
    suspend fun saveToFiles(paths: List<String>): Long {
        if (paths.isEmpty()) return 0L
        val treeUri = treePicker.pickDirectoryTree() ?: return 0L
        val docId = DocumentsContract.getTreeDocumentId(treeUri)
        val parentDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
        val resolver = context.contentResolver

        var saved = 0L
        for (rawPath in paths) {
            val src = File(rawPath)
            if (!src.exists()) continue
            val mime = mimeForName(src.name)
            try {
                val targetUri = DocumentsContract.createDocument(
                    resolver,
                    parentDocUri,
                    mime,
                    src.name,
                ) ?: throw FlutterError("encode_failed", "Could not create file ${src.name}.")
                val out = resolver.openOutputStream(targetUri)
                    ?: throw FlutterError("encode_failed", "Could not open output stream for ${src.name}.")
                src.inputStream().use { input ->
                    out.use { output ->
                        input.copyTo(output)
                    }
                }
                saved++
            } catch (e: FlutterError) {
                throw e
            } catch (e: IOException) {
                val msg = e.message ?: ""
                val full = msg.contains("ENOSPC") || msg.contains("No space left", ignoreCase = true)
                throw FlutterError(if (full) "disk_full" else "encode_failed", e.message)
            }
        }
        return saved
    }

    private fun mimeForName(name: String): String = when {
        name.endsWith(".wav", ignoreCase = true) -> "audio/wav"
        name.endsWith(".m4a", ignoreCase = true) -> "audio/mp4"
        name.endsWith(".mp4", ignoreCase = true) -> "video/mp4"
        else -> "application/octet-stream"
    }
}
