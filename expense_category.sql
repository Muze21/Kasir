-- MIGRASI: Tambah kategori pengeluaran (V2)
-- Jalankan SEKALI di SQL Editor. Aman dijalankan ulang (IF NOT EXISTS).
alter table public.expenses
  add column if not exists category text not null default 'Operasional'
  check (category in ('Bahan Baku', 'Operasional', 'Transport', 'Lainnya'));