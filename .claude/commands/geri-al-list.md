---
allowed-tools: Bash(powershell:*)
description: Geri alma icin commit listesi
---

# Git Commit Listesi

**SCRIPT ÇIKTISINI TAMAMEN AYNEN GÖSTER - YORUMLAMA YAPMA!**

!`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".claude\system\show-commits.ps1" list`

**ÖNEMLİ TALIMAT:**
- Yukarıdaki script çıktısının TAMAMINI olduğu gibi göster
- Özet yapma, yorumlama veya kısaltma
- Her satırı aynen kopyala
- Format: [Numara] Tarih - Hash - Mesaj <- Durum

Örnek beklenen format:
```
[32] 17.09.2025 14:48 - a3d8681 - Claude degisikligi - v250917144814 <- AKTIF (1 kez geri alinmis)
[31] 17.09.2025 14:49 - 0cbb39a - Claude degisikligi - v250917144913
[30] 17.09.2025 14:48 - 3d932a9 - Claude degisikligi - v250917144924
```
