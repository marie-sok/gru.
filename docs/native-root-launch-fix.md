# Native root, focus and wallpaper fix

Reviewed beta through 292fbb8, including the release theme center and migration
of legacy chat wallpapers. The 27 minimal cat sprites and nine theme IDs remain.

The old screen-protection container put the entire app inside a secure
UITextField's private canvas. That made an app-wide password input eligible
for focus/AutoFill and placed RootView behind another UIHostingController.
The UI now uses native SwiftUI containment, preserving focus, scene environment
and safe areas. No account or credential is injected; login values start empty.
The only source occurrence of user-222 is an unrelated message DTO test fixture.

Live capture/mirroring still hides the app, and the app-switcher overlay remains.
Ordinary screenshots are not prevented. The screenshot message now states this
accurately instead of promising secure-field redaction.

Chat artwork covers safe areas; the login screen also uses the selected theme.
Only the wallpaper ignores safe areas, so the composer still follows keyboard
layout. The theme center has a full-screen preview and respects system Reduce
Motion/Low Power Mode when showing LIVE vs STATIC.

Run on Mac: bash scripts/open_beta_xcode.command. It sets the default iPhone
host from the Mac LAN address and opens this checkout's exact project. It does
not kill servers, remove app data, alter Keychain or start another database.

Device checks: tap empty space on onboarding/chat/settings (no keyboard should
appear), edit login fields (AutoFill is allowed there), log in and verify the
keyboard closes, then type/scroll in chat and inspect full-screen theme motion.
Check capture overlay separately; simulator compilation cannot prove these
physical-device behaviours or identify a saved Passwords entry on the user's phone.
