# Searchy UI Visual Overhaul Plan

## Current State Analysis

The existing UI has functional foundations but suffers from:
- Generic color palette that doesn't feel distinctive
- Inconsistent visual depth (flat elements mixed with shadows)
- Basic rounded rectangles without refinement
- Cluttered visual hierarchy
- Standard system-like appearance rather than premium app feel

---

## Design Philosophy: **Refined Minimalism**

Inspired by: Linear, Raycast, Arc Browser, Figma

Key principles:
1. **Depth through subtlety** - Layered surfaces with delicate shadows
2. **Purposeful color** - Neutral base with strategic accent highlights
3. **Breathing room** - Generous spacing, uncluttered layouts
4. **Micro-polish** - Thoughtful transitions, refined corners, subtle textures

---

## 1. Color Palette Overhaul

### Current Problems
- `accent = 0.33, 0.44, 1.0` is a generic blue
- Light/dark backgrounds lack character
- No gradient personality

### New Palette: **Midnight Frost**

```swift
// MARK: - New Color System
struct Colors {
    // LIGHT MODE
    static let surface0 = Color(hex: "FAFBFC")        // Page background
    static let surface1 = Color(hex: "FFFFFF")        // Cards, elevated surfaces
    static let surface2 = Color(hex: "F4F5F7")        // Subtle backgrounds, inputs
    static let surface3 = Color(hex: "EBEDF0")        // Borders, dividers

    // DARK MODE
    static let surfaceDark0 = Color(hex: "0D0E12")    // Page background - deep charcoal
    static let surfaceDark1 = Color(hex: "16181D")    // Cards - lifted
    static let surfaceDark2 = Color(hex: "1E2028")    // Inputs, secondary surfaces
    static let surfaceDark3 = Color(hex: "282A33")    // Borders, dividers

    // ACCENT - Refined Indigo with warmth
    static let accentPrimary = Color(hex: "5E5CE6")   // Primary actions
    static let accentSecondary = Color(hex: "7B79FF") // Hover states
    static let accentSubtle = Color(hex: "5E5CE6").opacity(0.12) // Backgrounds

    // SEMANTIC
    static let success = Color(hex: "30D158")         // Apple-like green
    static let warning = Color(hex: "FFD60A")
    static let error = Color(hex: "FF453A")

    // TEXT (high contrast)
    static let textPrimary = Color(hex: "1A1A2E")     // Light mode
    static let textSecondary = Color(hex: "6B7280")
    static let textTertiary = Color(hex: "9CA3AF")

    static let textPrimaryDark = Color(hex: "F9FAFB") // Dark mode
    static let textSecondaryDark = Color(hex: "9CA3AF")
    static let textTertiaryDark = Color(hex: "6B7280")
}
```

### Gradient Accents
```swift
// Hero gradients for key elements
static let accentGradient = LinearGradient(
    colors: [Color(hex: "5E5CE6"), Color(hex: "BF5AF2")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Subtle surface gradient
static let surfaceGradient = LinearGradient(
    colors: [surface0, surface2.opacity(0.5)],
    startPoint: .top,
    endPoint: .bottom
)
```

---

## 2. Typography Refinement

### Current Problems
- `.rounded` design feels playful, not professional
- Font weights not optimized for hierarchy

### New Type Scale

```swift
struct Typography {
    // Use SF Pro with specific weights for sharpness
    static let displayLarge = Font.system(size: 32, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 24, weight: .semibold, design: .default)

    static let titleLarge = Font.system(size: 20, weight: .semibold, design: .default)
    static let titleMedium = Font.system(size: 17, weight: .medium, design: .default)
    static let titleSmall = Font.system(size: 15, weight: .medium, design: .default)

    static let bodyLarge = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    static let labelLarge = Font.system(size: 12, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 11, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 10, weight: .medium, design: .default)

    // Monospace for stats/numbers
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
}
```

---

## 3. Spacing & Layout System

