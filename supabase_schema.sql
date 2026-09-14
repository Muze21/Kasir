-- ============================================================
-- KASKITA - SUPABASE SCHEMA LENGKAP (1 file)
-- Cukup jalankan file ini SEKALI di SQL Editor.
-- ============================================================

-- 1. PROFILES (akun anggota keluarga)
-- Autentikasi dilayani Supabase Auth (auth.users). Profil dibuat otomatis
-- oleh trigger saat user daftar/login pertama kali.
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  created_at timestamptz default now()
);

-- 2. SHIFTS (sesi buka/tutup toko — dipakai BERSAMA semua user)
create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  opened_at timestamptz default now(),
  closed_at timestamptz,
  status text check (status in ('open', 'closed')) default 'open',
  opened_by uuid default auth.uid() references public.profiles(id),
  closed_by uuid references public.profiles(id)
);

-- 3. ORDERS (satu keranjang/pesanan pelanggan)
-- queue_number : global per shift (Pelanggan 1, 2, 3...) di-generate trigger
-- user_id      : SIAPA yang menginput order (dipakai laporan per user)
-- payment_method : 'cash' / 'qris' (tanpa gateway pembayaran)
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  shift_id uuid references public.shifts(id) on delete cascade not null,
  queue_number int not null,
  customer_name text,
  total_amount numeric default 0 check (total_amount >= 0),
  payment_method text check (payment_method in ('cash', 'qris')),
  user_id uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz default now()
);

-- 4. ORDER ITEMS (isi keranjang)
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete cascade not null,
  item_name text not null,
  qty int not null check (qty > 0),
  price numeric not null check (price >= 0),
  subtotal numeric not null check (subtotal >= 0)
);

-- 5. EXPENSES (pengeluaran selama shift)
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  shift_id uuid references public.shifts(id) on delete cascade,
  note text not null,
  amount numeric not null check (amount > 0),
  user_id uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz default now()
);

-- 6. TRIGGER: auto-create profile saat ada user auth baru
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 7. TRIGGER: queue_number otomatis 1, 2, 3... (global per shift)
create or replace function public.set_order_queue_number()
returns trigger as $$
declare
  next_num int;
begin
  select coalesce(max(queue_number), 0) + 1 into next_num
  from public.orders
  where shift_id = new.shift_id;

  new.queue_number := next_num;
  if new.customer_name is null then
    new.customer_name := 'Pelanggan ' || next_num;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_order_insert on public.orders;
create trigger on_order_insert
  before insert on public.orders
  for each row execute procedure public.set_order_queue_number();

-- 8. PENJAGA: hanya boleh SATU shift 'open' di seluruh database.
-- Ampuh terhadap race (2 device tekan "Buka Toko" bersamaan).
-- Insert shift open kedua otomatis gagal di level database.
create unique index if not exists one_open_shift_idx
  on public.shifts (status)
  where status = 'open';

-- 9. ROW LEVEL SECURITY
-- Status: SDK Flutter pakai anon/publishable key. RLS dibuka untuk semua
-- user authenticated karena ini aplikasi keluarga (semua member dipercaya).
alter table public.profiles enable row level security;
alter table public.shifts enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
-- 10. PRODUCTS / MENU TOKO
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric not null check (price >= 0),
  category text not null default 'Makanan',
  is_available boolean default true,
  created_at timestamptz default now()
);

alter table public.products enable row level security;
create policy "Auth access products" on public.products
  for all to authenticated using (true) with check (true);

-- Insert default sample products
insert into public.products (name, price, category)
values
  ('soto nasi', 12000, 'Makanan'),
  ('kerupuk gede', 5000, 'Makanan'),
  ('kerupuk kecil', 2000, 'Makanan')
on conflict do nothing;