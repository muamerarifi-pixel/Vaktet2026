# Publishing Vaktet on Google Play Store

Everything in this repository is pre-configured to produce a Play Store–ready `.aab` (Android App Bundle). Follow these 3 steps to publish:

## 1. Generate Your Upload Keystore (Run Once Locally)
```bash
keytool -genkey -v -keystore vaktet-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vaktet
```
> Keep `vaktet-upload.jks` backed up safely in a password manager or cloud vault. **Never commit it to Git.**

## 2. Add the 4 Signing Secrets to GitHub
Convert your keystore to Base64 (PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("vaktet-upload.jks")) | Set-Clipboard
```
Then go to **GitHub → Settings → Secrets and variables → Actions → New repository secret** and add:
- `KEYSTORE_BASE64`: the Base64 string copied above
- `KEYSTORE_PASSWORD`: your keystore password
- `KEY_ALIAS`: `vaktet`
- `KEY_PASSWORD`: your key password

On the next push or tag, GitHub Actions automatically builds a signed **`vaktet-playstore.aab`** artifact (`vaktet-playstore-aab`).

## 3. Upload to Google Play Console
1. Download `vaktet-playstore.aab` from the GitHub Actions run artifacts.
2. Upload your Store Listing assets:
   - **App icon (512 × 512):** `icons/icon-512.png`
   - **Feature graphic (1024 × 500):** `playstore/feature-graphic-1024x500.png`
   - **Privacy Policy URL:** host `privacy.html` (already deployed if using GitHub Pages / Vercel / Cloudflare at `/privacy.html`)
3. Complete **Data Safety** (no data collected or shared), **Content Rating**, and submit to **Closed Testing** (12 testers for 14 days for new personal accounts) or **Production**.