### New Spacing Scale (8pt grid)
```swift
struct Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}
```

### Corner Radius (refined)
```swift
struct Radius {
    static let xs: CGFloat = 4    // Small chips, badges
    static let sm: CGFloat = 8    // Buttons, inputs
    static let md: CGFloat = 12   // Cards
    static let lg: CGFloat = 16   // Dialogs, panels
    static let xl: CGFloat = 20   // Search bar, hero elements
    static let full: CGFloat = 999 // Pills
}
```

---

## 4. Shadow System

### Multi-layer shadows for depth
```swift
struct Shadows {
    // Subtle elevation - cards
    static let sm = Shadow(
        color: Color.black.opacity(0.04),
        radius: 4,
        x: 0, y: 2
    )

    // Medium elevation - dropdowns, popovers
    static let md = Shadow(
        color: Color.black.opacity(0.08),
        radius: 12,
        x: 0, y: 4
    )

    // High elevation - modals, spotlight
    static let lg = Shadow(
        color: Color.black.opacity(0.12),
        radius: 24,
        x: 0, y: 8
    )

    // Glow effect for focused elements
    static let glow = Shadow(
        color: Colors.accentPrimary.opacity(0.25),
        radius: 12,
        x: 0, y: 0
    )
}
```

---

## 5. Component Redesigns

### 5.1 Search Bar (Hero Element)

**Current:** Basic TextField with simple background
**New:** Floating glass search bar with subtle inner shadow

```swift
// Conceptual structure
ZStack {
    // Outer glow on focus
    RoundedRectangle(cornerRadius: Radius.xl)
        .fill(Colors.accentPrimary.opacity(isFocused ? 0.08 : 0))
        .blur(radius: 8)

    // Main container
    RoundedRectangle(cornerRadius: Radius.xl)
        .fill(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)

    // Content
    HStack(spacing: Spacing.md) {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Colors.textSecondary)

        TextField("Search your images...", text: $query)
            .font(Typography.bodyLarge)
    }
    .padding(Spacing.lg)
}
```

### 5.2 Result Cards

**Current:** Basic cards with generic styling
**New:** Floating cards with image-first design

```swift
// Key changes:
// 1. Remove visible borders - use shadow for separation
// 2. Image fills entire card with overlay for info
// 3. Glassmorphic info panel at bottom

VStack(spacing: 0) {
    ZStack(alignment: .bottomLeading) {
        // Full-bleed image
        AsyncImage(url: path)
            .aspectRatio(1, contentMode: .fill)

        // Gradient overlay
        LinearGradient(
            colors: [.clear, .black.opacity(0.6)],
            startPoint: .center,
            endPoint: .bottom
        )

        // Floating info pill
        HStack {
            Text(filename)
                .font(Typography.labelMedium)
                .foregroundColor(.white)

            Spacer()

            // Match percentage as pill
            Text("\(Int(similarity * 100))%")
                .font(Typography.labelSmall.weight(.semibold))
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(
                    Capsule()
                        .fill(matchColor)
                )
        }
        .padding(Spacing.md)
    }
}
.clipShape(RoundedRectangle(cornerRadius: Radius.md))
.shadow(color: .black.opacity(0.06), radius: 8, y: 2)
```

### 5.3 Tab Picker

**Current:** Basic capsule picker
**New:** Sleek segmented control with sliding indicator

```swift
// Animated pill that slides between tabs
ZStack(alignment: .leading) {
    // Background track
    RoundedRectangle(cornerRadius: Radius.sm)
        .fill(Colors.surface2)

    // Sliding indicator
    RoundedRectangle(cornerRadius: Radius.sm - 2)
        .fill(Colors.surface1)
        .shadow(Shadows.sm)
        .frame(width: tabWidth)
        .offset(x: selectedTabOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedTab)

    // Tab labels
    HStack(spacing: 0) {
        ForEach(tabs) { tab in
            Text(tab.title)
                .font(Typography.labelLarge)
                .foregroundColor(tab == selectedTab ? Colors.textPrimary : Colors.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }
}
.frame(height: 36)
.padding(Spacing.xxs)
```

