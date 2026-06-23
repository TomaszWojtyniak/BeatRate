# BeatRate Design System

Single source of truth for everything that gives the app its visual identity:
spacing, radii, sizes, strokes, typography, shadows, colours, surfaces, animation.

**Rule of thumb:** if you're typing a magic number into a SwiftUI view (a number
inside `.padding(...)`, `.frame(...)`, `cornerRadius:`, `lineWidth:`,
`.font(.system(size:...))`, etc.) — stop. Pick a token from this document. If no
token fits, decide whether the value is *truly* one-off (rare) or whether the
vocabulary needs a new entry (more common).

All tokens live in `Core/CoreUI/Sources/CoreUI/DesignSystem/`. Importing
`CoreUI` makes them available.

---

## Quick reference

| Category | Tokens | Where |
|---|---|---|
| **Spacing** | `xxs` 4, `xs` 8, `sm` 12, `md` 16, `lg` 20, `xl` 32 | `DesignSystem.swift` |
| **Radius** | `small` 12, `medium` 18, `large` 22, `logomark` 28, `signInButton` 14 | `DesignSystem.swift` |
| **Size** | `connectorIcon` 25, `touchTarget` 44, `thumbnailSmall` 56, `avatar` 84, `logomark` 124, `logomarkInset` 22, `thumbnailLarge` 138, `coverHero` 280, `signInButton` 54 | `Layout.swift` |
| **Halo** | `small` 260, `medium` 300, `large` 320, `meshSecondary` 360, `meshPrimary` 420 | `Layout.swift` |
| **Blur** | `contentDim` 2, `haloSmall` 36, `haloMedium` 40, `meshStandard` 80 | `Layout.swift` |
| **Stroke** | `hairline` 0.5, `thin` 1, `thick` 3 | `Layout.swift` |
| **Typography** | 23 roles — see below | `Typography.swift` |
| **Shadow** | `low`, `medium`, `high`, `accentGlow`, `accentLift`, `destructive` | `AppShadow.swift` |
| **Animation** | `quick` 0.2s, `standard` 0.25s, `smooth` 0.4s | `AppAnimation.swift` |
| **Colour** | adaptive + fixed accent set | `Color+Extension.swift` |
| **Surface** | `.roundedMaterialBackground(hi:)`, `.meshBackground()` | `RoundedMaterialBackground.swift`, `MeshBackground.swift` |

---

## Spacing

Use for padding and stack gaps. Six steps on a 4-pt grid.

```swift
.padding(.horizontal, Spacing.lg)              // outer screen edge
VStack(spacing: Spacing.md) { … }              // section gutters
HStack(spacing: Spacing.xs) { icon; label }    // inside a row
```

| Token | Value | Use |
|---|---|---|
| `Spacing.xxs` | 4 | Tight gaps between related labels (title→subtitle), inner pill padding. |
| `Spacing.xs` | 8 | Inside a row (icon-to-label), small chip padding. |
| `Spacing.sm` | 12 | Default `VStack`/`HStack` gutter, typical card-internal spacing. |
| `Spacing.md` | 16 | Section-internal padding, common card padding, glass-container spacing. |
| `Spacing.lg` | 20 | **Outer screen-edge horizontal padding** (the default page gutter), gaps between top-level sections, inner card padding for richer surfaces. |
| `Spacing.xl` | 32 | Bottom safe-area padding, large vertical breathing room (loading HUD vertical pad). |

---

## Radius

```swift
RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
.clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
```

| Token | Value | Use |
|---|---|---|
| `Radius.small` | 12 | Chips, search-row covers, small thumbnails. |
| `Radius.medium` | 18 | AlbumDetails hero cover, intermediate feature surfaces. |
| `Radius.large` | 22 | Section cards, material backgrounds, stat tiles, glass HUDs. |
| `Radius.logomark` | 28 | Splash / Login logomark (Apple-HIG continuous radius). |
| `Radius.signInButton` | 14 | Sign-In-with-Apple button (Apple-HIG continuous radius). |

**Always** use `style: .continuous` (squircle) — never the default rectangular corner.

---

## Size

Fixed component dimensions. Use these for `.frame(width:height:)` of avatars,
thumbnails, touch targets, and hero artwork.

