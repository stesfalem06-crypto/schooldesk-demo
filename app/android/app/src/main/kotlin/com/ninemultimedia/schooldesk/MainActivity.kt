package com.ninemultimedia.schooldesk

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var scanResult: MethodChannel.Result? = null
    private val scan = registerForActivityResult(ScanContract()) { result ->
        val pending = scanResult
        scanResult = null
        pending?.success(result.contents ?: "")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "school/scan").setMethodCallHandler { call, result ->
            if (call.method == "scan") {
                scanResult = result
                val options = ScanOptions()
                options.setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                options.setPrompt("Point at the picture on the school computer")
                options.setBeepEnabled(false)
                options.setOrientationLocked(false)
                scan.launch(options)
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
}
