package com.macecho.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.ui.home.HomeFragment

/**
 * MainActivity — Phase 4
 *
 * Application entry point. Thin orchestrator responsible for:
 *   1. Hosting the fragment container
 *   2. Loading the initial fragment (HomeFragment) on first launch
 *   3. Implementing [NavigationHost] so fragments can request navigation
 *      without touching FragmentManager directly
 *   4. Delegating system Back button presses to the fragment back stack
 *
 * What does NOT belong here:
 *   - Networking / WebSocket logic   → Phase 7 (transport/)
 *   - Authentication                 → Phase 13
 *   - Pairing logic                  → Phase 12
 *   - Cryptography                   → Phase 8
 *   - Permission handling            → Phase 16
 *   - Background services            → Phase 16
 *   - Business logic of any kind
 *
 * Navigation:
 *   All fragment transactions originate here through the [NavigationHost]
 *   interface. No fragment manipulates FragmentManager directly. This keeps
 *   navigation logic centralized and easy to extend in later phases.
 *
 * Animations:
 *   No fragment transition animations are added in Phase 4. Navigation is
 *   kept simple and functional. UI refinement belongs to a later phase.
 */
class MainActivity : AppCompatActivity(), NavigationHost {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Load the initial fragment only on first creation.
        // When the Activity is recreated (e.g., rotation), the fragment manager
        // restores the existing back stack automatically — no re-load needed.
        if (savedInstanceState == null) {
            navigateTo(HomeFragment())
        }
    }

    // -------------------------------------------------------------------------
    // NavigationHost implementation
    // -------------------------------------------------------------------------

    /**
     * Navigates to [fragment] by replacing the current fragment container
     * contents and adding the current state to the back stack.
     *
     * No transition animations are added in Phase 4 (guardrail 7).
     */
    override fun navigateTo(fragment: Fragment) {
        supportFragmentManager
            .beginTransaction()
            .replace(R.id.fragment_container, fragment)
            .addToBackStack(null)
            .commit()
    }

    /**
     * Pops the fragment back stack if entries exist.
     * Called by fragments that need to navigate back (e.g., SettingsFragment's
     * Back button) without manipulating FragmentManager directly.
     */
    override fun navigateBack() {
        if (supportFragmentManager.backStackEntryCount > 0) {
            supportFragmentManager.popBackStack()
        }
    }

    /**
     * Handles the system Back button.
     * If the fragment back stack has entries, pop to the previous screen.
     * If the back stack is empty, allow the default Activity finish behaviour.
     */
    @Suppress("MissingSuperCall")
    @Deprecated("Use OnBackPressedDispatcher instead for new code")
    override fun onBackPressed() {
        if (supportFragmentManager.backStackEntryCount > 1) {
            supportFragmentManager.popBackStack()
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }
}
