package com.macecho.app.ui.pair

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.macecho.app.BuildConfig
import com.macecho.app.databinding.FragmentPairScannerBinding
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.pairing.AndroidPairingState
import com.macecho.app.pairing.CameraPermissionManager
import com.macecho.app.pairing.CameraScanner
import com.macecho.app.pairing.PairingSessionClient
import com.macecho.app.pairing.QrValidator
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * PairingScannerFragment — Phase 12.2
 *
 * Full-screen QR scanner screen that drives the complete pairing handshake.
 *
 * Lifecycle:
 *   onCreate    → register CameraPermissionManager (required by ActivityResult API)
 *   onViewCreated → request camera permission → start scanning
 *   onQrFound   → validate QR → start PairingSessionClient → observe state
 *   onDestroyView → stop camera, destroy client
 *
 * State → UI mapping:
 *   SCANNING           → spinner + "Scanning…"
 *   CONNECTING         → spinner + "Connecting…"
 *   CONNECTED          → spinner + "Connected — waiting for Mac"
 *   EXCHANGING_KEYS    → spinner + "Exchanging Keys…"
 *   VERIFYING          → spinner + "Verifying…"
 *   SECURE_CHANNEL_READY → no spinner + "✓ Secure Channel Established"
 *   ERROR              → no spinner + error message + Try Again button
 *
 * Must NOT contain:
 *   - Trust establishment    → Phase 12.3
 *   - Keystore writes        → Phase 12.3
 *   - Permanent pairing      → Phase 12.3
 *   - Business logic beyond UI/UX
 */
class PairingScannerFragment : Fragment() {

    // -------------------------------------------------------------------------
    // ViewBinding
    // -------------------------------------------------------------------------

    private var _binding: FragmentPairScannerBinding? = null
    private val binding get() = checkNotNull(_binding) { "ViewBinding accessed outside of valid lifecycle" }

    // -------------------------------------------------------------------------
    // Pairing components
    // -------------------------------------------------------------------------

    /** Stable per-installation device UUID. Stored in a companion so it survives rotation. */
    private val deviceId: String by lazy {
        // In Phase 12.3 this will come from the Keystore. For now, use a
        // per-session UUID — sufficient for temporary handshake identity.
        UUID.randomUUID().toString()
    }

    private val pairingClient by lazy { PairingSessionClient(deviceId) }
    private val cameraScanner = CameraScanner()

    /** Registered in onCreate() per ActivityResult API contract. */
    private lateinit var permissionManager: CameraPermissionManager

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Must register ActivityResultLauncher before the fragment is STARTED
        permissionManager = CameraPermissionManager.from(
            fragment = this,
            onGranted = ::startCameraIfReady,
            onDenied = ::showPermissionDenied,
        )
        QrValidator.clearSeenIds()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        _binding = FragmentPairScannerBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupClickListeners()
        observePairingState()
        permissionManager.request()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        cameraScanner.stop()
        pairingClient.destroy()
        _binding = null
    }

    // -------------------------------------------------------------------------
    // Camera
    // -------------------------------------------------------------------------

    private fun startCameraIfReady() {
        val b = _binding ?: return
        cameraScanner.startScanning(
            previewView = b.previewView,
            lifecycleOwner = viewLifecycleOwner,
            onQrFound = ::onQrFound,
        )
        showStatus(getString(com.macecho.app.R.string.pair_status_scanning), subText = null)
    }

    private fun onQrFound(raw: String) {
        when (val result = QrValidator.validate(raw)) {
            is QrValidator.Result.Valid -> {
                QrValidator.markSeen(result.token.sessionId)
                // Stop camera — one scan per session
                cameraScanner.stop()
                pairingClient.start(result.token)
            }
            is QrValidator.Result.Error -> {
                showError(result.reason)
            }
        }
    }

    // -------------------------------------------------------------------------
    // State observation
    // -------------------------------------------------------------------------

    private fun observePairingState() {
        viewLifecycleOwner.lifecycleScope.launch {
            pairingClient.state.collect { state ->
                updateUiForState(state)
            }
        }
        viewLifecycleOwner.lifecycleScope.launch {
            pairingClient.errorMessage.collect { msg ->
                if (msg != null) showError(msg)
            }
        }
    }

    private fun updateUiForState(state: AndroidPairingState) {
        val b = _binding ?: return
        when (state) {
            AndroidPairingState.UNPAIRED -> Unit // handled by initial / error states

            AndroidPairingState.SCANNING ->
                showStatus(getString(com.macecho.app.R.string.pair_status_scanning))

            AndroidPairingState.CONNECTING ->
                showStatus(getString(com.macecho.app.R.string.pair_status_connecting))

            AndroidPairingState.CONNECTED ->
                showStatus(getString(com.macecho.app.R.string.pair_status_connected))

            AndroidPairingState.EXCHANGING_KEYS ->
                showStatus(getString(com.macecho.app.R.string.pair_status_exchanging_keys))

            AndroidPairingState.VERIFYING ->
                showStatus(getString(com.macecho.app.R.string.pair_status_verifying))

            AndroidPairingState.SECURE_CHANNEL_READY -> {
                b.progressIndicator.isVisible = false
                b.labelStatus.text = getString(com.macecho.app.R.string.pair_status_ready)
                b.labelSubStatus.isVisible = false
                b.btnTryAgain.isVisible = false
                // Phase 12.3 will navigate to trust-establishment screen here
            }

            AndroidPairingState.ERROR -> Unit // handled by errorMessage observer
        }
    }

    // -------------------------------------------------------------------------
    // UI helpers
    // -------------------------------------------------------------------------

    private fun showStatus(text: String, subText: String? = null) {
        val b = _binding ?: return
        b.progressIndicator.isVisible = true
        b.labelStatus.text = text
        b.labelSubStatus.text = subText ?: ""
        b.labelSubStatus.isVisible = subText != null
        b.btnTryAgain.isVisible = false
    }

    private fun showError(message: String) {
        val b = _binding ?: return
        b.progressIndicator.isVisible = false
        b.labelStatus.text = getString(com.macecho.app.R.string.pair_status_error)
        b.labelSubStatus.text = message
        b.labelSubStatus.isVisible = true
        b.btnTryAgain.isVisible = true
    }

    private fun showPermissionDenied() {
        showError(
            "Camera permission is required to scan the QR code.\n" +
            "Tap \"Try Again\" to re-request permission."
        )
    }

    private fun setupClickListeners() {
        binding.btnBack.setOnClickListener {
            pairingClient.cancel("user_cancelled")
            (requireActivity() as? NavigationHost)?.navigateBack()
        }
        binding.btnTryAgain.setOnClickListener {
            // Reset for a fresh attempt — restart camera, clear errors
            QrValidator.clearSeenIds()
            showStatus(getString(com.macecho.app.R.string.pair_status_scanning))
            permissionManager.request()
        }
    }
}
