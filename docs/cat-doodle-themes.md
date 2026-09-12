# Cat doodle themes

The nine existing theme identifiers and saved selections are preserved.
The active wallpaper uses the bundled 3-column, 9-row atlas with sitting,
sleeping and stretching poses. The red cat-dragon has folded ears; the violet
caticorn has a feline body and a single horn.

`GRUIllustratedWallpaper` lays out small sprites across the available area
(approximately 45–65 points each on an iPhone), with small decorative details
between them. The current beta treats these illustrations as visual theme art;
there is no user-facing promise that the wallpaper itself is animated.

Theme-picker thumbnails are static. Artwork is bundled with the application,
so there are no external image URLs or runtime downloads.

Artwork: generated with the built-in image-generation tool from the user's
approved minimal-outline reference. The atlas has a black matte and is drawn
with screen blending.

Asset: `swiftui/GRU/gru./Assets.xcassets/GRUCatDoodleAtlas.imageset/cat-doodles.png`.
Only the final minimal atlas is included; rejected ornate wallpaper variants
are not part of the application.

## Device check

1. Select each of the nine themes and open a chat using the selected theme.
2. Confirm small cats and decorations remain readable across the whole viewport.
3. Type, scroll, send a message and open the keyboard: the wallpaper must not
   intercept touches or move the composer/search controls.
4. Confirm message text remains readable on every theme.
5. Background/foreground the app and confirm the theme is restored correctly.
6. Confirm the red cat-dragon has folded ears and the caticorn is a cat.
