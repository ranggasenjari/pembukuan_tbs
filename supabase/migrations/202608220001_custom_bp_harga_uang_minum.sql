-- Custom field BP, penyesuaian harga, dan uang minum pada kendaraan & relasi bayar.
-- - vehicles.uang_minum: potongan uang minum per kendaraan (nullable = ikut prioritas bawah).
-- - payment_relations.potongan_bp/harga/uang_minum: custom field per relasi bayar.

alter table inv.vehicles
  add column if not exists uang_minum integer;

alter table inv.payment_relations
  add column if not exists potongan_bp integer,
  add column if not exists harga integer,
  add column if not exists uang_minum integer;
