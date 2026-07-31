[![npm version](https://img.shields.io/npm/v/crypt-sync.svg)](https://www.npmjs.com/package/crypt-sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[Hızlı Başlangıç](#hızlı-başlangıç) • [Özellikler](#özellikler) • [Kurulum](#kurulum) • [Claude Code Eklentisi](#claude-code-eklentisi) • [Kullanım](#kullanım) • [Nasıl Çalışır](#nasıl-çalışır) • [Sorun Giderme](#sorun-giderme)

# crypt-sync

`.env` ve gizli dosyaları age ile şifrele, git üzerinden makineler arasında senkronize et.

> 🇬🇧 For English see [README.md](README.md)

**crypt-sync, secretlarını git'te şifreli tutar.** Dosyaları `.gitignore`'layıp senkronu kaybetmek yerine, crypt-sync her dosyayı [age](https://github.com/FiloSottile/age) ile şifreler ve `.age` blob'unu repo'na commit'ler. Herhangi bir makinede `git pull` yap, passphrase ile çöz. Kopyalanacak anahtar dosyası yok. Çalıştırılacak secret manager yok.

---

## Hızlı Başlangıç

**İlk makine (yeni proje):**

```bash
npm install -g crypt-sync
crypt-sync init       # makine başına bir kez — passphrase gir
cd proje-dizini
crypt-sync setup      # interaktif: dosyaları gez → seç → şifrele → hook kur
git commit -m "add encrypted secrets"
git push
```

**Başka bir makine (mevcut proje):**

```bash
npm install -g crypt-sync
git clone <repo> && cd <repo>
crypt-sync init       # aynı passphrase → hook'lar kurulur + dosyalar otomatik çözülür
```

**`npm install -g crypt-sync` güncellemesi sonrası:**

```bash
# @latest kullan — npm update -g önbelleğe alınmış metadata kullanabilir
npm install -g crypt-sync@latest

cd proje-dizini
crypt-sync update-hooks   # .git/hooks/ dosyalarını yeni versiyona güncelle
```

---

## Özellikler

| Özellik | Açıklama |
|---|---|
| **age şifreleme** | X25519 + ChaCha20-Poly1305 — modern, denetimli, hızlı |
| **Passphrase'den türetilen anahtar** | Aynı passphrase → her makinede aynı anahtar. Anahtar dosyası kopyalanmaz |
| **Git-native senkron** | Şifreli blob'lar repo'nda yaşar. `git push` = senkron |
| **Otomatik hook'lar** | Push'ta şifreler, pull'da çözer (git hook'ları) |
| **Akıllı `init`** | Proje tespit edince hook'ları kurar ve dosyaları otomatik çözer |
| **İnteraktif setup** | Proje ağacını gez, dosya seç, alt dizinlere gir (`b` geri, `q` çık) |
| **Tam path artifact'ları** | `apps/web/.env` → `apps/web/.env.age` — plaintext olmadan fresh clone'da da çalışır |
| **`update-hooks`** | `npm install -g crypt-sync@latest` sonrası `.git/hooks/` dosyalarını günceller |

---

## Gereksinimler

- Node.js ≥ 16
- Git
- [age](https://github.com/FiloSottile/age) — `npm install` sırasında otomatik indirilir

Desteklenen platformlar: macOS (arm64, x64), Linux (x64, arm64), Windows (x64).

---

## Kurulum

```bash
npm install -g crypt-sync
```

Postinstall scripti, platformuna uygun `age` binary'sini indirir ve SHA256 checksum'ını resmi release ile doğrular.

**Güncellemek için:**

```bash
npm install -g crypt-sync@latest   # her zaman @latest kullan, npm update -g değil
```

### Kaldırma

```bash
# Global paketi kaldır
npm uninstall -g crypt-sync

# Identity dosyasını sil
rm -rf ~/.config/crypt-sync
```

---

## Claude Code Eklentisi

Aynı repo bir [Claude Code](https://claude.com/claude-code) eklentisi olarak da kurulabilir. Eklenti, Claude'a hangi durumda hangi crypt-sync komutunun gerektiğini ve daha önemlisi secretlarınla neyi asla yapmayacağını öğretir: `init`'i senin yerine çalıştırmaz (passphrase seninle terminalin arasında kalır), çözülmüş plaintext'i okuyup sana geri yazmaz, `--force` ve `--wipe`'ı sormadan kullanmaz.

```bash
# skill-hub marketplace üzerinden
claude plugin marketplace add sametbrr/skill-hub
claude plugin install crypt-sync@sametbrr/skill-hub

# ya da doğrudan bu repodan
claude plugin install github:sametbrr/crypt-sync
```

**Eklenti CLI'nin yerine geçmez — CLI'yi gerektirir.** Eklenti yalnızca bir skill; şifreleme, anahtar türetme ve paketle gelen `age` binary'si npm paketinde yaşar. İki şey CLI'nin `PATH`'te olmasına bağlı:

- git hook'ları CLI'yi `command -v crypt-sync` ile arıyor
- `age`, paketin postinstall scripti tarafından indiriliyor (`vendor/` git'te değil)

Bu yüzden npm paketini de kur:

```bash
npm install -g crypt-sync
crypt-sync init
```

Sadece eklentiyi kurarsan gürültülü bir hata almazsın — eklenti CLI'nin eksik olduğunu tespit eder ve başka bir şey yapmadan önce kurulumu teklif eder. Ayrıca projede `.cryptsync` olup CLI olmadığında oturum başında uyarır; çünkü o durumda git hook'ları **sessizce** atlanır: push'ta secretlar şifrelenmez, pull'da blob'lar çözülmez.

---

## Kullanım

```
crypt-sync <komut> [seçenekler]

  init                        Passphrase'den şifreleme identity'si türet (makine başına bir kez)
  setup                       İnteraktif setup: dosyaları gez, şifrele, hook kur
  lock [--all] [--wipe]       Değişen entry'leri şifrele ve blob'ları git-add yap
  unlock [--force]            Tüm blob'ları plaintext'e çöz
  status                      Tüm entry'lerin şifreleme durumunu göster
  clean                       Manifest'te olmayan orphan .age blob'larını temizle
  update-hooks                Git hook'larını mevcut versiyona güncelle (npm update sonrası çalıştır)
  export-key <yol>            Identity anahtarını dosyaya aktar
  import-key <yol>            Identity anahtarını dosyadan içe aktar
```

### `init`

Makine başına bir kez çalıştırılır. scrypt kullanarak passphrase'den deterministik bir age identity türetir. Aynı passphrase her zaman aynı anahtarı üretir — makineler arasında anahtar dosyası transferi gerekmez.

```bash
crypt-sync init
# Passphrase (min 8 karakter): ••••••••••
# Identity kaydedildi: ~/.config/crypt-sync/identity.txt
# Recipient: age1...
```

**Bir proje içinde çalıştırılırsa** (`.cryptsync` dosyası bulunursa), `init` git hook'larını otomatik kurar ve `unlock` çalıştırır. Yani yeni bir makinede tek komut yeterlidir:

```bash
git clone <repo> && cd <repo>
crypt-sync init   # passphrase → hook'lar kurulur → dosyalar çözülür
```

Mevcut identity'nin üzerine yazmak için `--force` kullanılır.

### `setup`

İnteraktif proje kurulumu. Proje ağacını tarar, alt dizinlere girmeye izin verir ve `.cryptsync` manifest dosyasını tam relative path'lerle yazar.

```bash
cd proje-dizini
crypt-sync setup
```

```
Dizin: /
──────────────────────────────────────────
     1.  .mcp.json  ← secret?
     d1.  apps/

> d1          ← apps/ dizinine gir
> d1          ← apps/bot/ dizinine gir
> 1           ← apps/bot/.env seç (tam path eklenir)
> b           ← bir üst dizine çık
> q           ← iptal et ve çık
> [Enter]     ← bitir → şifreler + hook kurar
```

Navigasyon tuşları:

| Tuş | Eylem |
|---|---|
| `<numara>` | Dosya seç / kaldır (tam relative path olarak eklenir) |
| `d<numara>` | Alt dizine gir |
| `b` veya `..` | Bir üst dizine çık |
| `q` | Setup'ı iptal et ve çık |
| Enter | Seçimi bitir → şifrele + hook kur |

**`.cryptsync` zaten mevcutsa** (örn. crypt-sync kullanan bir repo clone'ladıysan), `setup` dosya seçim wizard'ını atlar, hook'ları kurar ve `unlock` çalıştırır. Wizard'ı yeniden çalıştırmak için `--force` kullan.

### `lock`

Son lock'tan bu yana içeriği değişen entry'leri şifreler. Değişmeyen entry'ler atlanır. Blob'ları ve metadata dosyalarını otomatik olarak `git add` yapar.

```bash
crypt-sync lock           # değişen entry'leri şifrele
crypt-sync lock --all     # ledger'a bakmaksızın tüm entry'leri yeniden şifrele
crypt-sync lock --wipe    # şifreledikten sonra plaintext'i de sil
crypt-sync lock --no-add  # git add'i atla (hook'lar tarafından dahili olarak kullanılır)
```

### `unlock`

Manifest'teki tüm `.age` blob'larını plaintext'e çözer. Plaintext dosya mevcut olmasa bile oluşturur (fresh clone'da güvenli). Yerel olarak değiştirilmiş dosyaların üzerine `--force` olmadan yazmaz.

```bash
crypt-sync unlock
crypt-sync unlock --force   # yerel plaintext'in üzerine şifresi çözülmüş versiyonu yaz
```

Çıktı mesajları:

```
  unlocking apps/bot/.env... done          # blob bulundu → çözüldü
  not locked: apps/bot/.env               # plaintext var ama blob yok → çalıştır: crypt-sync lock
  missing: apps/bot/.env.age              # ne blob ne plaintext var → kaynak makinede lock + push yap
```

### `status`

Entry başına durumu gösterir ve orphan blob'lar hakkında uyarır.

```bash
crypt-sync status
# .mcp.json             locked   (unchanged)
# apps/web/.env         locked   (changed — run lock)
# apps/api/.env         missing blob — run lock
```

### `update-hooks`

`.git/hooks/` dizinindeki git hook'larını mevcut crypt-sync versiyonuyla eşleşecek şekilde günceller. Hem yeni (`# crypt-sync hook`) hem eski (`# env-crypt hook`) sentinel formatlarını tanır. crypt-sync güncelledikten sonra çalıştır.

```bash
crypt-sync update-hooks
#   hook pre-commit: updated
#   hook pre-push: updated
#   hook post-merge: updated
#   hook post-checkout: updated
```

### `export-key` / `import-key`

Identity'yi passphrase'den yeniden türetmeden başka bir makineye taşır.

```bash
crypt-sync export-key ~/key-backup.txt   # bu dosyayı güvende tut
crypt-sync import-key ~/key-backup.txt
```

---

## Yapılandırma

Proje kökünde bir `.cryptsync` dosyası oluştur. `#` ile başlayan satırlar yorum satırıdır. Bu dosyayı commit'le — tüm makinelerin neyin yönetildiğinde hemfikir olması gerekir.

```
# crypt-sync manifest
apps/bot/.env
apps/bot/.env.development
apps/dashboard-api/.env
apps/dashboard-api/.env.development
.mcp.json
secrets/              # dizinin tamamını tek archive olarak şifrele
*.pem                 # glob deseni
```

**Desen kuralları:**

| Desen | Davranış |
|---|---|
| `apps/bot/.env` (slash var) | Proje köküne göre tam path — önerilen yöntem |
| `.env` (slash yok) | Basename eşleşmesi — ağaçtaki her `.env`'i şifreler |
| `secrets/` (sonda slash) | Dizin — tek bir `.cryptsync.tar.age` archive'ı üretir |
| `*.pem` | Glob — yalnızca proje kökündeki dosyaları eşleştirir |
| `**/*.pem` | Özyinelemeli glob |

> **İpucu:** Basename pattern (`.env`) yerine tam relative path (`apps/bot/.env`) kullan. Basename pattern'lar çözümleme için plaintext dosyanın disk'te mevcut olmasına bağımlıdır; bu durum ilk `unlock` öncesi fresh clone'larda bozulur.

---

## Nasıl Çalışır

```
passphrase
    │  scrypt(N=65536, r=8, p=1)
    ▼
32-byte key → X25519 clamp → Bech32 → AGE-SECRET-KEY-1…
    │
    ├── age encrypt -r <recipient>  →  apps/bot/.env.age   (git'e commit'lenir)
    │
    └── age decrypt -i identity.txt ← apps/bot/.env.age   (pull sonrası)
```

1. **`init`** — scrypt kullanarak passphrase'den deterministik bir age identity türetir. `~/.config/crypt-sync/identity.txt` dosyasına kaydedilir (mod 0600, dizin modu 0700). `.cryptsync` projesi tespit edilirse hook'ları kurar ve `unlock` çalıştırır.
2. **`setup`** — proje ağacını tarar, interaktif browser ile tam path'lerle dosya seçimi yapar, `.cryptsync`'i yazar, hook'ları kurar, ilk `lock`'u çalıştırır. `.cryptsync` zaten varsa wizard'ı atlar, hook kur + `unlock` yapar.
3. **`lock`** — her değişen entry için: SHA256 hesaplar, ledger (`.cryptsync.state`) ile karşılaştırır, `age -r <recipient>` ile şifreler, blob'ları `git add` yapar.
4. **`unlock`** — her `.age` blob'unu geçici dosya + yeniden adlandırma yöntemiyle atomik olarak çözer. Gerekirse parent dizinleri oluşturur. Bir sonraki `lock`'ın no-op olması için ledger'ı günceller.
5. **Hook'lar** — `pre-push` `lock --no-add` çalıştırır; `post-merge` / `post-checkout` `unlock` çalıştırır. `pre-commit` yönetilen bir plaintext dosyası stage'lenmişse commit'i durdurur.
6. **Ledger** — `.cryptsync.state` (gitignore'lı) her plaintext entry'nin SHA256 hash'ini takip eder. Değişmeyen dosyalar hiçbir zaman yeniden şifrelenmez; bu sayede gereksiz git diff'leri önlenir.

---

## Sorun Giderme

**`age binary not found`** — Postinstall scripti sessizce başarısız oldu. Yeniden çalıştır:

```bash
npm rebuild crypt-sync
```

Ya da age'i [github.com/FiloSottile/age/releases](https://github.com/FiloSottile/age/releases) adresinden manuel olarak kur ve `PATH`'inde olduğundan emin ol.

**`Error: identity not found`** — Önce bu makinede `crypt-sync init` komutunu çalıştır.

**`unlock` `missing: .env.age` diyorsa** — Blob git'e hiç commit'lenmemiş. Kaynak makinede:

```bash
crypt-sync lock
git add apps/bot/.env.age
git push
```

**`unlock` `not locked: .env` diyorsa** — Plaintext dosyası yerel olarak mevcut ama hiç şifrelenmemiş. Çalıştır:

```bash
crypt-sync lock
```

**`git pull` sonrası dosyalar çözülmüyorsa** — Git hook'ları kurulmamış veya güncel değil. Çalıştır:

```bash
crypt-sync update-hooks
```

**`npm install -g crypt-sync@latest` sonrası hook'lar eski davranışı sürdürüyorsa** — `npm install` paketi günceller ama `.git/hooks/` içindeki hook dosyalarına dokunmaz. Her projede `crypt-sync update-hooks` çalıştır.

**`unlock` yanlış plaintext üretiyor / şifre çözme başarısız** — `crypt-sync status` recipient fingerprint'ini yazdırır. `lock` çalıştıran makinedeki fingerprint ile karşılaştır. Farklılarsa passphrase'ler farklıdır.

**`pre-commit` "Plaintext secret file staged" mesajıyla durdu** — Yönetilen bir plaintext dosyası yanlışlıkla stage'lendi:

```bash
git reset HEAD .env     # stage'den çıkar
crypt-sync lock          # önce şifrele
git add .env.age        # blob'u stage'e ekle
git commit
```

**`unlock` yerel dosyamın üzerine yazmayı reddediyor** — `unlock`, varsayılan olarak yerel olarak farklılaşmış dosyaları atlar. Yalnızca yerel değişikliklerini kasıtlı olarak değiştirmek istediğinde `--force` kullan:

```bash
crypt-sync unlock --force
```

---

## Lisans

MIT — bkz. [LICENSE](LICENSE).

---

<p align="center">
  <a href="https://github.com/sametbrr/crypt-sync/issues">Hata Bildir</a> ·
  <a href="https://github.com/sametbrr/crypt-sync/issues">Özellik İste</a>
</p>
