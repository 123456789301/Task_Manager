# TaskFlow (Manager & Employee)

Cross-platform task management with two roles (Manager/Employee), real-time updates (Firebase Firestore), daily SMS reminders (Twilio), and deployable as a Flutter PWA for the web + Android/iOS. Backend runs on Node.js (Express) on Render/Railway/Vercel.

## Features
- Authentication (Firebase Auth: email/password) + role stored in Firestore (`users/{{uid}}.role`).
- Manager Dashboard: employees list, assign tasks, see status, daily work reports.
- Employee Dashboard: view assigned tasks, submit updates, mark complete.
- Real-time updates: Firestore listeners update instantly.
- Reminders: Node cron job uses Twilio to SMS employees who haven’t updated today.
- Task history for both roles.
- PWA: `web/manifest.json`, service worker, icons; build with `flutter build web`.

## Quick Start

### 1) Firebase Setup
1. Create a Firebase project → enable **Authentication (Email/Password)** and **Firestore** (in *Production* mode).
2. Add a **Web app** to get Firebase config and paste in `mobile/lib/services/firebase_service.dart` (`webOptions`).
3. For Android/iOS, follow FlutterFire setup and place `google-services.json` / `GoogleService-Info.plist`. (For web/PWA only, the `webOptions` is enough.)
4. In **Firestore**, create rules from `mobile/firestore.rules`.
5. Create a **Service Account** key (JSON) for Firebase Admin; provide it via env var `FIREBASE_SERVICE_ACCOUNT` (stringified JSON) or the host's secret file.

### 2) Twilio Setup
- Add env vars to backend:
```
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1XXXXXXXXXX
FIREBASE_PROJECT_ID=your-firebase-project-id
CRON_TZ=Asia/Kolkata
DAILY_SMS_HOUR=18
PORT=8080
```
- On Render/Railway/Vercel add the same env vars in dashboard.

### 3) Backend (local)
```
cd backend
cp .env.example .env   # fill values
npm i
node server.js
```
Your API will be at `http://localhost:8080` (change in `mobile/lib/services/api_service.dart` if you deploy).

### 4) Flutter App (local & web/PWA)
```
cd mobile
flutter pub get
flutter run       # Android/iOS/Web dev
flutter build web # Builds PWA into build/web
```
Deploy `mobile/build/web` to any static host (Netlify, Vercel static, Cloudflare Pages, S3, etc.).

### 5) Backend Deploy (Render/Railway/Vercel)
- **Render/Railway**: Node service → Build `npm i`, Start `node server.js`.
- **Vercel**: use `backend/vercel.json` (serverless).

## Firestore Data Model
- `users/{{uid}}`: `email`, `role` ('manager'|'employee'), `name`, `phone`.
- `tasks/{{taskId}}`:
  - `title`, `description`, `assignedTo` (uid), `assignedBy` (uid),
  - `status` ('pending'|'in_progress'|'done'),
  - `createdAt`, `updatedAt`, `dueDate` (optional),
  - `lastEmployeeUpdateAt` (timestamp).
- `tasks/{{taskId}}/updates/{{updateId}}`: `by` (uid), `message`, `createdAt`, `status` (optional).

## API
- `POST /api/users` (auth) → create/update your profile: `{ name, phone, role }`.
- `GET /api/users` (manager) → list employees.
- `POST /api/tasks` (manager) → create task: `{ title, description?, assignedTo, dueDate? }`.
- `GET /api/tasks` (auth) → list tasks (employees see their own).
- `PATCH /api/tasks/:id` (auth) → update fields (status/title/desc/dueDate).
- `POST /api/tasks/:id/updates` (auth) → add update `{ message, status? }`.
- `POST /api/sms/test` (auth) → send a test SMS `{ to, body }`.

## Notes
- Costs: Twilio SMS is paid. Keep an eye on usage.
- Free tiers have quotas (Firestore, hosting). Optimize queries and indexes if you scale.
