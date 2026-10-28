# TradeVerse AI — Deployment & Cloud CI/CD Guide

## 1. Zero-Local-Flutter Paradigm

In accordance with strict environment constraints:
- **No local Flutter or Android SDK is needed on the developer workstation.**
- All dependency resolution, static analysis, unit tests, widget tests, and Android APK / AAB compilation occur in **GitHub Actions cloud runners**.

---

## 2. GitHub Actions Setup & APK Download

### GitHub Repository Secrets

Configure these secrets in your GitHub repository (`Settings -> Secrets and variables -> Actions`):

| Secret Name | Description | Required For |
|---|---|---|
| `API_BASE_URL` | Production/Staging URL of the deployed Node.js backend (e.g. `https://api.tradeverse.app/api/v1`) | Mobile App Network Config |
| `MONGODB_URI` | MongoDB Atlas connection string | Backend CI / Deployment |
| `JWT_SECRET` | Secret key for JWT signing | Backend Auth |
| `AI_PROVIDER_KEY` | Optional API key for external LLM (Gemini / OpenAI) | AI Assistant Service |

### Triggering the Android APK Build

1. Push your commits to the `main` branch:
   ```bash
   git push origin main
   ```
2. Navigate to your repository on GitHub and click the **Actions** tab.
3. Select the workflow **Flutter Android Build**.
4. You can also trigger it on-demand by clicking **Run workflow**.
5. Once the build finishes successfully (typically 3-5 minutes on the cloud runner):
   - Scroll down to the **Artifacts** section at the bottom of the workflow run summary.
   - Click **`tradeverse-mobile-debug-apk`** to download `app-debug.apk`.
   - Install the APK directly on any Android smartphone or tablet.

---

## 3. Node.js Backend Deployment (Render / Railway / VPS / Docker)

### MongoDB Atlas Setup

1. Create a free M0 cluster at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas).
2. Create a database user with read/write access.
3. Whitelist network IP (`0.0.0.0/0` for cloud deployment or specific static IPs).
4. Copy the connection URI:
   ```
   mongodb+srv://<username>:<password>@cluster0.tradeverse.mongodb.net/tradeverse?retryWrites=true&w=majority
   ```

### Deploying to Render / Railway / Fly.io

1. Connect the GitHub repository.
2. Set Root Directory to `apps/api`.
3. Set Build Command:
   ```bash
   npm install && npm run build
   ```
4. Set Start Command:
   ```bash
   npm start
   ```
5. Add Environment Variables:
   - `PORT`: `5000` (or platform default)
   - `NODE_ENV`: `production`
   - `MONGODB_URI`: `<your_atlas_connection_string>`
   - `JWT_SECRET`: `<secure_random_string_min_32_chars>`
   - `CORS_ORIGIN`: `*`
6. Verify deployment by visiting `https://<your-deployed-service>.com/health`.

---

## 4. Local Backend Testing

While Flutter is built on GitHub Actions, the Node.js backend can be tested locally using the installed Node.js v24:

```bash
cd apps/api
npm install
npm test
npm run dev
```
