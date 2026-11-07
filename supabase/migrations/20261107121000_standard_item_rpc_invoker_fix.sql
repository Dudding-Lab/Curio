-- Keep the underlying function inaccessible to browser clients. The only
-- authenticated entry point executes with the wrapper owner's privileges;
-- the underlying function enforces auth.uid() and derives the workspace.
create or replace function public.kv_create_standard_personal_item(
  p_standard_code text, p_title text, p_description text, p_attributes jsonb
) returns uuid
language sql security definer set search_path=''
as $$
  select kovunela.create_standard_personal_item(
    p_standard_code, p_title, p_description, p_attributes
  );
$$;
revoke all on function public.kv_create_standard_personal_item(text,text,text,jsonb) from public, anon;
grant execute on function public.kv_create_standard_personal_item(text,text,text,jsonb) to authenticated;
