# Catatan Request API OCR via Mistral AI

Dokumentasi referensi: `api/mistralai_openapi.yaml`

## Endpoint

```
POST /v1/ocr
```

Referensi spec: `/v1/ocr` (`api/mistralai_openapi.yaml:2769`), schema `OCRRequest` (`api/mistralai_openapi.yaml:17403`).

## Parameter Penting (`OCRRequest`)

| Field | Tipe | Deskripsi |
| --- | --- | --- |
| `model` | string | Model OCR, mis. `mistral-ocr-latest`. |
| `document` | object | Sumber dokumen. Salah satu dari `ImageURLChunk`, `DocumentURLChunk`, atau `FileChunk`. |
| `document_annotation_prompt` | string | Prompt untuk memandu ekstraksi structured output dari seluruh dokumen. Wajib jika `document_annotation_format` diisi. |
| `document_annotation_format` | object | `ResponseFormat` tipe `json_schema` (hanya `json_schema` yang valid). Menentukan struktur output. |
| `pages` | string/array | Halaman yang diproses (untuk PDF). Mulai dari 0. |
| `table_format` | string | `markdown` atau `html`. |

Tipe `document`:

- `ImageURLChunk` — gambar via data URI base64 atau URL:
  `{"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}`
- `DocumentURLChunk` — PDF/URL dokumen (`api/mistralai_openapi.yaml:14566`):
  `{"type": "document_url", "document_url": "<url>", "document_name": "slip.pdf"}`
- `FileChunk` — file yang sudah diupload ke `/v1/files` (`api/mistralai_openapi.yaml:16807`):
  `{"type": "file", "file_id": "<uuid>"}`

## Response

- `OCRResponse.document_annotation` — hasil structured output sebagai **string JSON** (perlu `JSON.parse()` di sisi client).
- `OCRResponse.pages[].markdown` — teks hasil OCR per halaman.
- `OCRResponse.pages[].images` — daftar gambar yang diekstrak dari halaman.
- `OCRResponse.pages[].dimensions` — dimensi halaman.

## Request Body (Contoh: Slip Timbangan)

```json
{
  "model": "mistral-ocr-latest",
  "document": {
    "type": "image_url",
    "image_url": {
      "url": "data:image/jpeg;base64,<base64_gambar>"
    }
  },
  "document_annotation_prompt": "You are a document parsing assistant. Extract structured data from the OCR text using these rules:\n\n- factory_name: Text starting with 'PT.', uppercase, or text below \"SLIP TIMBANGAN\" or null.\n- ticket_number: Value from 'No. Tiket', or null.\n- bon_date: Date formatted as YYYY-MM-DD, or null.\n- plate_number: Value from 'No. Polisi' as uppercase alphanumeric only (no spaces/punctuation), or null.\n- relation_name: Part of 'Nama Relasi' BEFORE '/', or null.\n- produk: Part of 'Nama Relasi' AFTER '/', or value of \"Nama Barang\" or null.\n- driver_name: Value from 'Nama Supir', or null.\n- fruit_origin:\n  - Use the value from \"Asal Buah\" if present.\n  - Only if \"Asal Buah\" is missing, use \"Keterangan\".\nIf a line starts with \"Total\", extract all numeric values.\nExample:\nTotal 10,600 212 106 10,282\nnumbers = [10600,212,106,10282]\n- netto_1 = numbers[0] or numbers[1]+numbers[2]+numbers[3]\n- netto_2 = numbers[3] or numbers[0]-(numbers[2]+numbers[3])\nif netto_1 or netto_2 null, use Netto 1 OR Netto 2 text value\nif netto_1 null, use netto_2 number\n- super: true if \"Keterangan\" is 'SUPER'\n\nReturn JSON only. Format number fields as integers with no punctuation.",
  "document_annotation_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "slip_timbangan",
      "strict": true,
      "schema": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "factory_name": { "type": ["string", "null"] },
          "ticket_number": { "type": ["string", "null"] },
          "bon_date": { "type": ["string", "null"] },
          "plate_number": { "type": ["string", "null"] },
          "relation_name": { "type": ["string", "null"] },
          "produk": { "type": ["string", "null"] },
          "driver_name": { "type": ["string", "null"] },
          "fruit_origin": { "type": ["string", "null"] },
          "netto_1": { "type": ["integer", "null"] },
          "netto_2": { "type": ["integer", "null"] },
          "is_super": { "type": ["boolean", "null"] }
        },
        "required": [
          "factory_name", "ticket_number", "bon_date", "plate_number",
          "relation_name", "produk", "driver_name", "fruit_origin",
          "netto_1", "netto_2", "is_super"
        ]
      }
    }
  }
}
```

## Contoh Output yang Diinginkan

```json
{
  "factory_name": "PT. CIPTA CHEMICAL MEDAN OIL",
  "ticket_number": "TBS-07/27/136",
  "bon_date": "2026-07-27",
  "plate_number": "BK9814PJ",
  "relation_name": "ODIE ALDIANSAH HARWIN",
  "produk": "BRONDOLAN",
  "driver_name": "DEDEK",
  "fruit_origin": "BATANG SERANGAN",
  "netto_1": 1960,
  "netto_2": 1861,
  "is_super": true
}
```

## Catatan Tambahan

- `document_annotation_format` hanya menerima tipe `json_schema` (`api/mistralai_openapi.yaml:17450`).
- `document_annotation_prompt` hanya berlaku jika `document_annotation_format` disediakan.
- Untuk PDF, gunakan `document_url` dan set `pages` bila perlu membatasi halaman.
- `document_annotation` dikembalikan sebagai string JSON — gunakan `JSON.parse()` pada hasilnya.
