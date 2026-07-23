package com.macecho.app.ui.pair

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentPairDeviceBinding
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.storage.TrustStore

/**
 * PairDeviceFragment — Phase 12.1 UI + Phase 12.2 Navigation, updated for
 * the follow-up UI refinement task (Tasks 3, 4, 5).
 *
 * Task 3: Before opening the camera (PairingScannerFragment), check whether
 * a trusted device already exists via TrustStore (the same single source of
 * truth used elsewhere — see HomeFragment.refreshPairingDisplay). If one
 * exists, show the "already paired" popup and do NOT navigate to the
 * camera. This is the ONLY place in the app that shows this popup now —
 * Home's Pair New Device button no longer shows it (see HomeFragment).
 *
 * Tasks 4/5: This fragment does not implement navigation-stack clearing
 * itself — PairingScannerFragment calls the new
 * NavigationHost.navigateToRoot() on successful pairing so the user lands
 * directly on Home without this screen remaining in the back stack. Back
 * navigation while still in the camera (before success) is unaffected and
 * uses the existing navigateBack(), which naturally returns here.
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
        // Task 3: guard camera launch — check TrustStore before opening it.
        binding.cardScanQr.setOnClickListener {
            handleScanQrTapped()
        }

        // Enter code — manual code entry is a future phase.
        binding.btnEnterCode.setOnClickListener { /* Future phase */ }

        // Help link — future phase.
        binding.tvLinkHowPairing.setOnClickListener { /* Future phase */ }
    }

    /**
     * Task 3: "Before opening the camera, check whether a trusted device
     * already exists. If one exists: Do NOT open the camera. Reuse the
     * existing popup... 'You are already paired with a device. Unpair the
     * current device before pairing another.'"
     *
     * Reads TrustStore directly (already-existing Phase 9 storage) — the
     * same single source of truth as HomeFragment, per Task 2's principle
     * applied consistently across the app.
     */
    private fun handleScanQrTapped() {
        val alreadyTrusted = TrustStore(requireContext()).getAll().isNotEmpty()
        if (alreadyTrusted) {
            showAlreadyPairedPopup()
            return
        }
        (requireActivity() as? NavigationHost)?.navigateTo(PairingScannerFragment())
    }

    /**
     * The single popup implementation for "already paired," reused (not
     * duplicated) — this is the only call site in the app after this task.
     */
    private fun showAlreadyPairedPopup() {
        AlertDialog.Builder(requireContext())
            .setMessage(
                "You are already paired with a device.\n" +
                "Unpair the current device before pairing another."
            )
            .setPositiveButton("OK", null)
            .show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
