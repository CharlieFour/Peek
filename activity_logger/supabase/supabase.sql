create table devices (
  id uuid primary key default uuid_generate_v4(),
  hostname text,
  ip_address text,
  os text,
  last_seen timestamp default now()
);

create table key_logs (
  id serial primary key,
  device_id text,
  app_name text,
  keystroke text,
  timestamp timestamp
);

create table activity_logs (
  id serial primary key,
  device_id text,
  process_name text,
  window_title text,
  timestamp timestamp
);
