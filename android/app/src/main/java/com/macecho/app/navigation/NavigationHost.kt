package com.macecho.app.navigation

import androidx.fragment.app.Fragment

/**
 * NavigationHost — Phase 4
 *
 * Interface implemented by MainActivity.
 *
 * Fragments must never manipulate FragmentManager directly. Instead, they
 * request navigation through this interface by casting their host Activity:
 *
 *     (requireActivity() as NavigationHost).navigateTo(SomeFragment())
 *     (requireActivity() as NavigationHost).navigateBack()
 *
 * This keeps all fragment transaction logic centralized in MainActivity and
 * prevents navigation logic from becoming scattered across fragments.
 *
 * If a dedicated navigation component is introduced in a future documented
 * phase, this interface can be updated or replaced without modifying each
 * Fragment — they only depend on this contract, not on the implementation.
 */
interface NavigationHost {

    /**
     * Navigate to the given [fragment], adding the current screen to the
     * back stack so the system Back button and [navigateBack] can return to it.
     */
    fun navigateTo(fragment: Fragment)

    /**
     * Navigate back to the previous fragment on the back stack.
     * Does nothing if the back stack is already empty.
     */
    fun navigateBack()
}
