# Kovunela — Visual Design Direction and UI Foundation

Status: Approved product design direction; implementation not started
Date: 2026-11-05
Source: product owner selected recommendation B from three concept boards.
Repository still uses internal working name Curio; public product candidate name Kovunela pending formal trademark clearance.

## 1. Selected design
**B — Warm & Inviting** is the primary visual direction.
- Friendly, contemporary, approachable, calm; suited to collectors, households and general personal inventory users.
- AI-first capture experience is the most prominent primary action.
- Use the clear content hierarchy, efficient dashboard composition and information density principles of concept A.
- Use concept C only as inspiration for an optional, equally accessible dark theme—not as the default styling.
- The generated concept board is visual inspiration, not an exact specification of iconography, photography, text, figures, layouts or final logo.

## 2. Initial design tokens (provisional; accessibility review required)
| Token | Suggested light value | Use |
|---|---|---|
| brand.primary | #0F766E | Primary actions, active states |
| brand.secondary | #14B8A6 | Secondary accents |
| brand.mint | #A7F3D0 | Subtle highlights |
| surface.warm | #F8FAF8 | Warm soft surfaces |
| surface.base | #F1F5F9 | Neutral background |
| text.primary | #143A35 (proposed) | Text on light surfaces |
| text.secondary | #4B615D (proposed) | Secondary text |

These hex values are draft tokens from the concept artwork plus proposed readable text colors, NOT a contrast-certified palette. Verify WCAG contrast for all text, controls and focus states, including dark mode, before implementation acceptance.
Typography candidate: Inter or Manrope with system font fallbacks and proper licensing. Do not embed or redistribute unauthorized font files.

## 3. Layout strategy
- Android/iOS phone: compact landing dashboard, direct camera/scan/manual capture, bottom navigation, one-handed critical actions, clear progress of AI recognition and user confirmation.
- Tablet: adaptive grid/card density, split views only where useful.
- Wide web browser: persistent sidebar/rail, searchable tables and grid, keyboard-first operations, multi-select/batch actions later.
- Unified component and design token system across Flutter Android, iOS and Web.
- User-controlled light/dark mode; system preference honored. Dark theme must not simply invert colors.

## 4. IA / initial navigation
Primary: Start, Collections, Capture, Locations, Search/AI.
Global: Profile, current workspace switcher and settings; private/household context must remain understandable.
No fabricated item counts on real screens. Empty states emphasize first useful action.
Capture flow: photo/scan/text -> analysis suggestion -> review/edit -> choose owner/workspace, collection and location optionally -> confirm save.
Manual fallback if AI fails or user opts out.

## 5. Brand and website rules
- Working brand: Kovunela, not yet legally cleared as a trademark.
- Domains kovunela.com, kovunela.app and kovunela.de reportedly registered by project owner; never disclose registrar credentials.
- Preferred structure: public marketing website on root .com, authenticated Flutter Web on app.kovunela.com, optional redirect for .app and German /de.
- Brand identity, logo artwork, product illustrations, app icon, favicon and responsive website still require design, review and asset licensing checks.
- Do not rename the GitHub repository, bundle identifier, app store listings, Supabase projects or production DNS until branding and technical transition plan is approved.

## 6. Usability and quality acceptance criteria
1. New user can start capturing an item from the first main screen without creating a collection first.
2. AI suggestions are clearly labeled, editable and require explicit confirmation; sources and uncertainty are communicated.
3. Private vs shared workspace is recognizable at a glance; sharing is deliberate and never implied.
4. Touch targets, scale, assistive technology, keyboard navigation and focus indicators work across platforms.
5. Light and dark themes meet target WCAG AA contrast for normal text (4.5:1) and large text (3:1) where applicable.
6. Narrow mobile, tablet and desktop web layouts work without horizontal scrolling in primary flows.
7. Loading, offline, no-results, permission denial and AI-error states have clear next actions.

## 7. Next deliverables
- Design-token definition and Flutter ThemeData implementation.
- Reusable component library (buttons, chips, object cards, list rows, form controls, AI suggestion panels).
- Responsive mobile/web high-fidelity screens for Start, Collection, Item, Capture/Review and Workspace.
- Logo and app icon concepts for approval, then export of accessible final assets.
- Public landing page design consistent with app (implementation separate from authenticated Flutter frontend).
