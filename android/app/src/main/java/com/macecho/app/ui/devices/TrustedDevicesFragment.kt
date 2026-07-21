package com.macecho.app.ui.devices

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentTrustedDevicesBinding
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.ui.pair.PairDeviceFragment

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

        // Manage — Phase 12.2: opens manage trusted devices UI.
        binding.tvManage.setOnClickListener { /* Phase 12.2 */ }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
