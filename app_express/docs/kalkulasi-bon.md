# Kalkulasi Bon Timbangan

## Input

| Field | Tipe | Sumber |
|-------|------|--------|
| `netto_1` | integer | Berat timbangan 1 (kg) |
| `netto_2` | integer | Berat timbangan 2 / bersih (kg) |
| `price` | integer | Harga per kg (Rupiah) |
| `factory_id` | uuid | ID pabrik (opsional) |
| `factory_spsi_type_id` | uuid | ID jenis SPSI (opsional) |
| `spsi_calculation_mode` | string | `PER_KG` atau `FIX` |
| `spsi_rate` | integer | Tarif SPSI |
| `biaya_bongkar` | integer | Biaya bongkar (sama dengan spsi_rate) |
| `bp_colt` | integer | Potongan BP/Colt (0, 50000, 70000, 100000) |
| `dp` | integer | DP / Panjar (Rupiah) |
| `uang_minum` | integer | Uang minum (default: 10000 atau 20000) |
| `deductions` | array | Potongan dinamis: `[{label, amount}]` |

## Prioritas Harga

```
body.price → vehicle.harga → factory_default_price → latest_bon_price
```

1. Jika `body.price` dikirim, pakai itu
2. Jika tidak, cek `vehicle.harga` dari tabel kendaraan (berdasarkan plat nomor)
3. Jika tidak, cek `factory_prices.is_default = true` untuk pabrik terkait
4. Jika tidak, ambil `price` dari bon terakhir

## Prioritas BP/Colt

```
body.bp_colt → vehicle.potongan_bp (jika body.bp_colt tidak dikirim atau 100000)
```

## Aturan Khusus

### Pabrik tanpa PPh dan Uang Minum
- Factory ID: `a536e3c0-7ea0-4003-9df0-c38721a9439b` (PT. AWAN ALAM ANUGRA)
- `pph = 0`
- `uang_minum = 0`

### PPh
```
jika factory_id = PT. AWAN:
    pph = 0
lainnya:
    jika pph dikirim manual:
        pph = input.pph
    jika tidak:
        pph = floor(0.0025 × price × netto_2)
```

### Uang Minum
```
jika factory_id = PT. AWAN:
    uang_minum = 0
lainnya:
    jika uang_minum dikirim manual:
        uang_minum = input.uang_minum
    jika tidak:
        jika netto_2 > 7000:
            uang_minum = 20000
        lainnya:
            uang_minum = 10000
```

### SPSI (Biaya Bongkar)
```
spsi_rate = input.spsi_rate jika ada, jika tidak = biaya_bongkar
spsi_calculation_mode = input.spsi_calculation_mode (default: PER_KG)

jika spsi_calculation_mode == 'FIX':
    total_biaya_bongkar = spsi_rate
lainnya (PER_KG):
    total_biaya_bongkar = spsi_rate × netto_1
```

### Potongan Lain (deductions)
```
Dipotong dari tabel bon_deductions (bukan kolom bons).
Sum of all deductions.amount:
  potongan_lain = sum of [{label, amount}]
```

## Kalkulasi Total

```
subtotal = price × netto_2
total = subtotal - dp - total_biaya_bongkar - bp_colt - pph - uang_minum - potongan_lain
```

## Output

| Field | Deskripsi |
|-------|-----------|
| `netto_1` | Sama dengan input |
| `netto_2` | Sama dengan input |
| `price` | Harga final setelah prioritas |
| `dp` | DP/Panjar |
| `biaya_bongkar` | Sama dengan spsi_rate |
| `spsi_calculation_mode` | PER_KG atau FIX |
| `spsi_rate` | Tarif SPSI final |
| `spsi_amount` | = total_biaya_bongkar |
| `bp_colt` | BP final |
| `pph` | PPh final |
| `uang_minum` | Uang minum final |
| `subtotal` | = price × netto_2 |
| `total_biaya_bongkar` | = spsi_amount |
| `total` | = subtotal - dp - spsi_amount - bp_colt - pph - uang_minum - potongan_lain |

## Contoh Perhitungan

### Input
```json
{
  "netto_1": 2807,
  "netto_2": 2807,
  "price": 4590,
  "bp_colt": 70000,
  "dp": 10000000,
  "factory_id": null,
  "spsi_calculation_mode": "PER_KG",
  "spsi_rate": 12,
  "biaya_bongkar": 12,
  "deductions": []
}
```

### Kalkulasi
```
subtotal = 4590 × 2807 = 12.884.130
pph = floor(0.0025 × 4590 × 2807) = floor(32.210,325) = 32.210
uang_minum = 10000 (netto_2 <= 7000)
total_biaya_bongkar = 12 × 2807 = 33.684
potongan_lain = 0
total = 12.884.130 - 10.000.000 - 33.684 - 70.000 - 32.210 - 10.000 - 0 = 2.738.236
```

### Output WA
```
Total bon: Rp 12.738.236    ← total + dp (sebelum DP)
TOTAL NOTA: Rp 12.738.236
DP / Panjar: Rp 10.000.000
Total Akhir: Rp 2.738.236  ← total (sesudah DP)
```

## Catatan Penting

1. **DP tidak dikurangkan dari `bon.total` untuk tampilan** — nilai `bon.total` di database sudah termasuk DP, tapi di tampilan WA/PDF, `Total bon` dan `TOTAL NOTA` menampilkan nilai SEBELUM DP (`bon.total + bon.dp`), lalu DP ditampilkan terpisah, dan `Total Akhir` adalah sesudah DP (`bon.total`).
2. **Semua nilai dalam Rupiah adalah integer** (tanpa desimal).
3. **Deductions** adalah array of objects dengan `label` (string) dan `amount` (integer). Digunakan untuk potongan dinamis selain yang sudah terdefinisi.
