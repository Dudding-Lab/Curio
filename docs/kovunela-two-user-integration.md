# Kovunela — real Supabase Auth isolation test

Project: Curio, `tgawxheqrcqhcvxaexvd` (non-production).
Test file: `flutter_app/test/two_user_supabase_integration_test.dart`.

## Why accounts are not automatically provisioned
The currently connected Supabase integration permits SQL and schema operations but exposes no supported Auth Admin create-user action. Direct inserts into `auth.users` are NOT a valid Supabase Auth API workflow and are deliberately avoided. The test uses real, separately authenticated sessions, not SQL editor session impersonation.

## Create the two test identities using Supabase's supported interface
1. Open [Supabase Auth Users](https://supabase.com/dashboard/project/tgawxheqrcqhcvxaexvd/auth/users).
2. Use **Add user** to invite or create **two separate, disposable addresses you control**. Mark them confirmed only through the supported Supabase Auth UI. Use unique strong test passwords. Do not paste the passwords or API tokens into ChatGPT or commit them to Git.
3. Ensure both users can sign in independently. Keep the existing user account untouched.
4. Store the credentials securely on your development workstation or an appropriately protected CI environment.

## Run locally
From `flutter_app`, supply all six values through **local environment / tool secrets** using Dart defines (do not check command history containing plaintext passwords into logs). Example argument names:

- `KOVUNELA_TEST_SUPABASE_URL`: `https://tgawxheqrcqhcvxaexvd.supabase.co`
- `KOVUNELA_TEST_SUPABASE_PUBLISHABLE_KEY`: project's **publishable** key (never a service-role key)
- `KOVUNELA_TEST_EMAIL_A`, `KOVUNELA_TEST_PASSWORD_A`
- `KOVUNELA_TEST_EMAIL_B`, `KOVUNELA_TEST_PASSWORD_B`

`flutter test test/two_user_supabase_integration_test.dart` with the corresponding `--dart-define=NAME=VALUE` values. Use a secret-aware runner or secured local environment to prevent credentials appearing in terminal history. In ordinary CI without these variables, the integration test is **skipped** rather than incorrectly reporting passed isolation.

## Expected real results
- A and B authenticate with different Supabase Auth UIDs.
- A creates an item through `kv_create_personal_item` and sees it through `kv_list_personal_items`; B cannot see that item.
- B creates another item and A cannot see it.
- Anonymous create/list are rejected; blank title is rejected.
- Database table grants additionally confirm that neither `anon` nor `authenticated` can read/insert directly into `kovunela.items`.
- Real tests leave clearly marked items in the non-production database; they should be cleaned up once the audited soft-delete API exists.

## Current verified DB grants, 2026-11-06
| Role | Create RPC | List RPC | Direct INSERT on kovunela.items | Direct SELECT |
|---|---|---|---|---|
| anon | DENIED | DENIED | DENIED | DENIED |
| authenticated | ALLOWED | ALLOWED | DENIED | DENIED |

**Do not enable `KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE` by default until a genuine two-session integration run passes.** No Auth test user has been created through the connected Supabase integration.
