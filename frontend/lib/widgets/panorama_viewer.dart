import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PanoramaViewer extends StatefulWidget {
  const PanoramaViewer({
    required this.imageUrl,
    required this.heading,
    this.yawOverride,
    super.key,
  });

  final String imageUrl;
  final double heading;
  final double? yawOverride;

  @override
  State<PanoramaViewer> createState() => PanoramaViewerState();
}

class PanoramaViewerState extends State<PanoramaViewer> {
  static const _initialFieldOfView = 60.0;
  ui.Image? _image;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double _yaw = 0;
  double _pitch = 0;
  double _fieldOfView = _initialFieldOfView;
  double _fieldOfViewAtGestureStart = _initialFieldOfView;

  double get cameraYawDegrees => _yaw * 180 / math.pi;

  void setCameraYawDegrees(double degrees) {
    if (!mounted) return;
    setState(() => _yaw = degrees * math.pi / 180);
  }

  @override
  void initState() {
    super.initState();
    _yaw = _headingInRadians;
    _loadImage();
  }

  double get _headingInRadians =>
      (widget.yawOverride ?? widget.heading) * math.pi / 180;

  @override
  void didUpdateWidget(covariant PanoramaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
      setState(() {
        _yaw = _headingInRadians;
        _pitch = 0;
        _fieldOfView = _initialFieldOfView;
        _fieldOfViewAtGestureStart = _initialFieldOfView;
      });
    } else if (oldWidget.heading != widget.heading ||
        oldWidget.yawOverride != widget.yawOverride) {
      setState(() {
        _yaw = _headingInRadians;
        _pitch = 0;
      });
    }
  }

  void _loadImage() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _image = null;
    final stream = ResizeImage(
      NetworkImage(widget.imageUrl),
      width: 4096,
    ).resolve(const ImageConfiguration());
    _imageStream = stream;
    _imageListener = ImageStreamListener(
      (frame, synchronousCall) {
        if (mounted) setState(() => _image = frame.image);
      },
      onError: (Object error, StackTrace? stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'campus panorama viewer',
            context: ErrorDescription('while loading ${widget.imageUrl}'),
          ),
        );
        if (mounted) setState(() => _image = null);
      },
    );
    stream.addListener(_imageListener!);
  }

  void zoomBy(double amount) {
    setState(() {
      _fieldOfView = (_fieldOfView + amount).clamp(35.0, 110.0);
    });
  }

  void resetView() {
    setState(() {
      _yaw = _headingInRadians;
      _pitch = 0;
      _fieldOfView = _initialFieldOfView;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _fieldOfViewAtGestureStart = _fieldOfView;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.pointerCount > 1) {
        _fieldOfView = (_fieldOfViewAtGestureStart / details.scale).clamp(
          35.0,
          110.0,
        );
      }
      _yaw -= details.focalPointDelta.dx * 0.006;
      _pitch = (_pitch - details.focalPointDelta.dy * 0.006).clamp(
        -math.pi / 2,
        math.pi / 2,
      );
    });
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PanoramaPainter(
            image: _image,
            yaw: _yaw,
            pitch: _pitch,
            fieldOfView: _fieldOfView,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PanoramaPainter extends CustomPainter {
  const _PanoramaPainter({
    required this.image,
    required this.yaw,
    required this.pitch,
    required this.fieldOfView,
  });

  final ui.Image? image;
  final double yaw;
  final double pitch;
  final double fieldOfView;

  static const _columns = 48;
  static const _rows = 28;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xffb4d5e3),
    );
    final panorama = image;
    if (panorama == null || size.isEmpty) return;

    final focalLength =
        size.width / (2 * math.tan(fieldOfView * math.pi / 360));
    final cosineYaw = math.cos(yaw);
    final sineYaw = math.sin(yaw);
    final cosinePitch = math.cos(pitch);
    final sinePitch = math.sin(pitch);
    final uvs = List<List<Offset>>.generate(
      _rows + 1,
      (row) => List<Offset>.generate(_columns + 1, (column) {
        final screenX = column / _columns * size.width - size.width / 2;
        final screenY = row / _rows * size.height - size.height / 2;
        final localX = screenX / focalLength;
        final localY = 1.0;
        final localZ = -screenY / focalLength;
        final pitchedY = localY * cosinePitch - localZ * sinePitch;
        final worldX = localX * cosineYaw + pitchedY * sineYaw;
        final worldY = -localX * sineYaw + pitchedY * cosineYaw;
        final worldZ = localY * sinePitch + localZ * cosinePitch;
        final longitude = math.atan2(worldX, worldY);
        final latitude = math.asin(
          (worldZ /
                  math.sqrt(
                    worldX * worldX + worldY * worldY + worldZ * worldZ,
                  ))
              .clamp(-1.0, 1.0),
        );
        final u = (0.5 + longitude / (2 * math.pi)) * panorama.width;
        final v = (0.5 - latitude / math.pi) * panorama.height;
        return Offset(u, v);
      }),
    );

    final positions = <double>[];
    final textureCoordinates = <double>[];
    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        final left = column / _columns * size.width;
        final right = (column + 1) / _columns * size.width;
        final top = row / _rows * size.height;
        final bottom = (row + 1) / _rows * size.height;
        _addTriangle(
          positions,
          textureCoordinates,
          [Offset(left, top), Offset(right, top), Offset(left, bottom)],
          [uvs[row][column], uvs[row][column + 1], uvs[row + 1][column]],
          panorama.width.toDouble(),
        );
        _addTriangle(
          positions,
          textureCoordinates,
          [Offset(right, top), Offset(right, bottom), Offset(left, bottom)],
          [
            uvs[row][column + 1],
            uvs[row + 1][column + 1],
            uvs[row + 1][column],
          ],
          panorama.width.toDouble(),
        );
      }
    }

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.fromList(positions),
      textureCoordinates: Float32List.fromList(textureCoordinates),
    );
    final shader = ui.ImageShader(
      panorama,
      ui.TileMode.repeated,
      ui.TileMode.clamp,
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );
    canvas.drawVertices(vertices, BlendMode.src, Paint()..shader = shader);
    vertices.dispose();
  }

  void _addTriangle(
    List<double> positions,
    List<double> textureCoordinates,
    List<Offset> points,
    List<Offset> uv,
    double imageWidth,
  ) {
    final horizontal = uv.map((point) => point.dx / imageWidth).toList();
    final minimum = horizontal.reduce(math.min);
    final maximum = horizontal.reduce(math.max);
    if (maximum - minimum > 0.5) {
      for (var index = 0; index < horizontal.length; index++) {
        if (horizontal[index] < 0.5) horizontal[index] += 1;
      }
    }

    for (var index = 0; index < points.length; index++) {
      positions
        ..add(points[index].dx)
        ..add(points[index].dy);
      textureCoordinates
        ..add(horizontal[index] * imageWidth)
        ..add(uv[index].dy);
    }
  }

  @override
  bool shouldRepaint(covariant _PanoramaPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.fieldOfView != fieldOfView;
  }
}
