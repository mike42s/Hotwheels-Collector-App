# Hot Wheels Collection Manager

Full-stack application for managing a Hot Wheels collection with:
- Flutter offline-first frontend using SQLite, image capture/compression, Excel export/import, and sync.
- Node.js backend using Express, SQL Server, JWT authentication, and UPSERT sync logic.

## Repository Structure

- `backend/`
  - `server.js` - Express server with `/register`, `/login`, `/api/sync`, and `/health`.
  - `package.json` - backend dependencies and startup script.
  - `.env.example` - template for SQL Server and JWT configuration.
  - `hotwheels_collection.postman_collection.json` - Postman collection for API requests.

- `frontend/hotwheels/`
  - `lib/` - Flutter app source files.
  - `pubspec.yaml` - Flutter dependencies.
  - `test/` - widget tests for Riverpod app startup.

## Backend Setup

1. Install dependencies:
   ```powershell
   cd backend
   npm install
   ```

2. Configure environment variables in `backend/.env` or create from `backend/.env.example`:
   ```text
   DB_USER=sa
   DB_PASSWORD=PasswordSQLAnda123
   DB_SERVER=localhost
   DB_PORT=1433
   DB_NAME=db_hotwheels
   JWT_SECRET=your_jwt_secret_here
   PORT=3000
   ```

3. Start the backend server:
   ```powershell
   npm start
   ```

4. Notes:
   - The backend uses `express.json({ limit: '50mb' })` to support Base64 image payloads.
   - `/api/sync` is protected by JWT middleware and stores `user_id` from the token.
   - The server will automatically create `dbo.users` and `dbo.hotwheels_collection` if they do not exist.
   - If login fails, verify SQL Server credentials and SQL Server authentication mode.

## Frontend Setup

1. Open the Flutter project:
   ```powershell
   cd frontend/hotwheels
   flutter pub get
   ```

2. Validate the Flutter app:
   ```powershell
   flutter analyze
   flutter test
   ```

3. Run the app:
   ```powershell
   flutter run
   ```

4. App features:
   - Offline-first storage in SQLite (`collection` table).
   - Image capture uses `image_picker` and compresses images to JPEG with `image`.
   - Photos are stored as Base64 strings in SQLite and exported/imported in Excel.
   - Sync sends unsynced rows (`is_synced = 0`) to the backend.
   - Clear local data deletes only local SQLite records.

## Postman API Testing

1. Import `backend/hotwheels_collection.postman_collection.json` into Postman.
2. Set the `baseUrl` environment variable to your backend URL, e.g. `http://localhost:3000`.
3. Use the following sequence:
   - `Register User` to create a new user.
   - `Login User` to receive a JWT token.
   - `Sync Collections` to send JSON data to `/api/sync`.

4. The collection includes token support:
   - `Login User` saves the returned token to the environment variable `token`.
   - `Sync Collections` uses `Authorization: Bearer {{token}}`.

## Important Notes

- Make sure SQL Server is reachable and the credentials in `backend/.env` are correct.
- The app uses Riverpod state management in Flutter.
- Local SQLite records are marked with `is_synced = 0` until they are successfully synced.
- The backend does not accept raw binary images; only Base64 JPEG strings are handled.

## Troubleshooting

- If the backend fails with `Login failed for user 'sa'`, update `.env` with valid SQL Server credentials or enable SQL Server authentication.
- If Postman does not set the token, copy the value from the login response and set the `token` environment variable manually.
- If Flutter fails to launch, ensure the correct Flutter SDK is installed and the `frontend/hotwheels` project is opened.
