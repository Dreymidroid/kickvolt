package com.kickvolt.app

import android.content.pm.PackageManager
import com.kickvolt.app.audio.AudioHostApi
import com.kickvolt.app.audio.AudioHostApiImpl
import com.kickvolt.app.audio.AudioProgressApi
import com.kickvolt.app.audio.PermissionRequester
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CompletableDeferred

class MainActivity : FlutterActivity() {
    private var pendingPermission: CompletableDeferred<Boolean>? = null

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

    private companion object {
        const val PERMISSION_REQUEST = 4201
    }
}
