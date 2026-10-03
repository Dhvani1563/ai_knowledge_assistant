# Archive — Flutter app

White base, light-purple accent. Requires **Flutter 3.27+**.

```bash
flutter create .        # once, generates android/ ios/ (keeps lib/)
flutter pub get
flutter run -d <device>
```

Before running, set in `lib/core/constants/app_constants.dart`:
- `apiBaseUrl` → `http://<your-laptop-LAN-IP>:8000/api/v1` for a physical device
- `googleWebClientId` → your Google *Web* client ID (see ../AUTH_SETUP.md)

Design tokens live in `lib/core/theme/` (colors, type, ThemeData).