### 5.4 Header Redesign

**Current:** Heavy with multiple elements
**New:** Minimal, floating header

```swift
HStack(spacing: Spacing.lg) {
    // Simple wordmark
    Text("Searchy")
        .font(Typography.titleMedium)
        .foregroundColor(Colors.textPrimary)

    // Subtle status pill (only when relevant)
    if isIndexing {
        HStack(spacing: Spacing.xs) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Indexing...")
                .font(Typography.labelMedium)
        }
        .foregroundColor(Colors.accentPrimary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Colors.accentSubtle)
        .clipShape(Capsule())
    }

    Spacer()

    // Icon-only action buttons
    HStack(spacing: Spacing.sm) {
        IconButton(icon: "plus", action: indexFolder)
        IconButton(icon: "gearshape", action: openSettings)
    }
}
.padding(.horizontal, Spacing.xl)
.padding(.vertical, Spacing.lg)
```

### 5.5 Filter Sidebar

**Current:** Cramped with generic styling
**New:** Airy floating panel

```swift
// Floating filter panel with backdrop blur
VStack(alignment: .leading, spacing: Spacing.xl) {
    // Header with close
    HStack {
        Text("Filters")
            .font(Typography.titleSmall)
        Spacer()
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Colors.textTertiary)
                .frame(width: 24, height: 24)
                .background(Colors.surface2)
                .clipShape(Circle())
        }
    }

    // Filter chips - inline style
    FilterSection(title: "Type") {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(types) { type in
                FilterChip(label: type, isSelected: selected.contains(type))
            }
        }
    }

    // Size presets as pills
    FilterSection(title: "Size") {
        HStack(spacing: Spacing.xs) {
            SizePreset(label: "< 1MB", ...)
            SizePreset(label: "1-5MB", ...)
            SizePreset(label: "> 5MB", ...)
        }
    }
}
.padding(Spacing.xl)
.frame(width: 240)
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: Radius.lg))
.shadow(Shadows.lg)
```

### 5.6 Duplicate Groups

**Current:** Dense, card-heavy
**New:** Clean list with thumbnail strip

```swift
// Horizontal scrolling thumbnails for each group
VStack(alignment: .leading, spacing: Spacing.md) {
    // Group header inline
    HStack {
        Text("Group \(id)")
            .font(Typography.labelLarge)
            .foregroundColor(Colors.textSecondary)

        Spacer()

        Button("Keep largest") {
            autoSelectSmaller()
        }
        .font(Typography.labelMedium)
        .foregroundColor(Colors.accentPrimary)
    }

    // Thumbnail strip
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Spacing.sm) {
            ForEach(images) { image in
                DuplicateThumbnail(image: image, isFirst: index == 0)
            }
        }
        .padding(.horizontal, Spacing.xxs)
    }
}
.padding(Spacing.lg)
.background(Colors.surface1)
.clipShape(RoundedRectangle(cornerRadius: Radius.md))
```

---

## 6. Micro-interactions & Animations

### Hover States
```swift
// Consistent hover scale
.scaleEffect(isHovered ? 1.02 : 1.0)
.animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)

// Subtle brightness lift
.brightness(isHovered ? 0.02 : 0)
```

### Loading States
```swift
// Custom shimmer effect
.shimmer(isLoading: isLoading)

// Implementation using gradient animation
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.2), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200 - 100)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
```

### Button Press
```swift
// Tactile press feedback
.scaleEffect(isPressed ? 0.96 : 1.0)
.opacity(isPressed ? 0.8 : 1.0)
.animation(.spring(response: 0.15), value: isPressed)
```

---

## 7. Spotlight Search Window

### Current Problems
- Feels disconnected from main app
- Heavy visual weight

