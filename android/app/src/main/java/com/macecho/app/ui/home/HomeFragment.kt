package com.macecho.app.ui.home

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentHomeBinding
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.session.AppSessionManager
import com.macecho.app.storage.TrustStore
import com.macecho.app.ui.pair.PairDeviceFragment
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.util.Calendar

/**
 * HomeFragment — Phase 12.1 UI Redesign, updated for connection-ownership fix
 * and for the follow-up UI refinement task (Task 1 / Task 3 relocation).
 *
 * Layout:
 *   Header: MacEcho + dynamic greeting + status pill
 *   Status row: real pairing status, read from TrustStore (Task 1 — was
 *     hardcoded "Unpaired" / "0" string resources; now bound to
 *     binding.tvStatusValue / binding.tvTrustedMacsValue, added to
 *     fragment_home.xml with android:id per Task 1 clarification).
 *   Pair New Device card → navigates to PairDeviceFragment. Per Task 3,
 *     this button no longer shows an "already paired" popup — that popup
 *     now lives solely on the Scan QR Code button inside PairDeviceFragment.
 *   Need Help? links (UI only)
 *
 * Single source of truth: [TrustStore] (already-existing Phase 9 storage).
 * [AppSessionManager] is consulted only for whether a *live* session exists
 * (used elsewhere, e.g. PairDeviceFragment's guard) — the values displayed
 * here come directly from TrustStore per Task 1's requirement to "not
 * hardcode values" and "read from the existing TrustStore/session state."
 *
 * Must NOT contain:
 *   - QR scanning / generation    → Phase 12.2
 *   - Pairing logic               → Phase 12.2
 *   - WebSocket / network calls   → Phase 7
 *   - Permission handling         → Phase 16
 *   - Business logic
 */
class HomeFragment : Fragment() {

    private var _binding: FragmentHomeBinding? = null
    private val binding get() = checkNotNull(_binding) {
        "ViewBinding accessed outside of valid lifecycle"
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setDynamicGreeting()
        setupClickListeners()
        refreshPairingDisplay()
    }

    override fun onResume() {
        super.onResume()
        // Per requirement: "If Home is reopened, do not reconnect. Simply
        // display the already-active session." This only reads TrustStore's
        // current on-disk state — it never opens a connection.
        refreshPairingDisplay()
        
        viewLifecycleOwner.lifecycleScope.launch {
            AppSessionManager.trustRevokedEvents.collectLatest {
                refreshPairingDisplay()
            }
        }
    }

    /**
     * Task 1: "Immediately after pairing, update the Home UI using the
     * already stored TrustStore information... Do not hardcode values.
     * Read from the existing TrustStore/session state."
     *
     * TrustStore is the single source of truth (per Task 2's principle,
     * applied consistently here too). MacEcho Version 1 supports exactly
     * one paired device, so the first entry (if any) is "the" trusted
     * device.
     */
    private fun refreshPairingDisplay() {
        val entries = TrustStore(requireContext()).getAll()
        val trusted = entries.firstOrNull()

        if (trusted != null) {
            binding.tvStatusValue.text = getString(com.macecho.app.R.string.home_status_paired)
            binding.tvTrustedMacsValue.text = trusted.deviceName
        } else {
            binding.tvStatusValue.text = getString(com.macecho.app.R.string.home_status_unpaired)
            binding.tvTrustedMacsValue.text = "0"
        }
    }

    // -------------------------------------------------------------------------
    // Dynamic greeting based on time of day
    // -------------------------------------------------------------------------

    private fun setDynamicGreeting() {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val greeting = when {
            hour < 12 -> getString(com.macecho.app.R.string.home_greeting_morning)
            hour < 18 -> getString(com.macecho.app.R.string.home_greeting_afternoon)
            else      -> getString(com.macecho.app.R.string.home_greeting_evening)
        }
        binding.tvGreeting.text = greeting
    }

    // -------------------------------------------------------------------------
    // Click listeners
    // -------------------------------------------------------------------------

    private fun setupClickListeners() {
        // Task 3: "We do not need to have two places where we have that
        // notification... nothing should come [from] that button, it should
        // work." The already-paired popup now lives solely on the Scan QR
        // Code button inside PairDeviceFragment. This button always
        // navigates — no guard, no popup here.
        binding.cardPairDevice.setOnClickListener {
            (requireActivity() as NavigationHost).navigateTo(PairDeviceFragment())
        }

        // Help links — UI only, no business logic.
        binding.tvLinkHowPairing.setOnClickListener { /* Phase 12.2: open help content */ }
        binding.tvLinkTroubleshooting.setOnClickListener { /* Phase 12.2: open troubleshooting */ }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
