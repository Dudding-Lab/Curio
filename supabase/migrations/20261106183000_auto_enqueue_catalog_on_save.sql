create or replace function kovunela_catalog.enqueue_item_contribution()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
begin
 if new.deleted_at is not null then
   delete from kovunela_catalog.contribution_queue where item_id = new.id;
 else
   insert into kovunela_catalog.contribution_queue
     (item_id, workspace_id, state, attempt_count, last_error, queued_at, processed_at, confirmed_at, confirmed_item_updated_at)
   values (new.id, new.workspace_id, 'pending', 0, null, now(), null, now(), new.updated_at)
   on conflict (item_id) do update set
     workspace_id = excluded.workspace_id,
     state = 'pending',
     attempt_count = 0,
     last_error = null,
     queued_at = now(),
     processed_at = null,
     confirmed_at = now(),
     confirmed_item_updated_at = excluded.confirmed_item_updated_at;
 end if;
 return new;
end;
$fn$;
create trigger enqueue_catalog_contribution
after insert or update of title, attributes, category_id, template_version_id, deleted_at
on kovunela.items for each row execute function kovunela_catalog.enqueue_item_contribution();