### New Design
```swift
// Ultra-clean floating panel
VStack(spacing: 0) {
    // Minimal search field
    HStack(spacing: Spacing.md) {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(Colors.textTertiary)

        TextField("Search...", text: $query)
            .font(Typography.titleMedium)
            .textFieldStyle(.plain)
    }
    .padding(Spacing.xl)

    // Results (if any)
    if !results.isEmpty {
        Divider()
            .padding(.horizontal, Spacing.lg)

        ScrollView {
            VStack(spacing: Spacing.xxs) {
                ForEach(results.prefix(8)) { result in
                    SpotlightRow(result: result, isSelected: ...)
                }
            }
            .padding(Spacing.sm)
        }
        .frame(maxHeight: 400)
    }

    // Keyboard hints
    HStack(spacing: Spacing.lg) {
        KeyHint(keys: "↑↓", label: "Navigate")
        KeyHint(keys: "↵", label: "Copy")
        KeyHint(keys: "⌘↵", label: "Reveal")
        KeyHint(keys: "esc", label: "Close")
    }
    .font(Typography.labelSmall)
    .foregroundColor(Colors.textTertiary)
    .padding(Spacing.md)
    .background(Colors.surface2.opacity(0.5))
}
.frame(width: 560)
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: Radius.xl))
.shadow(Shadows.lg)
```

---

## 8. Settings Panel Redesign

### Current: Verbose sections with heavy styling
### New: Clean grouped settings

```swift
// Simple grouped layout
ScrollView {
    VStack(spacing: Spacing.xxxl) {
        SettingsGroup("Display") {
            SettingRow(
                icon: "square.grid.3x3",
                title: "Grid columns",
                control: Stepper(value: $columns, in: 2...6)
            )

            SettingRow(
                icon: "photo",
                title: "Thumbnail size",
                control: Slider(value: $size, in: 100...400)
            )
        }

        SettingsGroup("Search") {
            SettingRow(
                icon: "number",
                title: "Max results",
                control: Picker(...)
            )
        }

        SettingsGroup("Directories") {
            ForEach(directories) { dir in
                DirectoryRow(directory: dir)
            }

            Button(action: addDirectory) {
                Label("Add Directory", systemImage: "plus")
            }
        }
    }
    .padding(Spacing.xxl)
}
```

---

## 9. Implementation Order

### Phase 1: Foundation (Day 1)
1. Replace DesignSystem colors with new palette
2. Update Typography struct
3. Update Spacing and Radius values
4. Update Shadows system

### Phase 2: Core Components (Day 2-3)
1. Search bar redesign
2. Header simplification
3. Tab picker with sliding indicator
4. Result card redesign

### Phase 3: Secondary Views (Day 3-4)
1. Filter sidebar
2. Duplicates view
3. Empty states
4. Settings panel

### Phase 4: Polish (Day 4-5)
1. Spotlight window
2. Micro-interactions
3. Loading states
4. Dark mode refinement

---

## 10. Files to Modify

| File | Changes |
|------|---------|
| `ContentView.swift` | All UI components, DesignSystem struct |
| `Assets.xcassets` | Add color set assets if using asset catalog |

---

## Visual Reference

```
┌─────────────────────────────────────────────────────┐
│  Searchy                              [+] [⚙]       │  <- Minimal header
├─────────────────────────────────────────────────────┤
│                                                     │
│   ┌───────────────────────────────────────────┐    │
│   │ 🔍  Search your images...                 │    │  <- Floating search
│   └───────────────────────────────────────────┘    │
│                                                     │
│   [  Search  ] [  Duplicates  ]                    │  <- Pill tabs
│                                                     │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│   │         │  │         │  │         │           │  <- Borderless cards
│   │   IMG   │  │   IMG   │  │   IMG   │           │
│   │         │  │         │  │         │           │
│   │ name 87%│  │ name 76%│  │ name 72%│           │
│   └─────────┘  └─────────┘  └─────────┘           │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

This plan transforms Searchy from a "works fine" utility app into a polished, premium macOS experience that users will want to show off.
