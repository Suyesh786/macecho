package com.macecho.app.pairing

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import com.google.android.material.dialog.MaterialAlertDialogBuilder

/**
 * CameraPermissionManager.kt — Phase 12.2
 *
 * Encapsulates the Android runtime camera permission lifecycle.
 *
 * Usage:
 *   1. Create in Fragment.onCreate() via [CameraPermissionManager.from].
 *   2. Call [request] from Fragment.onViewCreated() or a button click.
 *
 * Flow:
 *   checkGranted() == true  → onGranted() called immediately
 *   First request denied    → onDenied() called; user may tap Try Again
 *   Permanently denied      → shows dialog with Open Settings / Cancel
 *                              ACTION_APPLICATION_DETAILS_SETTINGS
 *
 * Must NOT contain:
 *   - Camera or CameraX logic  → CameraScanner
 *   - Pairing logic            → PairingSessionClient
 *   - Business logic of any kind
 */
class CameraPermissionManager private constructor(
    private val fragment: Fragment,
    private val launcher: ActivityResultLauncher<String>,
    private val onGranted: () -> Unit,
    private val onDenied: () -> Unit,
) {

    companion object {
        private const val CAMERA_PERMISSION = android.Manifest.permission.CAMERA

        /**
         * Creates a [CameraPermissionManager] and registers the permission launcher.
         * Must be called in [Fragment.onCreate] or earlier (before Fragment is started).
         *
         * @param fragment   The fragment requesting permission.
         * @param onGranted  Invoked when permission is granted.
         * @param onDenied   Invoked when permission is denied (temporary; not permanent).
         */
        fun from(
            fragment: Fragment,
            onGranted: () -> Unit,
            onDenied: () -> Unit,
        ): CameraPermissionManager {
            var manager: CameraPermissionManager? = null
            val launcher = fragment.registerForActivityResult(
                ActivityResultContracts.RequestPermission()
            ) { granted ->
                if (granted) {
                    onGranted()
                } else {
                    manager?.handleDenied()
                }
            }
            manager = CameraPermissionManager(fragment, launcher, onGranted, onDenied)
            return manager
        }

        /** Returns true if camera permission is already granted. */
        fun checkGranted(context: Context): Boolean =
            ContextCompat.checkSelfPermission(context, CAMERA_PERMISSION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    /**
     * Requests the camera permission if not already granted.
     * If already granted, calls [onGranted] immediately.
     */
    fun request() {
        val ctx = fragment.requireContext()
        if (checkGranted(ctx)) {
            onGranted()
            return
        }
        launcher.launch(CAMERA_PERMISSION)
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    private fun handleDenied() {
        // Check if we should show rationale (i.e. not permanently denied)
        val shouldShowRationale = fragment.shouldShowRequestPermissionRationale(CAMERA_PERMISSION)

        if (shouldShowRationale) {
            // Temporarily denied — let the caller handle the UI
            onDenied()
        } else {
            // Permanently denied — show Settings dialog
            showPermanentlyDeniedDialog()
        }
    }

    private fun showPermanentlyDeniedDialog() {
        val ctx = fragment.requireContext()
        MaterialAlertDialogBuilder(ctx)
            .setTitle("Camera Permission Required")
            .setMessage(
                "Camera access is required to scan the QR code on your Mac.\n\n" +
                "Please enable it in Settings to continue pairing."
            )
            .setPositiveButton("Open Settings") { _, _ ->
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", ctx.packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                ctx.startActivity(intent)
            }
            .setNegativeButton("Cancel") { dialog, _ ->
                dialog.dismiss()
                onDenied()
            }
            .show()
    }
}
