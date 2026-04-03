# sign_speaks

SignSpeaks Flutter app with live sign-language detection.

## Live Detection on Chrome/Web

For web targets, Flutter cannot start local Python processes directly from the browser.
So the app uses a local Python API (`web_api.py`) and sends camera frames to it.

### 1) Start Python backend

From this folder (`sign_speaks`):

```bash
pip install -r requirements-web.txt
python web_api.py
```

Backend starts at `http://127.0.0.1:8000`.

### 2) Start Flutter web app

In another terminal:

```bash
flutter pub get
flutter run -d chrome
```

Open **Live Detection** and tap **Start Detection**.

## Optional: custom API URL

If backend is not on the default URL, pass compile-time define:

```bash
flutter run -d chrome --dart-define=SIGN_SPEAKS_API_URL=http://127.0.0.1:8000/predict
```
