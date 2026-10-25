begin;

create or replace function public.attendance_checkout_allowed_at(instant timestamptz)
returns boolean language sql immutable set search_path = pg_catalog
as $$ select (instant at time zone 'Asia/Bangkok')::time >= time '15:00' $$;

-- Keep the existing attendance tables and history. Authenticated attendance
-- actions use server time in WIB, including calls made by older app versions.
create or replace function public.enforce_personal_attendance()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  server_now timestamptz := clock_timestamp();
  work_now timestamp := server_now at time zone 'Asia/Bangkok';
begin
  -- Database maintenance and service-role imports keep their existing access.
  if auth.uid() is null or auth.role() = 'service_role' then return new; end if;
  if new.user_id is distinct from auth.uid()::text then
    raise exception 'Absensi hanya dapat dicatat untuk akun sendiri.' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.check_in_time is null or new.check_out_time is not null then
      raise exception 'Absen masuk terlebih dahulu.' using errcode = '23514';
    end if;
    new.attendance_date := work_now::date;
    new.check_in_time := server_now;
    new.status := 'open';
  else
    if new.user_id is distinct from old.user_id or new.attendance_date is distinct from old.attendance_date then
      raise exception 'Akun dan tanggal absensi tidak dapat diubah.' using errcode = '23514';
    end if;
    if new.check_in_time is distinct from old.check_in_time
       or new.check_in_lat is distinct from old.check_in_lat
       or new.check_in_lng is distinct from old.check_in_lng then
      raise exception 'Absen masuk sudah tercatat dan tidak dapat ditimpa.' using errcode = '23514';
    end if;
    if old.check_out_time is not null and (
      new.check_out_time is distinct from old.check_out_time
      or new.check_out_lat is distinct from old.check_out_lat
      or new.check_out_lng is distinct from old.check_out_lng
      or new.status is distinct from old.status
    ) then
      raise exception 'Absensi hari ini sudah selesai.' using errcode = '23514';
    end if;
    if new.check_out_time is not null and old.check_out_time is null then
      if old.check_in_time is null then
        raise exception 'Absen masuk terlebih dahulu.' using errcode = '23514';
      end if;
      if old.attendance_date <> work_now::date then
        raise exception 'Absen pulang hanya untuk kehadiran hari ini.' using errcode = '23514';
      end if;
      if not public.attendance_checkout_allowed_at(server_now) then
        raise exception 'Absen pulang tersedia mulai pukul 15.00 WIB.' using errcode = '23514';
      end if;
      if new.check_out_lat is null or new.check_out_lng is null
         or not (new.check_out_lat between -90 and 90)
         or not (new.check_out_lng between -180 and 180) then
        raise exception 'Koordinat GPS pulang tidak valid.' using errcode = '23514';
      end if;
      new.check_out_time := server_now;
      new.status := 'closed';
    end if;
  end if;

  if new.check_in_lat is null or new.check_in_lng is null
     or not (new.check_in_lat between -90 and 90)
     or not (new.check_in_lng between -180 and 180) then
    raise exception 'Koordinat GPS masuk tidak valid.' using errcode = '23514';
  end if;
  if new.check_out_time is null and new.status is distinct from 'open' then
    raise exception 'Absen pulang belum tercatat.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_personal_attendance on public.attendance_header;
create trigger enforce_personal_attendance
before insert or update on public.attendance_header
for each row execute function public.enforce_personal_attendance();

-- Existing permissive policies are retained. These additional restrictive
-- policies make personal history and activity records account scoped.
drop policy if exists attendance_header_own_account on public.attendance_header;
create policy attendance_header_own_account on public.attendance_header
as restrictive for all to public
using (user_id = (select auth.uid())::text)
with check (user_id = (select auth.uid())::text);

drop policy if exists attendance_activity_own_account on public.attendance_activity;
create policy attendance_activity_own_account on public.attendance_activity
as restrictive for all to public
using (user_id::text = (select auth.uid())::text)
with check (
  user_id::text = (select auth.uid())::text and exists (
    select 1 from public.attendance_header h
    where h.attendance_id = attendance_activity.attendance_id
      and h.user_id = (select auth.uid())::text
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 3145728,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 3145728,
allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists profile_photos_own_account on storage.objects;
create policy profile_photos_own_account on storage.objects
for all to authenticated
using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Existing storage policies for other app buckets remain unchanged.
drop policy if exists profile_photos_restrict_account on storage.objects;
create policy profile_photos_restrict_account on storage.objects
as restrictive for all to public
using (bucket_id <> 'profile-photos' or (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id <> 'profile-photos' or (storage.foldername(name))[1] = (select auth.uid())::text);

commit;
