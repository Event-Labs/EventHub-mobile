---
name: EventHub Space Dark
colors:
  surface: '#0a1328'
  surface-dim: '#0a1328'
  surface-bright: '#303950'
  surface-container-lowest: '#050d22'
  surface-container-low: '#121b30'
  surface-container: '#161f35'
  surface-container-high: '#21293f'
  surface-container-highest: '#2c344b'
  on-surface: '#dae2ff'
  on-surface-variant: '#e0c0b1'
  inverse-surface: '#dae2ff'
  inverse-on-surface: '#273046'
  outline: '#a78b7d'
  outline-variant: '#584237'
  surface-tint: '#ffb690'
  primary: '#ffb690'
  on-primary: '#552100'
  primary-container: '#f97316'
  on-primary-container: '#582200'
  inverse-primary: '#9d4300'
  secondary: '#b0cadd'
  on-secondary: '#1a3342'
  secondary-container: '#334c5c'
  on-secondary-container: '#a2bcce'
  tertiary: '#ddb7ff'
  on-tertiary: '#490080'
  tertiary-container: '#be7bff'
  on-tertiary-container: '#4c0084'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbca'
  primary-fixed-dim: '#ffb690'
  on-primary-fixed: '#341100'
  on-primary-fixed-variant: '#783200'
  secondary-fixed: '#cce6fa'
  secondary-fixed-dim: '#b0cadd'
  on-secondary-fixed: '#021e2c'
  on-secondary-fixed-variant: '#314a59'
  tertiary-fixed: '#f0dbff'
  tertiary-fixed-dim: '#ddb7ff'
  on-tertiary-fixed: '#2c0051'
  on-tertiary-fixed-variant: '#6900b3'
  background: '#0a1328'
  on-background: '#dae2ff'
  surface-variant: '#2c344b'
typography:
  headline-xl:
    fontFamily: Geist
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Geist
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-lg:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Geist
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.005em
  headline-sm:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-lg-medium:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-md-medium:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.005em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
  code-ticket:
    fontFamily: Geist
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  space-2xs: 0.25rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
  space-2xl: 2rem
  space-3xl: 2.5rem
  margin-screen: 1rem
  gutter-grid: 0.75rem
  nav-bottom-height: 4rem
  touch-target-min: 2.75rem
---

## Brand & Style
This design system establishes a high-precision, atmospheric mobile interface engineered for nocturnal live events, festival management, and digital ticketing. The visual language blends deep cosmic nightscapes with energetic, functional signals—ensuring instant legibility in high-stimulus, dark environments like concert halls, stadium gates, and night markets.

The visual direction merges **glassmorphism** and **high-contrast functional modernism**:
- Deep cosmic navy backgrounds mimic infinite depth while eliminating OLED battery drain.
- Intense primary orange cues drive conversion and action points during fast checkouts.
- Tactical purple-violet glows signal automated, intelligent event features and real-time AI assistance.
- Physical event metaphors (scannable passes, perforated stub cuts, high-frequency QR codes) provide tangible continuity between screen interactions and physical venue admission.

## Colors
The palette utilizes layered navy tones to create architectural surface hierarchy, overlaid with purposeful, luminous accents for distinct functional contexts.

### Base Surfaces & Structure
- **Canvas / App Root (`#081126`)**: The deepest navy backdrop, grounding all screens and root layouts.
- **Surface / Bottom Sheets / Modals (`#0c1446`)**: Mid-tier structural elevation for interactive cards, modals, and sheets.
- **Surface Soft / Interactive Inputs (`#122155`)**: Recessed or elevated control containers, text fields, search bars, and active tabs.
- **Ghost Border / Border Hairlines (`rgba(179, 205, 224, 0.12)`)**: Defines edges of dark components without adding visual clutter.

### Accents & Semantic Color Signals
- **Brand CTA / Action Glow (`#f97316`)**: Reserved strictly for high-value actions: "Buy Ticket", "Confirm Entry", "Pay Now", and urgent notifications.
- **Primary Structural Accent (`#b3cde0`)**: Slate blue used for active icons, secondary labels, and structural highlights.
- **Secondary Atmospheric Accent (`#2b5c92`)**: Deep sky blue applied to badges, container fills, card dividers, and inactive state fills.
- **AI Concierge / Magic Feature (`#a855f7`)**: Exclusively reserved for smart recommendations, schedule automation, and AI companion tools.

### Content & Status
- **Text Primary (`#f8fafc`)**: Highest contrast slate white for headlines, critical data, ticket codes, and seat numbers.
- **Text Secondary (`#cbd5e1`)**: Muted slate for metadata, sub-labels, timestamps, and terms.
- **Text Tertiary (`#64748b`)**: Subtle helper copy, disabled text, and placeholder icons.
- **Success (`#22c55e`)**: Valid gate passes, paid transactions, and confirmed admissions.
- **Warning (`#f59e0b`)**: Low ticket inventory, closing gates, and delayed performances.
- **Error (`#ef4444`)**: Invalid or already redeemed QR codes, payment failures, and network timeouts.

## Typography
Typographic pairings use **Geist** for technical, high-impact headings and numeric data, combined with **Inter** for neutral legibility across long schedules, terms, and input forms.

- **Display & Headings (Geist)**: Delivers a clean, geometric structure for event titles, artist names, countdown timers, seat tiers, and ticket verification keys.
- **Content & Controls (Inter)**: Optimized for fast scanning under dim lighting conditions. Tight baseline alignment guarantees readability across nested table cells and line-item breakdowns.
- **Uppercase Labels**: Gate codes, pass tiers (e.g., VIP, GA, CREW), and ticket IDs must use `label-sm` or `code-ticket` with tabular numeric lining and expanded letter spacing for rapid scanning by staff.

