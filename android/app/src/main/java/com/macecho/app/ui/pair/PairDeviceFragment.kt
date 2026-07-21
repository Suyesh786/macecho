package com.macecho.app.ui.pair

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentPairDeviceBinding
import com.macecho.app.navigation.NavigationHost

/**
 * PairDeviceFragment — Phase 12.1 UI + Phase 12.2 Navigation
 *
 * Presentational screen for the Pair Device flow.
 *
 * Phase 12.2: Tapping the Scan QR Code card navigates to
 * [PairingScannerFragment] which drives the full camera + handshake flow.
 */
class PairDeviceFragment : Fragment() {

    private var _binding: FragmentPairDeviceBinding? = null
    private val binding get() = checkNotNull(_binding) {
        "ViewBinding accessed outside of valid lifecycle"
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentPairDeviceBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupClickListeners()
    }

    private fun setupClickListeners() {
        // Phase 12.2: launch the full camera + QR scanning + handshake screen
        binding.cardScanQr.setOnClickListener {
            (requireActivity() as? NavigationHost)?.navigateTo(PairingScannerFragment())
        }

        // Enter code — manual code entry is a future phase.
        binding.btnEnterCode.setOnClickListener { /* Future phase */ }

        // Help link — future phase.
        binding.tvLinkHowPairing.setOnClickListener { /* Future phase */ }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}

