-- 1. Tabel Profiles (nama member)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  created_at timestamptz default now()
);

-- 2. Tabel Transactions (pemasukan & pengeluaran)
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('income', 'expense')),
  amount numeric not null check (amount > 0),
  category text not null,
  note text,
  transaction_date date default current_date,
  user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now()
);

-- 3. Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.transactions enable row level security;

create policy "Allow authenticated read profiles"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Allow user to manage own profile"
  on public.profiles for all
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Allow authenticated read transactions"
  on public.transactions for select
  to authenticated
  using (true);

create policy "Allow authenticated insert transactions"
  on public.transactions for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Allow authenticated delete transactions"
  on public.transactions for delete
  to authenticated
  using (auth.uid() = user_id);

-- 4. Trigger auto-create profile saat user daftar
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
