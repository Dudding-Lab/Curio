create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('kovunela-catalog-stage-pending','* * * * *', $$ select kovunela_catalog.process_contribution_batch(50); $$);
