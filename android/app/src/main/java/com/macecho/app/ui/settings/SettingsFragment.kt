package com.macecho.app.ui.settings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentSettingsBinding
import com.macecho.app.navigation.NavigationHost

/**
 * SettingsFragment — Phase 4
 *
 * PRESENTATIONAL ONLY. This fragment renders the Settings screen scaffold as
 * described in 06_UI_GUIDELINES.md §Android Settings.
 *
 * Permitted responsibilities:
 *   - Render static UI
 *   - Handle the Back button click
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
 * Settings Sections in Phase 4 (all static, all inert):
 *   - Permissions   → future Phase 16
 *   - Connection    → future Phase 7 / Phase 14
 *   - Notifications → future Phase 16 / Phase 17
 *   - About         → content TBD in a future phase
 *   - Privacy       → content TBD in a future phase
 *
 * Tapping any section header performs NO action in Phase 4.
 * Their purpose is to establish the future screen structure only.
 *
 * Navigation:
 *   This fragment never touches FragmentManager directly.
 *   It requests back navigation by calling through [NavigationHost],
 *   which is implemented by MainActivity.
 */
class SettingsFragment : Fragment() {

    // ViewBinding reference. Initialized in onCreateView, cleared in onDestroyView
    // to prevent view leaks (guardrail 6).
    private var _binding: FragmentSettingsBinding? = null
    private val binding get() = checkNotNull(_binding) {
        "ViewBinding accessed outside of valid lifecycle (onCreateView..onDestroyView)"
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSettingsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupClickListeners()
    }

    private fun setupClickListeners() {
        // Navigate back via the NavigationHost interface.
        // This fragment never manipulates FragmentManager directly.
        binding.btnBack.setOnClickListener {
            (requireActivity() as NavigationHost).navigateBack()
        }

        // Section items are static informational placeholders in Phase 4.
        // No click listeners are attached to section headers or descriptions.
        // Their only purpose is to establish the future screen structure.
    }

    override fun onDestroyView() {
        super.onDestroyView()
        // Clear binding reference to prevent memory leaks (guardrail 6).
        _binding = null
    }
}