```swift
.frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)
.frame(width: Size.touchTarget, height: Size.touchTarget)   // any tappable square
.frame(maxWidth: .infinity, maxHeight: Size.signInButton)
```

| Token | Value | Use |
|---|---|---|
| `Size.connectorIcon` | 25 | Third-party service connector icon (Apple Music, Spotify) in Settings rows. |
| `Size.touchTarget` | 44 | Apple HIG minimum tappable area; small chip / button square (e.g. RateAlbum star chip). |
| `Size.thumbnailSmall` | 56 | Search-row album cover. |
| `Size.avatar` | 84 | Account profile avatar. |
| `Size.logomark` | 124 | Login + Splash logomark square. |
| `Size.logomarkInset` | 22 | SF Symbol inset within the logomark gradient square. |
| `Size.thumbnailLarge` | 138 | HomeSection grid album thumbnail. |
| `Size.coverHero` | 280 | AlbumDetails hero cover. |
| `Size.signInButton` | 54 | Sign-In-with-Apple button height (Apple HIG). |

## Halo

Decorative blurred-circle dimensions used behind avatars / logomarks / mesh
backgrounds. Use `Halo.*` for the diameter and `Blur.*` for the matching blur
radius — see below.

| Token | Value | Use |
|---|---|---|
| `Halo.small` | 260 | Login screen halo behind logomark. |
| `Halo.medium` | 300 | Account profile-card halo behind avatar. |
| `Halo.large` | 320 | Splash screen halo behind logomark. |
| `Halo.meshSecondary` | 360 | Mesh background secondary (blue) halo. |
| `Halo.meshPrimary` | 420 | Mesh background primary (honey) halo. |

## Blur

| Token | Value | Use |
|---|---|---|
| `Blur.contentDim` | 2 | Content dim while a loading HUD is on top. |
| `Blur.haloSmall` | 36 | Login halo blur. |
| `Blur.haloMedium` | 40 | Splash / Account halo blur. |
| `Blur.meshStandard` | 80 | Mesh background halo blur. |

Halo / mesh **offsets** (e.g. `offset(x: -160, y: -240)`) stay as raw numbers —
2D positioning of decorative elements is per-screen tuning, not a reusable
vocabulary entry.

---

## Stroke

Border / hairline / ring widths. Pair with `Color.surfaceStroke` for
adaptive strokes on cards.

```swift
.stroke(Color.surfaceStroke, lineWidth: Stroke.hairline)
.stroke(Color.white.opacity(0.6), lineWidth: Stroke.thick)
```

| Token | Value | Use |
|---|---|---|
| `Stroke.hairline` | 0.5 | Hairline borders, dividers, chip outlines. |
| `Stroke.thin` | 1 | Standard inner highlight or edge stroke. |
| `Stroke.thick` | 3 | Decorative ring (Account avatar conic). |

---

## Typography

Apply via `.textStyle(_:color:)` or `.textStyle(_:foreground:)`. Each role bundles
**font + default colour + tracking**. Override the colour per call site via the
`color:` (Color) or `foreground:` (any `ShapeStyle`) parameter — *do not* chain a
trailing `.foregroundStyle`, the override slot is there to keep colour logic in
one place.

```swift
Text("New Releases").textStyle(.titleSection)
Text("See all").textStyle(.captionEmphasis, color: .accentPrimary)
Text("Edit profile").textStyle(.bodyEmphasis, color: .primaryTextOnDark)

// For ShapeStyle values (.secondary, .tertiary, materials, gradients):
Text("GENRE").textStyle(.label, foreground: .tertiary)
Image(systemName: "chevron.right").textStyle(.iconRowAccessory, foreground: .tertiary)
```

