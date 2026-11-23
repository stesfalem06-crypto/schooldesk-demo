package com.ninemultimedia.schooldesk

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.journeyapps.barcodescanner.IntentIntegrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var scanResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "school/scan").setMethodCallHandler { call, result ->
            if (call.method == "scan") {
                scanResult = result
                val integrator = IntentIntegrator(this)
                integrator.setDesiredBarcodeFormats(IntentIntegrator.QR_CODE)
                integrator.setPrompt("Point at the picture on the school computer")
                integrator.setBeepEnabled(false)
                integrator.setOrientationLocked(false)
                integrator.initiateScan()
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "school/update").setMethodCallHandler { call, result ->
            if (call.method != "install") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path.isNullOrEmpty()) {
                result.error("path", "The update file is missing", null)
                return@setMethodCallHandler
            }
            val file = File(path)
            val uri: Uri = FileProvider.getUriForFile(this, "$packageName.files", file)
            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            }
            startActivity(intent)
            result.success(true)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val parsed = IntentIntegrator.parseActivityResult(requestCode, resultCode, data)
        if (parsed != null) {
            scanResult?.success(parsed.contents ?: "")
            scanResult = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
