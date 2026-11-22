package com.swipetrip.app

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Receipt scan: Google ML Kit text recognition with the bundled
        // model, entirely on the device; the photo stays here.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tripfam/text_recognition")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("args", "path missing", null)
                    return@setMethodCallHandler
                }
                val image = try {
                    InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                } catch (e: Exception) {
                    result.error("unreadable", e.message, null)
                    return@setMethodCallHandler
                }
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                recognizer.process(image)
                    .addOnSuccessListener { text ->
                        val lines = text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                            val box = line.boundingBox ?: return@mapNotNull null
                            mapOf(
                                "text" to line.text,
                                "left" to box.left.toDouble(),
                                "top" to box.top.toDouble(),
                                "right" to box.right.toDouble(),
                                "bottom" to box.bottom.toDouble(),
                            )
                        }
                        result.success(lines)
                    }
                    .addOnFailureListener { e -> result.error("mlkit", e.message, null) }
                    .addOnCompleteListener { recognizer.close() }
            }
    }
}