| Role | Font | Default colour | Use |
|---|---|---|---|
| `displayHero` | 70pt semibold | primaryText | Login wordmark |
| `displayLarge` | 42pt bold | primaryText | Splash wordmark |
| `title` | 32pt bold | primaryText | Album hero title |
| `displayName` | 28pt bold | primaryText | Account profile-card display name |
| `avatarInitials` | 34pt rounded bold | primaryText | Account profile-card avatar initials |
| `titleSection` | `.title2` bold | primaryText | Section headers ("New Releases", "Recent") |
| `statValue` | `.title2` rounded bold | primaryText | Stat-tile numbers |
| `statValueCompact` | 26pt rounded bold | primaryText | Account mini-stats, RateAlbum value |
| `captionValue` | `.caption2` rounded bold | primaryText | Compact rounded-bold number on chips over artwork (Home rating chip). |
| `bodyEmphasis` | `.subheadline` semibold | primaryText | Button labels, list-row titles, primary actions |
| `body` | `.subheadline` | primaryText | Body copy, descriptions, supporting text |
| `secondaryDetail` | `.title3` medium | primaryText | Album artist, secondary detail text |
| `captionEmphasis` | `.footnote` semibold | secondaryText | Chip labels, accent links ("See all", "Clear") |
| `caption` | `.footnote` | secondaryText | Secondary metadata, helper text |
| `label` | `.caption2` rounded semibold | secondaryText | **UPPERCASED** tile labels ("RATING", "RELEASED") |
| `mono` | `.caption2` monospaced | secondaryText | Build / version strings |
| `iconLabel` | `.caption2` semibold | primaryText | Small SF Symbol paired with a label (e.g. StatTile leading icon) |
| `iconChip` | 11pt semibold | primaryText | SF Symbol leading a caption chip (e.g. genre chip) |
| `iconRowAccessory` | 12pt semibold | primaryText | List-row trailing accessory (e.g. chevron) |
| `iconAction` | 20pt bold | primaryText | SF Symbol inside an action chip (e.g. RateAlbum star chip) |
| `iconRating` | `.title3` | primaryText | Interactive rating stars |
| `iconPlaceholder` | 36pt | primaryText | Placeholder SF Symbol for album thumbnails |
| `iconHero` | 50pt | primaryText | Placeholder SF Symbol behind a hero cover (AlbumDetails) |

Do **not** hand-roll `.font(.system(size:weight:))` — if you need something not
covered here, add a role rather than freelancing.

### SF Symbol icons via typography

SF Symbols (`Image(systemName:)`) are sized via `.font` in SwiftUI, so they
share the typography vocabulary. Apply `.textStyle(.iconChip)` (or any
icon-named role) directly to an `Image(systemName:)`. Tracking is a no-op on
symbols; pass `color:` explicitly when the icon shouldn't use the role default.

---

## Shadow

Apply via `.appShadow(_:)`. Six tiers across three roles; do **not** hand-roll
`.shadow(color:radius:x:y:)`.

```swift
.appShadow(.medium)         // standard card depth
.appShadow(.high)           // hero artwork
.appShadow(.accentGlow)     // honey CTA glow
.appShadow(.destructive)    // red logout
```

| Tier | Use |
|---|---|
| `.low` | Search rows, chips, album thumbnails (subtle 1-layer). |
| `.medium` | Cards, raised tiles, all material backgrounds (2-layer ambient + crisp). |
| `.high` | Hero artwork, large featured surfaces (heavy 2-layer). |
| `.accentGlow` | Honey-tinted lift for primary CTAs (Edit profile pill, Rate star chip, avatar ring). |
| `.accentLift` | Large honey lift on dark backgrounds (splash/login logomark, home Hero card). |
| `.destructive` | Red glow for destructive CTAs (Settings logout). |

---

## Animation

Three named curves. Use for `withAnimation { … }` and `.animation(_:value:)`.

```swift
withAnimation(AppAnimation.quick) { showFlash = true }
.animation(AppAnimation.smooth, value: artworkTint)
```

| Token | Curve | Use |
|---|---|---|
| `AppAnimation.quick` | 0.20s ease-in-out | State flips (loading blur, opacity toggles, snap-in flashes). |
| `AppAnimation.standard` | 0.25s ease-in-out | Short transitions ("Saved" flash fade-out). |
| `AppAnimation.smooth` | 0.40s ease-in-out | Value-driven crossfades, colour swaps. |

For waiting (not animating), use `Task.sleep(for: .seconds(N))` — never
`nanoseconds:`.

---

## Colour

Defined in `Color+Extension.swift`. All adaptive colours auto-pick light/dark
variants via `UIColor`'s dynamic provider.

