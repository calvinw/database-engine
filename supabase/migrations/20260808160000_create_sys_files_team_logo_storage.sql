begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'sys-files',
  'sys-files',
  false,
  52428800,
  array['image/*', 'video/mp4']::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.storage_can_upload_team_logo()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    auth.uid() is not null
    and (
      exists (
        select 1
        from private.roles as membership
        where membership.user_id = auth.uid()
          and membership.team_id <> '00000000-0000-0000-0000-000000000000'::uuid
          and membership.role in ('owner', 'admin')
      )
      or exists (
        select 1
        from private.roles as membership
        where membership.user_id = auth.uid()
          and membership.team_id = '00000000-0000-0000-0000-000000000000'::uuid
          and membership.role in ('owner', 'admin')
      )
      or (
        not exists (
          select 1
          from private.roles as membership
          where membership.user_id = auth.uid()
            and membership.team_id <> '00000000-0000-0000-0000-000000000000'::uuid
            and membership.role <> 'rejected'
        )
        and not exists (
          select 1
          from private.roles as membership
          where membership.user_id = auth.uid()
            and membership.team_id = '00000000-0000-0000-0000-000000000000'::uuid
            and membership.role in ('owner', 'admin', 'member')
        )
      )
    )
$function$;

create or replace function private.storage_can_delete_team_logo(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    auth.uid() is not null
    and exists (
      select 1
      from private.teams as team
      where (
          team.json ->> 'lightLogo' = '../sys-files/' || p_object_name
          or team.json ->> 'darkLogo' = '../sys-files/' || p_object_name
        )
        and (
          exists (
            select 1
            from private.roles as membership
            where membership.user_id = auth.uid()
              and membership.team_id = team.id
              and membership.role in ('owner', 'admin')
          )
          or exists (
            select 1
            from private.roles as system_membership
            where system_membership.user_id = auth.uid()
              and system_membership.team_id = '00000000-0000-0000-0000-000000000000'::uuid
              and system_membership.role in ('owner', 'admin')
          )
        )
    )
$function$;

revoke all on function private.storage_can_upload_team_logo()
  from public, anon, authenticated, service_role;
revoke all on function private.storage_can_delete_team_logo(text)
  from public, anon, authenticated, service_role;
grant execute on function private.storage_can_upload_team_logo() to authenticated;
grant execute on function private.storage_can_delete_team_logo(text) to authenticated;

drop policy if exists "sys_files_team_assets_read" on storage.objects;
create policy "sys_files_team_assets_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'sys-files'
  and (storage.foldername(name))[1] in ('logo', 'video')
);

drop policy if exists "sys_files_team_logos_insert" on storage.objects;
create policy "sys_files_team_logos_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'sys-files'
  and (storage.foldername(name))[1] = 'logo'
  and lower(storage.extension(name)) in ('jpeg', 'jpg', 'png', 'gif', 'bmp', 'webp', 'svg')
  and private.storage_can_upload_team_logo()
);

drop policy if exists "sys_files_team_logos_delete" on storage.objects;
create policy "sys_files_team_logos_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'sys-files'
  and (storage.foldername(name))[1] = 'logo'
  and (
    owner_id = auth.uid()::text
    or private.storage_can_delete_team_logo(name)
  )
);

commit;
