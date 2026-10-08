# Campus Street View

The frontend uses the production Railway backend by default:
`https://vazhikaatti-production.up.railway.app`.

Run the app:

```powershell
flutter pub get
flutter run
```

To use a different backend, provide its base URL at build/run time:

```powershell
flutter run --dart-define=API_BASE_URL=https://your-service.up.railway.app
```

For local development, start the backend and use
`http://10.0.2.2:8080` on an Android emulator or `http://localhost:8080` on
desktop/web.
