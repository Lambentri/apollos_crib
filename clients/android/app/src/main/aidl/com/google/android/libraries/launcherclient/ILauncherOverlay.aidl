// The launcher overlay interface, as launchers implementing the Google
// "minus one" page expect to find it. The package and method order are the
// contract -- both are fixed by the callers, not by us.
//
// Copied from Lawnchair, which carries the same declaration:
// lawnchair/aidl/com/google/android/libraries/launcherclient/ILauncherOverlay.aidl
package com.google.android.libraries.launcherclient;

import android.view.WindowManager.LayoutParams;
import com.google.android.libraries.launcherclient.ILauncherOverlayCallback;

interface ILauncherOverlay {

    oneway void startScroll();

    oneway void onScroll(in float progress);

    oneway void endScroll();

    oneway void windowAttached(in LayoutParams lp, in ILauncherOverlayCallback cb, in int flags);

    oneway void windowDetached(in boolean isChangingConfigurations);

    oneway void closeOverlay(in int flags);

    oneway void onPause();

    oneway void onResume();

    oneway void openOverlay(in int flags);

    oneway void requestVoiceDetection(in boolean start);

    String getVoiceSearchLanguage();

    boolean isVoiceDetectionRunning();

    boolean hasOverlayContent();

    oneway void windowAttached2(in Bundle bundle, in ILauncherOverlayCallback cb);

    oneway void unusedMethod();

    oneway void setActivityState(in int flags);

    boolean startSearch(in byte[] data, in Bundle bundle);

}
