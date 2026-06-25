Place menu fixture images (`.jpg`, `.jpeg`, `.png`, or `.webp`) here.

The regression runner uses these files in filename order. If this directory has
no images, it falls back to `assets/images/tutorial_sample.jpg`.

Live calls are opt-in:

```text
LIVE_VISION_TEST=true
LIVE_VISION_ENDPOINT=https://.../analyzeVision
LIVE_VISION_AUTH_TOKEN=<Firebase ID token, when required>
```

No credentials are stored in this directory.