### Surfaces & text (adaptive)
- `Color.backgroundColor` — page background.
- `Color.primaryText` / `Color.secondaryText` — main / supporting text.
- `Color.primaryTextOnDark` / `Color.secondaryTextOnDark` — **fixed-light** text
  for permanently-dark surfaces (splash/login on dark gradient, accent-filled
  CTA pills). Use these whenever the surface beneath is fixed-dark, since the
  adaptive `primaryText` would turn dark in light mode and vanish.

### Primary accent (honey yellow #E6B655 — same in both modes)
- `accentPrimary` — stars, CTAs, brand highlights, "See all" / "Clear" links.
- `accentPrimaryDeep` — gradient bottom stop, pressed states.
- `accentPrimarySoft` (18%) — accent halos behind avatars/ratings.
- `accentPrimaryTint` (10%) — subtle stat-tile background washes.
- `accentPrimaryGlow` (50%) — drop-shadow glow under primary CTAs.
- `accentPrimaryGradient` — vertical primary→deep gradient, fill for accent buttons.

### Secondary accent (blue, adaptive)
- `accentSecondary` — date/time/links, "rated count" stat.
- `accentSecondarySoft` — backdrop halo in mesh background.
- `accentSecondaryTint` — "Released" stat-tile background.

### Decorative gradients
- `backgroundGradient` — full-bleed dark sapphire→navy gradient (Splash, Login).
- `avatarConic` — Account profile avatar conic ring.

### Misc
- `albumPlaceholderColor` — placeholder behind loading album artwork.
- `errorRed` — error text.
- `glassTintOnMedia` — fixed-dark tint for Liquid Glass over album art (keeps the rating chip's white/honey content legible on light covers).

---

## Surfaces

### `.roundedMaterialBackground(hi:)` — the universal section card

Liquid Glass (iOS 26) backdrop with an outer drop shadow. Use this whenever
content needs to sit in a "card" — section containers, stat tiles, profile
cards, anything that should feel like a raised surface.

```swift
content
    .padding(Spacing.lg)
    .roundedMaterialBackground()           // regular glass
    .padding(.horizontal, Spacing.md)      // outer screen-edge inset
```

Pass `hi: true` to add a faint honey tint for hero/profile tiles (currently
unused — most tiles use plain glass).

The internal shadow is always `.appShadow(.medium)` — do not stack a separate
shadow on top.

### `.meshBackground()` — page backdrop with halos

Soft honey halo top-left + soft blue halo bottom-right over `systemBackground`.
Provides texture for Liquid Glass tiles to refract.

```swift
ScrollView { … }
    .meshBackground()
```

The mesh is `.drawingGroup()`'d for performance — blurs are computed once and
reused. Avoid putting it on screens that don't host glass tiles (it's not free).

### `GlassEffectContainer` — group adjacent glass tiles

When stacking multiple `.roundedMaterialBackground()` cards, wrap them in a
`GlassEffectContainer` matched to the stack spacing. The container helps the
renderer batch glass passes.

```swift
GlassEffectContainer(spacing: Spacing.md) {
    LazyVStack(spacing: Spacing.md) { … }
}
```

---

## Recipes

Common view shapes built entirely from design-system tokens. Copy these as
starting points.

### Section card (the everywhere-card)

```swift
HomeSectionView(name: "New Releases", albums: …, selectedAlbum: $selected)
    .padding(Spacing.lg)
    .roundedMaterialBackground()
    .padding(.horizontal, Spacing.md)
```

### Stack of cards in a scroll view

```swift
ScrollView {
    GlassEffectContainer(spacing: Spacing.md) {
        LazyVStack(spacing: Spacing.md) {
            ForEach(items) { item in
                ItemCard(item)
                    .padding(Spacing.lg)
                    .roundedMaterialBackground()
                    .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.bottom, Spacing.lg)
    }
}
.meshBackground()
```

### Section header with accent link

```swift
HStack(alignment: .firstTextBaseline) {
    Text(title).textStyle(.titleSection)
    Spacer()
    Text("See all").textStyle(.captionEmphasis, color: .accentPrimary)
}
```

### Stat tile

