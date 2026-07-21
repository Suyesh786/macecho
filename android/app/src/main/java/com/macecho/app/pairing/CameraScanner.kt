package com.macecho.app.pairing

import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * CameraScanner.kt — Phase 12.2
 *
 * Wraps CameraX ImageAnalysis + ML Kit BarcodeScanner to detect QR codes.
 *
 * Usage:
 *   val scanner = CameraScanner()
 *   scanner.startScanning(previewView, lifecycleOwner) { rawValue ->
 *       // called once for the first valid QR code found
 *   }
 *   // on cleanup:
 *   scanner.stop()
 *
 * Guarantees:
 *   - [onQrFound] is called at most once per [startScanning] call.
 *     Subsequent frames are discarded after the first valid QR.
 *   - Camera is released automatically when the LifecycleOwner stops.
 *   - Calling [stop] is safe even if [startScanning] was never called.
 *
 * Must NOT contain:
 *   - QR validation logic   → QrValidator
 *   - Pairing protocol      → PairingSessionClient
 *   - Permission handling   → CameraPermissionManager
 *   - Business logic of any kind
 */
class CameraScanner {

    private var analysisExecutor: ExecutorService? = null
    private var cameraProvider: ProcessCameraProvider? = null
    @Volatile private var hasFoundQr = false

    /**
     * Starts the camera and begins scanning frames for QR codes.
     *
     * @param previewView   CameraX PreviewView surface for the live viewfinder.
     * @param lifecycleOwner Fragment/Activity that owns the camera lifecycle.
     * @param onQrFound     Called on the main thread when the first QR is decoded.
     *                      Not called again until [startScanning] is called anew.
     */
    fun startScanning(
        previewView: PreviewView,
        lifecycleOwner: LifecycleOwner,
        onQrFound: (rawValue: String) -> Unit,
    ) {
        hasFoundQr = false
        val executor: ExecutorService = Executors.newSingleThreadExecutor()
        analysisExecutor = executor

        val context = previewView.context
        val mainExecutor: Executor = ContextCompat.getMainExecutor(context)
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            val provider = cameraProviderFuture.get()
            cameraProvider = provider

            // Preview use-case — drives the PreviewView surface
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            // Analysis use-case — decode QR frames via ML Kit
            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(executor) { imageProxy ->
                        if (hasFoundQr) {
                            imageProxy.close()
                            return@setAnalyzer
                        }

                        @androidx.camera.core.ExperimentalGetImage
                        val mediaImage = imageProxy.image
                        if (mediaImage == null) {
                            imageProxy.close()
                            return@setAnalyzer
                        }

                        val inputImage = InputImage.fromMediaImage(
                            mediaImage,
                            imageProxy.imageInfo.rotationDegrees,
                        )

                        val scanner = BarcodeScanning.getClient()
                        scanner.process(inputImage)
                            .addOnSuccessListener { barcodes ->
                                val qr = barcodes.firstOrNull { b ->
                                    b.format == Barcode.FORMAT_QR_CODE &&
                                        b.rawValue != null
                                }
                                if (qr != null && !hasFoundQr) {
                                    hasFoundQr = true
                                    val raw = qr.rawValue!!
                                    // Deliver result on the main thread
                                    mainExecutor.execute { onQrFound(raw) }
                                }
                            }
                            .addOnCompleteListener {
                                imageProxy.close()
                            }
                    }
                }

            try {
                provider.unbindAll()
                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageAnalysis,
                )
            } catch (_: Exception) {
                // Camera binding failure — surface will be blank;
                // PairingScannerFragment handles via lifecycle events
            }
        }, mainExecutor)
    }

    /**
     * Stops scanning and releases the camera and analysis executor.
     * Safe to call multiple times or before [startScanning].
     */
    fun stop() {
        hasFoundQr = false
        cameraProvider?.unbindAll()
        cameraProvider = null
        analysisExecutor?.shutdown()
        analysisExecutor = null
    }
}
