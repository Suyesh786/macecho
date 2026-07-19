package com.macecho.app.ui.home

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentHomeBinding
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.ui.settings.SettingsFragment

/**
 * HomeFragment — Phase 4
 *
 * PRESENTATIONAL ONLY. This fragment is responsible for rendering the Home
 * Screen UI as described in 06_UI_GUIDELINES.md §Android Home Screen.
 *
 * Permitted responsibilities:
 *   - Render static UI
 *   - Handle simple button clicks
 *   - Request navigation through [NavigationHost]
 *
 * Must NOT contain:
 *   - Networking or WebSocket logic   → Phase 7
 *   - Cryptography                    → Phase 8
 *   - Permission handling             → Phase 16
 *   - Persistence or storage          → future phases
 *   - Protocol or pairing logic       → Phase 12 / Phase 13
 *   - Background services             → Phase 16
 *   - Business logic of any kind
 *   - Application state management
 *
 * All status values displayed in Phase 4 are static placeholders.
 * They will be replaced with live data in later phases.
 *
 * Navigation:
 *   This fragment never touches FragmentManager directly.
 *   It requests navigation by calling through [NavigationHost],
 *   which is implemented by MainActivity.
 */
class HomeFragment : Fragment() {

    // ViewBinding reference. Initialized in onCreateView, cleared in onDestroyView
    // to prevent view leaks (guardrail 6).
    private var _binding: FragmentHomeBinding? = null
    private val binding get() = checkNotNull(_binding) {
        "ViewBinding accessed outside of valid lifecycle (onCreateView..onDestroyView)"
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
        setupClickListeners()
    }

    private fun setupClickListeners() {
        // Navigate to Settings via the NavigationHost interface.
        // This fragment never manipulates FragmentManager directly.
        binding.btnManageSettings.setOnClickListener {
            (requireActivity() as NavigationHost).navigateTo(SettingsFragment())
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        // Clear binding reference to prevent memory leaks (guardrail 6).
        _binding = null
    }
}
