-- FlowProperty and UnitGroup support snapshots protect identity, ownership,
-- state, payload, and modified_at. Their generated markdown and full-text
-- embedding columns are not part of that proof, so derivative workers can
-- safely update those columns without taking the scope-wide actor fence.

drop trigger if exists dataset_flow_identity_flowproperty_active_fence
  on public.flowproperties;
drop trigger if exists dataset_flow_identity_flowproperty_delete_active_fence
  on public.flowproperties;

create trigger dataset_flow_identity_flowproperty_active_fence
before update on public.flowproperties
for each row
when (
  (to_jsonb(new) - array[
    'extracted_md',
    'embedding_ft',
    'embedding_ft_at'
  ]::text[])
  is distinct from
  (to_jsonb(old) - array[
    'extracted_md',
    'embedding_ft',
    'embedding_ft_at'
  ]::text[])
)
execute function private.dataset_flow_identity_active_fence_v2();

create trigger dataset_flow_identity_flowproperty_delete_active_fence
before delete on public.flowproperties
for each row
execute function private.dataset_flow_identity_active_fence_v2();

comment on trigger dataset_flow_identity_flowproperty_active_fence
  on public.flowproperties is
  'Fail-closed Step 3 actor fence for FlowProperty updates that change any support-guard-relevant or future non-derivative column; extracted_md, embedding_ft, and embedding_ft_at updates bypass the actor fence.';

comment on trigger dataset_flow_identity_flowproperty_delete_active_fence
  on public.flowproperties is
  'Fail-closed Step 3 actor fence for every FlowProperty delete.';

drop trigger if exists dataset_flow_identity_unitgroup_active_fence
  on public.unitgroups;
drop trigger if exists dataset_flow_identity_unitgroup_delete_active_fence
  on public.unitgroups;

create trigger dataset_flow_identity_unitgroup_active_fence
before update on public.unitgroups
for each row
when (
  (to_jsonb(new) - array[
    'extracted_md',
    'embedding_ft',
    'embedding_ft_at'
  ]::text[])
  is distinct from
  (to_jsonb(old) - array[
    'extracted_md',
    'embedding_ft',
    'embedding_ft_at'
  ]::text[])
)
execute function private.dataset_flow_identity_active_fence_v2();

create trigger dataset_flow_identity_unitgroup_delete_active_fence
before delete on public.unitgroups
for each row
execute function private.dataset_flow_identity_active_fence_v2();

comment on trigger dataset_flow_identity_unitgroup_active_fence
  on public.unitgroups is
  'Fail-closed Step 3 actor fence for UnitGroup updates that change any support-guard-relevant or future non-derivative column; extracted_md, embedding_ft, and embedding_ft_at updates bypass the actor fence.';

comment on trigger dataset_flow_identity_unitgroup_delete_active_fence
  on public.unitgroups is
  'Fail-closed Step 3 actor fence for every UnitGroup delete.';
