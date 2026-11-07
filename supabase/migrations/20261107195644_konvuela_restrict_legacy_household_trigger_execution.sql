-- Applied in Supabase production as migration 20261107195644
-- konvuela_restrict_legacy_household_trigger_execution
-- This is intentionally non-destructive; the installed trigger continues to fire.
revoke execute on function public.handle_new_household() from public, anon, authenticated;

-- Verify after application:
-- select has_function_privilege('anon','public.handle_new_household()','EXECUTE'),
--        has_function_privilege('authenticated','public.handle_new_household()','EXECUTE');
-- Both must return false.
--
-- Rollback, only if explicitly needed:
-- grant execute on function public.handle_new_household() to public;
