# Indoor Campus Street View Prototype

This prototype keeps its Flutter client and Dart REST API in separate
`frontend/` and `backend/` projects. Panorama positions are derived exclusively
from image names in the form `x_y_z.jpg`; the JSON catalog contains only IDs,
image names, and headings.

## Run locally

1. Start the API:

   ```powershell
   cd backend
   dart pub get
   dart run bin/server.dart
   ```

   The API listens on `http://localhost:8080`. It exposes `GET /api/health`,
   `GET /api/panoramas`, `GET /api/panoramas/:id`, and serves panorama files
   from `/images/:filename`.

2. Start the Flutter app in another terminal:

   ```powershell
   cd frontend
   flutter pub get
   flutter run
   ```

   For an Android emulator, use
   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`. Other devices
   should use the API host address reachable from that device.

Add panoramas as `.jpg` files to `backend/images/`, named by their integer
coordinates, such as `-1_2_0.jpg`. The API scans this folder on each request;
new files appear automatically. Add matching entries to
`backend/data/panoramas.json` only when an explicit ID or non-zero heading is
needed. Coordinates are always parsed from the filename.

The app first displays a floor map generated from the discovered panorama
coordinates. Select a node and press **Start Street View** to open its
panorama. The graph connects only panoramas exactly one X or Y coordinate
step apart at the same Z level; missing points, diagonal positions, and longer
distances do not create connections. The same graph drives the map edges, the
minimap, and the four-direction navigation control.

In the viewer, each enabled arrow moves exactly one graph edge and loads that
node's panorama. Disabled arrows indicate that no connected panorama exists
in that direction. Drag to look around, pinch to zoom on touch devices, or use
the on-screen zoom controls.
