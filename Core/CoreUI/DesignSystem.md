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
| **Radius** | `small` 12, `medium` 18, `large` 22 | `DesignSystem.swift` |
| **Size** | `touchTarget` 44, `thumbnailSmall` 56, `avatar` 84, `logomark` 124, `thumbnailLarge` 138, `coverHero` 280, `signInButton` 54 | `Layout.swift` |
| **Stroke** | `hairline` 0.5, `thin` 1, `thick` 3 | `Layout.swift` |
| **Typography** | 13 roles — see below | `Typography.swift` |
| **Shadow** | `low`, `medium`, `high`, `accentGlow`, `accentLift`, `destructive` | `AppShadow.swift` |
| **Animation** | `quick` 0.2s, `standard` 0.25s, `smooth` 0.4s | `AppAnimation.swift` |
| **Colour** | adaptive + fixed accent set | `Color+Extension.swift` |
| **Surface** | `.roundedMaterialBackground(hi:)`, `.meshBackground(intense:)` | `RoundedMaterialBackground.swift`, `MeshBackground.swift` |

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

**Always** use `style: .continuous` (squircle) — never the default rectangular corner.

Special exceptions (do not tokenize): the splash/login logomark (`28`) and
Sign-In-with-Apple button (`14`) use Apple-HIG-specified continuous radii.

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
| `Size.touchTarget` | 44 | Apple HIG minimum tappable area; small chip / button square (e.g. RateAlbum star chip). |
| `Size.thumbnailSmall` | 56 | Search-row album cover. |
| `Size.avatar` | 84 | Account profile avatar. |
| `Size.logomark` | 124 | Login + Splash logomark square. |
| `Size.thumbnailLarge` | 138 | HomeSection grid album thumbnail. |
| `Size.coverHero` | 280 | AlbumDetails hero cover. |
| `Size.signInButton` | 54 | Sign-In-with-Apple button height (Apple HIG). |

Frame sizes for non-component content (mesh halo circles, accent halos,
LinearGradient heights, etc.) stay as raw numbers — those are visual tuning,
not reusable component sizes.

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

Apply via `.textStyle(_:color:)`. Each role bundles **font + default colour + tracking**.
Override the colour per call site via the `color:` parameter — *do not* chain a
trailing `.foregroundStyle`, the override slot is there to keep colour logic in
one place.

```swift
Text("New Releases").textStyle(.titleSection)
Text("See all").textStyle(.captionEmphasis, color: .accentPrimary)
Text("Edit profile").textStyle(.bodyEmphasis, color: .primaryTextOnDark)
```

| Role | Font | Default colour | Use |
|---|---|---|---|
| `displayHero` | 70pt semibold | primaryText | Login wordmark |
| `displayLarge` | 42pt bold | primaryText | Splash wordmark |
| `title` | 32pt bold | primaryText | Album hero title |
| `titleSection` | `.title2` bold | primaryText | Section headers ("New Releases", "Recent") |
| `statValue` | `.title2` rounded bold | primaryText | Stat-tile numbers |
| `statValueCompact` | 26pt rounded bold | primaryText | Account mini-stats, RateAlbum value |
| `bodyEmphasis` | `.subheadline` semibold | primaryText | Button labels, list-row titles, primary actions |
| `body` | `.subheadline` | primaryText | Body copy, descriptions, supporting text |
| `secondaryDetail` | `.title3` medium | primaryText | Album artist, secondary detail text |
| `captionEmphasis` | `.footnote` semibold | secondaryText | Chip labels, accent links ("See all", "Clear") |
| `caption` | `.footnote` | secondaryText | Secondary metadata, helper text |
| `label` | `.caption2` rounded semibold | secondaryText | **UPPERCASED** tile labels ("RATING", "RELEASED") |
| `mono` | `.caption2` monospaced | secondaryText | Build / version strings |

Do **not** hand-roll `.font(.system(size:weight:))` — if you need something not
covered here, add a role rather than freelancing.

The exceptions (left out of typography on purpose):
- **Icon font sizes** sizing SF Symbols inside chips/buttons — those are
  contextual, not body text.
- **Account display name** (28pt bold) and **avatar initials** (34pt rounded bold) —
  one-offs that aren't reused anywhere else.

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

### `.meshBackground(intense:)` — page backdrop with halos

Soft honey halo top-left + soft blue halo bottom-right over `systemBackground`.
Provides texture for Liquid Glass tiles to refract.

```swift
ScrollView { … }
    .meshBackground()                  // standard
    .meshBackground(intense: true)     // hero/AlbumDetails (currently unused)
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
