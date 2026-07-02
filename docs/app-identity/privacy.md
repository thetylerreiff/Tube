# Tube Privacy Note

Tube is a native wrapper around the real YouTube website.

- Tube does not collect credentials.
- Tube does not inject scripts into YouTube.
- Tube does not modify YouTube pages or playback behavior.
- Tube does not add analytics or usage tracking.
- Google and YouTube sign-in happen inside WebKit.
- Website cookies, local storage, and account state are stored by WebKit's default website data store.
- `File > Reset YouTube Session` clears Tube's WebKit website data for a fresh sign-in state.

Current app entitlements are limited to App Sandbox and outgoing network access.
