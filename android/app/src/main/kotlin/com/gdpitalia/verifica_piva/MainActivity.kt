package com.gdpitalia.verifica_piva

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "verifica_piva/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "signingSha1" -> result.success(signingSha1())
                    "packageName" -> result.success(packageName)
                    else -> result.notImplemented()
                }
            }
    }

    /** SHA-1 del certificato con cui è firmata l'app installata (per le chiavi Google limitate). */
    private fun signingSha1(): String? {
        return try {
            val sig: Signature? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNING_CERTIFICATES
                ).signingInfo ?: return null
                if (info.hasMultipleSigners()) info.apkContentsSigners.firstOrNull()
                else info.signingCertificateHistory.lastOrNull()
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                    .signatures?.firstOrNull()
            }
            sig ?: return null
            MessageDigest.getInstance("SHA-1").digest(sig.toByteArray())
                .joinToString("") { "%02X".format(it) }
        } catch (e: Exception) {
            null
        }
    }
}