```swift
StatTile(label: "Rating",
         systemImage: "star.fill",
         iconColor: .accentPrimary,
         tint: .accentPrimaryTint) {
    Text("8.4").textStyle(.statValue)
}
```

The label is uppercased and rendered in `.label` style automatically.

### Primary CTA pill (honey gradient)

```swift
Button(action: action) {
    Text("Edit profile")
        .textStyle(.bodyEmphasis, color: .primaryTextOnDark)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Capsule().fill(Color.accentPrimaryGradient))
        .appShadow(.accentGlow)
}
.buttonStyle(.plain)
```

### Album thumbnail (small / large)

```swift
// Search row
AsyncImage(url: url) { … }
    .frame(width: Size.thumbnailSmall, height: Size.thumbnailSmall)
    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    .appShadow(.low)

// HomeSection grid
AsyncImage(url: url) { … }
    .frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)
    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    .appShadow(.low)
```

### Rating chip (over artwork)

`RatingChip` is a Liquid Glass capsule (honey `★` + one-decimal score) pinned to
the top-trailing corner of a cover. The glass carries a fixed-dark tint
(`.glassEffect(.regular.tint(Color.glassTintOnMedia), in: Capsule())`) so the
white number and honey star stay legible over light covers. The star uses
`.iconChip`, the number `.captionValue` (rounded-bold) in `.primaryTextOnDark`.
Overlay it on the **clipped** cover and gate it on a real rating — never render
`★ 0.0`.

```swift
cover
    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    .overlay(alignment: .topTrailing) {
        if let userRating = album.userRating, userRating > 0 {  // hide when unrated
            RatingChip(rating: userRating)
                .padding(Spacing.xs)                            // ~snug inset from the corner
        }
    }
    .appShadow(.low)
```

### List row text block (title + subtitle)

```swift
VStack(alignment: .leading, spacing: 1) {       // 1pt is fine for tight pairs
    Text(album.title).textStyle(.bodyEmphasis).lineLimit(1)
    Text(album.artist).textStyle(.caption).lineLimit(1)
}
```

### Loading HUD

```swift
content.loading(isLoading, message: "Saving…")
```

`LoadingView` already handles glass material, blur on content, animation curve.

---

## Anti-patterns

If you find yourself writing any of these, stop and pick a token instead.

| Don't | Do |
|---|---|
| `.padding(20)` | `.padding(Spacing.lg)` |
| `VStack(spacing: 12)` | `VStack(spacing: Spacing.sm)` |
| `cornerRadius: 22` | `cornerRadius: Radius.large` |
| `.frame(width: 138, height: 138)` | `.frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)` |
| `lineWidth: 0.5` | `lineWidth: Stroke.hairline` |
| `.font(.system(.subheadline, weight: .semibold))` | `.textStyle(.bodyEmphasis)` |
| `.shadow(color: .black.opacity(0.18), radius: 14, …)` | `.appShadow(.medium)` |
| `.easeInOut(duration: 0.2)` | `AppAnimation.quick` |
| `Task.sleep(nanoseconds: 1_400_000_000)` | `Task.sleep(for: .seconds(1.4))` |
| `.background(Color(red: 0.5, green: 0.4, …))` | `.background(Color.accentPrimaryTint)` (or define a token) |
| `.foregroundStyle(.gray)` | `.foregroundStyle(Color.secondaryText)` |
| Chained `.foregroundStyle` after `.textStyle` | `.textStyle(.role, color: ...)` |

When a value genuinely **doesn't** belong to the system (e.g. mesh halo
positions, gradient tuning stops, icon glyph sizes inside chips), keep it as a
raw number locally — but be honest with yourself: most magic numbers belong in
the system.

---

## Adding to the system

If you need a value the system doesn't have:

1. **Check if it's a one-off.** A frame size used once for a unique decorative
   blob doesn't need to be tokenized.
2. **Check if rounding to an existing token works.** `padding(.top, 14)` →
   `Spacing.sm` (12) is usually fine.
3. **If it's reused or semantic, add a token.** Add the constant to the
   appropriate file in `Core/CoreUI/Sources/CoreUI/DesignSystem/`. Update this
   document. Migrate existing call sites.

Keep the vocabulary small. The whole design system is currently ~40 tokens —
adding more should be deliberate.
