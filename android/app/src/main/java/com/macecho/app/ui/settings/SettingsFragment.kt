package com.macecho.app.ui.settings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.macecho.app.databinding.FragmentSettingsBinding

/**
 * SettingsFragment — Phase 12.1 UI Redesign
 *
 * App Settings screen with three cards:
 *   Permissions  — Local Network, Camera, Notifications (visual switches)
 *   Privacy      — Data Collection, Analytics (visual switches, off)
 *   About        — App Version
 *
 * All switches are visual-only in this phase.
 * Real permission request logic → Phase 16.
 *
 * Must NOT contain:
 *   - Permission request APIs  → Phase 16
 *   - Persistence              → future phases
 *   - Business logic of any kind
 */
class SettingsFragment : Fragment() {

    private var _binding: FragmentSettingsBinding? = null
    private val binding get() = checkNotNull(_binding) {
        "ViewBinding accessed outside of valid lifecycle"
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
        // All switches are non-clickable UI placeholders.
        // No listeners attached — Phase 16 will wire real permission requests.
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
