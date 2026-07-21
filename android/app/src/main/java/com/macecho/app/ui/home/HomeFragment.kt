package com.macecho.app.ui.home

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentHomeBinding
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.ui.pair.PairDeviceFragment
import java.util.Calendar

/**
 * HomeFragment — Phase 12.1 UI Redesign
 *
 * Presentational screen matching the Phase 12.1 design reference.
 *
 * Layout:
 *   Header: MacEcho + dynamic greeting + status pill
 *   Pair New Device card → navigates to PairDeviceFragment
 *   Connection Overview card (static placeholder values)
 *   Need Help? links (UI only)
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
        // Pair New Device card → navigate to PairDeviceFragment
        // No pairing logic; navigation only.
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
