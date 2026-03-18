# Testing Scripts — LKS 2026

## Alur Penggunaan

```
1. push-to-github.sh          ← Push kode ke GitHub (dari VSCode/terminal)
         │
         ▼
2. jury-deploy.sh             ← Juri deploy sendiri untuk verifikasi soal
         │
         ▼
3. jury-assess.sh             ← Juri nilai hasil deploy siswa
         │
         ▼
4. student-check.sh           ← Siswa self-check sebelum panggil juri
         │
         ▼
5. jury-teardown.sh           ← Juri bersihkan resource setelah selesai
```

---

## Scripts

| Script | Untuk | Fungsi |
|---|---|---|
| `../push-to-github.sh` | Semua | Push kode dari lokal ke GitHub |
| `jury-deploy.sh` | Juri | Deploy seluruh infrastruktur dari nol (proof of concept) |
| `jury-assess.sh <nama>` | Juri | Nilai hasil deploy siswa, skor 0–130 |
| `student-check.sh` | Siswa | Self-check sebelum panggil juri |
| `jury-teardown.sh` | Juri | Hapus semua resource AWS setelah testing |

---

## Setup awal (dari VSCode, jalankan sekali)

```bash
chmod +x push-to-github.sh testing/*.sh
./push-to-github.sh
```

---

## Skor penilaian juri

| Section | Topik | Maks |
|---|---|---|
| A | Networking & VPC (+ Peering routes) | 30 |
| B | Security Groups (incl. TCP 9100) | 10 |
| C | Database (RDS, DynamoDB, SSM) | 10 |
| D | ECR Repositories | 5 |
| E | ECS Application Services | 20 |
| F | ALB & Full CRUD | 20 |
| G | Prometheus + Inter-Region Peering | 25 |
| H | CI/CD Pipeline | 10 |
| **Total** | | **130** |
