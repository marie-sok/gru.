# Animated cat doodle themes

The nine existing theme identifiers and saved selections are preserved.
The active wallpaper uses a bundled 3-column, 9-row atlas: sitting, sleeping,
and stretching poses. The red cat-dragon has folded ears; the violet caticorn
has a feline body and a single horn.

`GRUIllustratedWallpaper` lays out small sprites across the entire available
area (approximately 45–65 points each on an iPhone), with tiny decorations
between them. Each instance has a deterministic phase, gentle bobbing,
rotation, opacity variation, and breathing/stretching scale. These are 2D
sprite transforms, not articulated skeletal animation or video playback.

Animation is limited to 24 updates per second and pauses when inactive,
in Low Power Mode, or when system/app Reduce Motion is enabled. Theme-picker
thumbnails are static. Crops are cached once, not decoded each frame.

Artwork: generated with the built-in image-generation tool from the user's
approved minimal-outline reference. The atlas has a black matte and is drawn
with screen blending; no external image URLs or runtime downloads are used.

Asset: `swiftui/GRU/gru./Assets.xcassets/GRUCatDoodleAtlas.imageset/cat-doodles.png`.
Only the final minimal atlas is included; rejected ornate wallpaper variants
are not part of the application.

## Device check

1. Select each of the nine themes and open a chat using the app's theme.
2. Confirm small cats and decorations cover the whole viewport, including
   the center; cats have three poses and do not move in unison.
3. Type, scroll, send a message, and open the keyboard: the wallpaper must
   not intercept touches or move the composer.
4. Toggle Reduce Motion and dynamic backgrounds; confirm a static pattern.
5. Background/foreground the app and enable Low Power Mode.
6. Confirm the red cat-dragon has folded ears and the caticorn is a cat.
