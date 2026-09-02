package io.neiam.apolloscrib.feed

import android.view.View
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner

/**
 * The lifecycle a Compose view needs, for a window that has no Activity.
 *
 * A launcher overlay is a view added straight to the window manager against
 * the launcher's token, so nothing supplies the owners Compose looks up the
 * view tree for. This is that, driven by hand from the overlay's own
 * attach/detach and the activity state the launcher reports.
 */
class OverlayHost : LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore = ViewModelStore()
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateController.savedStateRegistry

    /** Call once, before the view is added. */
    fun attachTo(view: View) {
        savedStateController.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        view.setViewTreeLifecycleOwner(this)
        view.setViewTreeViewModelStoreOwner(this)
        view.setViewTreeSavedStateRegistryOwner(this)
    }

    fun moveTo(state: Lifecycle.State) {
        // Compose stops recomposing below STARTED, which is what makes a
        // closed panel cost nothing while the launcher is on the home screen.
        lifecycleRegistry.currentState = state
    }

    fun destroy() {
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        viewModelStore.clear()
    }
}
