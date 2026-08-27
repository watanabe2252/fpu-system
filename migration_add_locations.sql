-- ============================================================
-- 地点(受信点)の緯度経度を保存するテーブルを追加
--
-- links.name は「グランコート→本社仮設1」のように矢印区切りの
-- 地点名で構成されているため、地点名(program_id + name)ごとに
-- 座標を1件持たせる設計にしている。
-- 権限は既存の is_admin() ヘルパー(migration_rls_hardening.sqlで
-- 作成済み)を再利用する。
-- ============================================================

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  program_id text not null references public.programs(id) on delete cascade,
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now(),
  unique (program_id, name)
);

alter table public.locations enable row level security;

drop policy if exists "locations_select_authenticated" on public.locations;
create policy "locations_select_authenticated" on public.locations
  for select to authenticated using (true);

drop policy if exists "locations_admin_write" on public.locations;
create policy "locations_admin_write" on public.locations
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- 確認用
select tablename, policyname, permissive, roles, cmd
from pg_policies
where schemaname = 'public' and tablename = 'locations';
