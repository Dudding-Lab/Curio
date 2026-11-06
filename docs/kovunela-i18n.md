# Kovunela Internationalization (i18n / l10n)

Decision: ship core flows in **German (de), English (en), French (fr), Spanish (es), Italian (it) and Brazilian Portuguese (pt-BR)** on Android, iOS and Web.

## Implementation
- Flutter official gen-l10n with versioned ARB files in `flutter_app/lib/l10n`.
- `app_en.arb` is the template; other locales match its translation keys. All keys must be translated before a locale's release.
- Default to device/browser locale; users must be able to explicitly choose a language and return to system settings. Persist preference in app/account settings before first release, synchronizing when signed in.
- `MaterialApp.router` includes generated localizations and platform delegates. Avoid hard-coded user-facing strings in newly built widgets.
- The initial files cover a **starter vocabulary only**. Legacy auth/household/collection screens still contain German-only strings and require migration. **Do not claim full localization until covered by tests.**
- Dates, pluralization, amounts, measurements, sorting and currencies should use locale-aware formatters. Never translate user-entered object titles without permission.
- Curio AI should answer in the user-selected locale. Factual catalog data may retain its original source language, with optional localized display names and translation provenance.
- Public marketing website, legal notices, accessibility text, transaction emails and store metadata need their own complete translation processes.
- Prepare RTL layout and localization tests for future languages such as Arabic, but do not mark unimplemented locales supported.

## Required validation
1. CI generates localization bindings and fails on missing required keys or code-gen errors.
2. Core capture, review, save, search, collections and workspace-sharing flows have no untranslated static user-facing strings.
3. Test locale switching and platform locale changes, especially en/de, with pt-BR fallback behavior.
4. Verify long labels, dynamic text scale, screen readers and browser/mobile form factor layouts.
5. Professional language review before public release; machine-generated strings are drafts only.

## Implementation checkpoint (2026-11-05)
- Generated ARB catalog now includes a `pt` fallback in addition to `pt_BR` (required by gen-l10n).
- `selectedLocaleProvider` and `KovunelaLanguageMenu` support system language or six explicit languages; selection persists on the local device via `shared_preferences`.
- Login, household list and collection list now use generated localization strings for principal static messages and controls.
- Legacy Supabase AuthException messages may still be supplied by the backend in English; translate known error codes safely later rather than matching arbitrary error text.
- Locale preference is **not yet synchronized across devices**. Add a user profile preference and conflict policy in a reviewed future database migration; do not change production schema implicitly.
- These translations are initial drafts and require native-language QA before public release.
- CI must pass localization generation, Dart formatting, static analysis and tests before merging. Current status must be checked in GitHub Actions.
