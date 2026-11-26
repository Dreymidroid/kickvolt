package com.kickvolt.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.kickvolt.app.audio.AudioHostApi
import com.kickvolt.app.audio.AudioHostApiImpl
import com.kickvolt.app.audio.AudioProgressApi
import com.kickvolt.app.audio.DirectoryTreePicker
import com.kickvolt.app.audio.PermissionRequester
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private var pendingPermission: CompletableDeferred<Boolean>? = null
    private var pendingDirectoryTree: CompletableDeferred<Uri?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        AudioHostApi.setUp(
            messenger,
            AudioHostApiImpl(
                applicationContext,
                AudioProgressApi(messenger),
                object : PermissionRequester {
                    override suspend fun request(permission: String) = requestPermission(permission)
                },
                object : DirectoryTreePicker {
                    override suspend fun pickDirectoryTree() = openDocumentTree()
                },
            ),
        )
    }

    private suspend fun requestPermission(permission: String): Boolean {
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) return true
        pendingPermission?.complete(false)
        val deferred = CompletableDeferred<Boolean>()
        pendingPermission = deferred
        requestPermissions(arrayOf(permission), PERMISSION_REQUEST)
        return deferred.await()
    }

    private suspend fun openDocumentTree(): Uri? = withContext(Dispatchers.Main) {
        pendingDirectoryTree?.complete(null)
        val deferred = CompletableDeferred<Uri?>()
        pendingDirectoryTree = deferred
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_DOCUMENT_TREE_REQUEST)
        deferred.await()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        pendingPermission?.complete(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
        pendingPermission = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != OPEN_DOCUMENT_TREE_REQUEST) return
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        pendingDirectoryTree?.complete(uri)
        pendingDirectoryTree = null
    }

    private companion object {
        const val PERMISSION_REQUEST = 4201
        const val OPEN_DOCUMENT_TREE_REQUEST = 4202
    }
}
