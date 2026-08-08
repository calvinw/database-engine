begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public, auth;

select plan(23);

select ok(
  exists (
    select 1
    from storage.buckets
    where id = 'sys-files'
      and name = 'sys-files'
  ),
  'sys-files bucket exists'
);

select is(
  (select public from storage.buckets where id = 'sys-files'),
  false,
  'sys-files bucket is private'
);

select is(
  (select file_size_limit from storage.buckets where id = 'sys-files'),
  52428800::bigint,
  'sys-files bucket has the repository-owned 50 MiB limit'
);

select ok(
  'image/*' = any (
    select unnest(allowed_mime_types)
    from storage.buckets
    where id = 'sys-files'
  ),
  'sys-files bucket accepts image MIME types'
);

select ok(
  'video/mp4' = any (
    select unnest(allowed_mime_types)
    from storage.buckets
    where id = 'sys-files'
  ),
  'sys-files bucket retains MP4 support for the Welcome guide video'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'sys_files_team_assets_read',
        'sys_files_team_logos_insert',
        'sys_files_team_logos_delete'
      )
  ),
  3::bigint,
  'all sys-files Team asset policies exist'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.storage_can_upload_team_logo()',
    'execute'
  ),
  'authenticated users can invoke the internal upload authorization helper'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.storage_can_upload_team_logo()',
    'execute'
  ),
  'anonymous users cannot invoke the upload authorization helper'
);

select ok(
  not has_function_privilege(
    'service_role',
    'private.storage_can_upload_team_logo()',
    'execute'
  ),
  'the helper does not add a service-role capability'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.storage_can_delete_team_logo(text)',
    'execute'
  ),
  'anonymous users cannot invoke the delete authorization helper'
);

select ok(
  not exists (
    select 1
    from pg_proc as routine
    join pg_namespace as namespace on namespace.oid = routine.pronamespace
    where namespace.nspname in ('public', 'api')
      and routine.proname in (
        'storage_can_upload_team_logo',
        'storage_can_delete_team_logo'
      )
  ),
  'Storage authorization helpers are absent from exposed Data API schemas'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_sso_user,
  is_anonymous
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '87000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'logo-owner@example.com',
    'test-password-hash',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"sub":"87000000-0000-0000-0000-000000000001"}'::jsonb,
    now(),
    now(),
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '87000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'logo-admin@example.com',
    'test-password-hash',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"sub":"87000000-0000-0000-0000-000000000002"}'::jsonb,
    now(),
    now(),
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '87000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'logo-member@example.com',
    'test-password-hash',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"sub":"87000000-0000-0000-0000-000000000003"}'::jsonb,
    now(),
    now(),
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '87000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'logo-new-team@example.com',
    'test-password-hash',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"sub":"87000000-0000-0000-0000-000000000004"}'::jsonb,
    now(),
    now(),
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '87000000-0000-0000-0000-000000000005',
    'authenticated',
    'authenticated',
    'logo-system-admin@example.com',
    'test-password-hash',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"sub":"87000000-0000-0000-0000-000000000005"}'::jsonb,
    now(),
    now(),
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '87000000-0000-0000-0000-000000000006',
    'authenticated',
    'authenticated',
    'logo-system-member@example.com',
    'test-password-hash',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"sub":"87000000-0000-0000-0000-000000000006"}'::jsonb,
    now(),
    now(),
    false,
    false
  );

insert into private.teams (id, json, rank, is_public, modified_at)
values (
  '88000000-0000-0000-0000-000000000001',
  '{
    "lightLogo":"../sys-files/logo/team-light.svg",
    "darkLogo":"../sys-files/logo/team-dark.png"
  }'::jsonb,
  0,
  true,
  now()
);

insert into private.roles (user_id, team_id, role, modified_at)
values
  (
    '87000000-0000-0000-0000-000000000001',
    '88000000-0000-0000-0000-000000000001',
    'owner',
    now()
  ),
  (
    '87000000-0000-0000-0000-000000000002',
    '88000000-0000-0000-0000-000000000001',
    'admin',
    now()
  ),
  (
    '87000000-0000-0000-0000-000000000003',
    '88000000-0000-0000-0000-000000000001',
    'member',
    now()
  ),
  (
    '87000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000000',
    'admin',
    now()
  ),
  (
    '87000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000000',
    'member',
    now()
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '87000000-0000-0000-0000-000000000004', true);

select ok(
  private.storage_can_upload_team_logo(),
  'a user without a team may upload logos while creating a team'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '87000000-0000-0000-0000-000000000001', true);

select ok(
  private.storage_can_upload_team_logo(),
  'a team owner may upload a replacement logo'
);

select ok(
  private.storage_can_delete_team_logo('logo/team-light.svg'),
  'a team owner may delete a logo referenced by the team'
);

select ok(
  not private.storage_can_delete_team_logo('logo/unreferenced.svg'),
  'a team owner may not delete an unreferenced logo uploaded by another user'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '87000000-0000-0000-0000-000000000002', true);

select ok(
  private.storage_can_upload_team_logo(),
  'a team admin may upload a replacement logo'
);

select ok(
  private.storage_can_delete_team_logo('logo/team-dark.png'),
  'a team admin may delete a logo referenced by the team'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '87000000-0000-0000-0000-000000000003', true);

select ok(
  not private.storage_can_upload_team_logo(),
  'a team member may not upload a team logo'
);

select ok(
  not private.storage_can_delete_team_logo('logo/team-light.svg'),
  'a team member may not delete a team logo'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '87000000-0000-0000-0000-000000000005', true);

select ok(
  private.storage_can_upload_team_logo(),
  'a System admin may upload a replacement team logo'
);

select ok(
  private.storage_can_delete_team_logo('logo/team-light.svg'),
  'a System admin may delete a logo referenced by a managed team'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '87000000-0000-0000-0000-000000000006', true);

select ok(
  not private.storage_can_upload_team_logo(),
  'a System member may not upload a replacement team logo'
);

select ok(
  not private.storage_can_delete_team_logo('logo/team-light.svg'),
  'a System member may not delete a team logo'
);

select * from finish();

rollback;
