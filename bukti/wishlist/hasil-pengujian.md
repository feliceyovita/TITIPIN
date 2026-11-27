# Hasil pengujian wishlist Titipin

27 November 2026 · Firebase Authentication Emulator dan Cloud Firestore Emulator, database default.

## Integrasi backend

Perintah `node --test test/wishlist_firestore.test.mjs` lulus (1 skenario, 0 gagal). Dua akun uji memiliki email USU terverifikasi pada Auth Emulator. Operasi wishlist menggunakan token masing-masing akun. Data barang uji disiapkan secara lokal.

| Pemeriksaan | Hasil |
|---|---|
| Akun A menyimpan barang yang sama dua kali | Satu dokumen tersimpan |
| Akun B menyimpan barang yang sama | Tersimpan di jalur UID B |
| B membaca dan menghapus favorit A | Kedua operasi ditolak dengan HTTP 403 |
| Barang ditandai terjual lalu dihapus | Ringkasan tersimpan tetap dapat dibaca |
| A menghapus favorit setelah barang hilang | Dokumen A hilang, dokumen B tetap ada dengan data yang sesuai |

Dokumen bukti pada emulator: `users/uGVx7tbixbfnoao5IVBfVB7NImeG/wishlist/buku-1795720792391`.

Pengujian ulang dengan Firebase Emulator Suite juga lulus (1 skenario, 0 gagal).

## Pengujian antarmuka Android

Build pertama berhenti ketika Gradle daemon keluar saat `assembleDebug`. Pada percobaan lanjutan, ADB belum mendeteksi Pixel 10 sebagai perangkat siap uji. Alur antarmuka, video simpan dan hapus, serta tangkapan layar Firestore masih menunggu verifikasi.
