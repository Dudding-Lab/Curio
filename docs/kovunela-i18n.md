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