## Layout & Spacing
The layout follows an 8pt base grid adjusted for edge-to-edge mobile screens with a 4pt subgrid for icons, micro-badges, and compact ticket tags.

### Mobile Grid & Safe Areas
- **Screen Margins**: Standard horizontal padding is 16px (`space-md`). For high-density staff verification grids, margins tighten to 12px (`space-sm`).
- **Touch Safe Boundaries**: Every tappable element enforces a strict minimum hit box of 44x44px (`touch-target-min`), irrespective of visual container size.
- **Fixed Bottom Clearances**: Any screen with a floating action button (FAB) or checkout bar must append 88px of bottom scroll inset padding to prevent overlay clipping by the 64px frosted bottom navigation bar.

### Screen Adaptations
- **Mobile (< 640px)**: Single-column linear streams, sticky bottom CTA trays, and swipe-up modal sheets.
- **Tablet / Large Venue Terminals (>= 640px)**: Dual-pane layout splitting the event feed / scanner view from the active attendee dossier or cart manifest.

## Elevation & Depth
This design system avoids harsh drop shadows, using tonal containment, luminous ambient blurs, and glassmorphic overlays to reflect high-tech spatial depth.

- **Ground Level (Base / 0)**: Tone `#081126`. Canvas background for screen views and base scroll streams.
- **Tier 1 (Surface / Elevated)**: Tone `#0c1446` with a crisp 1px stroke of `rgba(179, 205, 224, 0.08)`. Applied to standard event cards, lists, and summary panels.
- **Tier 2 (Modals, Ticket Sheets & Overlays)**: Tone `#0c1446` with a translucent glass background (`rgba(12, 20, 70, 0.85)`), 20px blur (`backdrop-filter: blur(20px)`), and a subtle 1px inner border (`rgba(248, 250, 252, 0.12)`).
- **Tier 3 (Floating Bars & Navigation)**: Frosted midnight sheet (`rgba(8, 17, 38, 0.92)`) with a top border highlight `rgba(179, 205, 224, 0.15)`.
- **Neon Cast Glows**: Interactive elements under focus emit soft, colored ambient halos:
  - CTA glow: `0 8px 24px rgba(249, 115, 22, 0.35)`
  - AI Genie glow: `0 8px 24px rgba(168, 85, 247, 0.35)`
  - Active Entry scan: `0 0 32px rgba(34, 197, 94, 0.4)`

## Shapes
Shapes balance fluid organic curvature with technical modular precision. Roundedness is keyed to interaction hierarchy:

- **Inputs & Standard Action Buttons**: `12px` (`rounded-xl` standard) to ensure clear, clickable boundaries.
- **Cards, Modals & Bottom Sheets**: `20px` to `24px` (`rounded-2xl` to `rounded-3xl`), framing complex modules and grouping data blocks cleanly.
- **Pills, Badges, Chips & Avatars**: `9999px` (`rounded-full`) for high contrast against rectilinear card blocks.
- **Ticket Stub Cutouts**: Inward radial masks (`r = 12px`) placed along the ticket divider seam to mimic perforated physical ticket stubs, reinforced by a dashed hairline rule.

## Components

### Buttons & CTAs
- **Primary Brand Button**: `#f97316` solid fill, text `#ffffff` (`body-md-medium`), border radius 12px, minimum height 48px. Features a 16px orange ambient drop shadow on press.
- **Secondary Ghost Button**: Surface `#122155` with 1px border `rgba(179, 205, 224, 0.25)`, text `#f8fafc`.
- **AI Assist Action Button**: Gradient fill from `#a855f7` to `#7e22ce`, text `#ffffff`, displaying an accompanying ambient glow.
- **Disabled State**: `#122155` at 50% opacity, border none, text `#64748b`.

### Cards & Event Displays
- **Standard Event Card**: Background `#0c1446`, 1px hairline `rgba(179, 205, 224, 0.1)`, 20px radius. Media cover has an aspect ratio of 16:9 with an inner bottom gradient (`rgba(8, 17, 38, 0.95)` to transparent) for title readability.
- **Digital Ticket Pass**: 2-part card separated by an SVG-masked semicircle cutout on both sides and a dashed separator border (`#2b5c92`). Top section houses event artwork, seat details, and date. Bottom section houses the high-contrast scannable QR code on a solid `#ffffff` inner plate with a 12px radius.

### Bottom Navigation Bar
- Height: 64px plus safe area inset bottom.
- Styling: `rgba(8, 17, 38, 0.95)` background with 16px blur and a 1px hairline top edge `rgba(179, 205, 224, 0.12)`.
- Icon alignment: Centered with 44px interactive hit area; active item tinted `#f97316` or `#b3cde0` with a 4px indicator dot beneath.

### Inputs & Form Controls
- **Input Fields**: Background `#122155`, radius 12px, height 48px, horizontal padding 16px. Border is 1px `transparent` at rest, transitioning to 1px `#b3cde0` on focus.
- **Checkboxes & Radios**: 22x22px with 6px border radius (or 9999px for radio). Inactive border `rgba(179, 205, 224, 0.3)`; active state fills `#f97316` with a white checkmark.

### Chips & Badges
- **Status & VIP Chips**: Height 24px to 28px, pill-shaped (`rounded-full`), padding 4px 12px. VIP chip: `#a855f7` at 15% opacity with `#a855f7` solid text. Active Gate chip: `#22c55e` at 15% opacity with `#22c55e` solid text.

### Staff Scanner Viewfinder
- Fullscreen camera viewfinder framed by an illuminated reticle target (260x260px) rounded at 24px with 4 corner guide strokes in `#f97316` or `#22c55e`. Center features an oscillating neon horizontal scan beam.