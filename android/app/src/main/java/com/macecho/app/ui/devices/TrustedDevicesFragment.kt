package com.macecho.app.ui.devices

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.appcompat.app.AlertDialog
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.macecho.app.databinding.FragmentTrustedDevicesBinding
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.session.AppSessionManager
import com.macecho.app.storage.TrustStore
import com.macecho.app.ui.pair.PairDeviceFragment
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.text.DateFormat
import java.util.Date

/**
 * TrustedDevicesFragment — Phase 12.1 UI Redesign
 *
 * Displays the empty state for the Trusted Devices tab.
 * No RecyclerView — device list will be populated in Phase 12.2+
 * when real pairing data is available.
 *
 * Must NOT contain:
 *   - Trust management        → Phase 12.2 / 13
 *   - Keychain reads/writes   → Phase 9 (complete)
 *   - Business logic of any kind
 */
class TrustedDevicesFragment : Fragment() {

    private var _binding: FragmentTrustedDevicesBinding? = null
    private val binding get() = checkNotNull(_binding) {
        "ViewBinding accessed outside of valid lifecycle"
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentTrustedDevicesBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupClickListeners()
    }

    private fun setupClickListeners() {
        // Primary CTA: navigate to PairDeviceFragment.
        binding.btnPairDevice.setOnClickListener {
            (requireActivity() as NavigationHost).navigateTo(PairDeviceFragment())
        }

        binding.btnUnpairDevice.setOnClickListener {
            unpairDevice()
        }

        // Manage — Phase 12.2: opens manage trusted devices UI.
        binding.tvManage.setOnClickListener { /* Phase 12.2 */ }
    }

    override fun onResume() {
        super.onResume()
        refreshTrustedDeviceDisplay()
        
        viewLifecycleOwner.lifecycleScope.launch {
            AppSessionManager.trustRevokedEvents.collectLatest {
                handleRemoteUnpair()
            }
        }
    }

    private fun refreshTrustedDeviceDisplay() {
        val entry = TrustStore(requireContext()).getAll().firstOrNull()
        if (entry != null) {
            binding.llEmptyState.isVisible = false
            binding.llPopulatedState.isVisible = true
            
            binding.tvDeviceName.text = entry.deviceName
            binding.tvDeviceStatus.text = "🟢 Connected"
            binding.tvDeviceId.text = "Device ID: ${entry.trustedDeviceId}"
            
            val dateFormat = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
            binding.tvLastConnected.text = "Last Connected: ${dateFormat.format(Date(entry.pairingTimestampMs))}"
        } else {
            binding.llEmptyState.isVisible = true
            binding.llPopulatedState.isVisible = false
        }
    }

    private fun unpairDevice() {
        AlertDialog.Builder(requireContext())
            .setTitle("Unpair Device?")
            .setMessage("This Android device will no longer trust this Mac. You must pair again before using MacEcho.")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Unpair") { _, _ ->
                val entry = TrustStore(requireContext()).getAll().firstOrNull() ?: return@setPositiveButton
                
                // 1. Notify Remote
                AppSessionManager.activeSession?.webSocket?.let { socket ->
                    val jsonStr = JSONObject().apply {
                        put("type", "TRUST_REVOKED")
                        put("sessionId", AppSessionManager.activeSession?.pairedDeviceId)
                    }.toString()
                    socket.send(jsonStr)
                }
                
                // 2. Local Cleanup
                TrustStore(requireContext()).remove(entry.trustedDeviceId)
                AppSessionManager.terminate(AppSessionManager.SessionTerminationReason.UNPAIRED)
                
                // 3. UI Refresh
                refreshTrustedDeviceDisplay()
            }
            .show()
    }

    private fun handleRemoteUnpair() {
        refreshTrustedDeviceDisplay()
        
        AlertDialog.Builder(requireContext())
            .setTitle("Device Unpaired")
            .setMessage("The paired device has removed this trust relationship.\n\nTo continue using MacEcho, pair with a device again.")
            .setPositiveButton("OK", null)
            .show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
