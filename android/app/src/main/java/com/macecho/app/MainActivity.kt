package com.macecho.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.macecho.app.navigation.NavigationHost
import com.macecho.app.ui.devices.TrustedDevicesFragment
import com.macecho.app.ui.home.HomeFragment
import com.macecho.app.ui.pair.PairDeviceFragment
import com.macecho.app.ui.settings.SettingsFragment

/**
 * MainActivity — Phase 12.1 UI Redesign
 *
 * Hosts the BottomNavigationView and a fragment container.
 * Tabs: Home / Devices / Settings — no Notifications tab.
 *
 * Navigation rules:
 *   Bottom nav swaps the primary tab fragment.
 *   Fragments that require a detail screen (e.g. PairDeviceFragment)
 *   call [navigateTo]; back navigation via [navigateBack] pops to the tab.
 *
 * Must NOT contain:
 *   - Pairing logic         → Phase 12.2
 *   - WebSocket logic       → Phase 7
 *   - Cryptography          → Phase 8
 *   - Permission handling   → Phase 16
 *   - Business logic
 */
class MainActivity : AppCompatActivity(), NavigationHost {

    private lateinit var bottomNav: BottomNavigationView

    // Tracks which tab is currently selected so we can restore it on back.
    private var currentTabId: Int = R.id.nav_home

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        bottomNav = findViewById(R.id.bottom_navigation)

        // Load initial tab only on first creation.
        if (savedInstanceState == null) {
            showTab(R.id.nav_home)
        } else {
            currentTabId = savedInstanceState.getInt(KEY_TAB, R.id.nav_home)
        }

        bottomNav.setOnItemSelectedListener { item ->
            if (item.itemId != currentTabId) {
                currentTabId = item.itemId
                showTab(item.itemId)
            }
            true
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(KEY_TAB, currentTabId)
    }

    // -------------------------------------------------------------------------
    // Tab switching
    // -------------------------------------------------------------------------

    private fun showTab(tabId: Int) {
        val fragment: Fragment = when (tabId) {
            R.id.nav_home     -> HomeFragment()
            R.id.nav_devices  -> TrustedDevicesFragment()
            R.id.nav_settings -> SettingsFragment()
            else              -> HomeFragment()
        }
        supportFragmentManager
            .beginTransaction()
            .setCustomAnimations(android.R.anim.fade_in, android.R.anim.fade_out)
            .replace(R.id.fragment_container, fragment, tabId.toString())
            .commit()
    }

    // -------------------------------------------------------------------------
    // NavigationHost — detail screens pushed on top of the tab
    // -------------------------------------------------------------------------

    override fun navigateTo(fragment: Fragment) {
        supportFragmentManager
            .beginTransaction()
            .setCustomAnimations(
                android.R.anim.slide_in_left,
                android.R.anim.slide_out_right,
                android.R.anim.slide_in_left,
                android.R.anim.slide_out_right
            )
            .replace(R.id.fragment_container, fragment)
            .addToBackStack(null)
            .commit()
    }

    override fun navigateBack() {
        if (supportFragmentManager.backStackEntryCount > 0) {
            supportFragmentManager.popBackStack()
        }
    }

    override fun navigateToRoot() {
        // Pops every entry in one step (rather than looping navigateBack()),
        // so exactly one animation plays and the user never sees an
        // intermediate screen — per Task 4: "Do not show two separate back
        // animations." POP_BACK_STACK_INCLUSIVE with a null name pops back
        // to the bottom of the stack, i.e. the current tab fragment
        // installed by showTab(), which was never added to the back stack.
        if (supportFragmentManager.backStackEntryCount > 0) {
            supportFragmentManager.popBackStack(
                null,
                androidx.fragment.app.FragmentManager.POP_BACK_STACK_INCLUSIVE
            )
        }
    }

    @Suppress("MissingSuperCall")
    @Deprecated("Use OnBackPressedDispatcher instead for new code")
    override fun onBackPressed() {
        if (supportFragmentManager.backStackEntryCount > 0) {
            supportFragmentManager.popBackStack()
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }

    companion object {
        private const val KEY_TAB = "current_tab"
    }
}
