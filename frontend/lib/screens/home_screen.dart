import 'package:flutter/material.dart';

import '../models/panorama.dart';
import '../models/panorama_navigation.dart';
import '../services/api_service.dart';
import '../services/orientation_store.dart';
import '../widgets/coordinate_map.dart';
import '../widgets/navigation_controls.dart';
import '../widgets/panorama_viewer.dart';
import '../widgets/position_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _orientationStore = OrientationStore();
  final _viewerKey = GlobalKey<PanoramaViewerState>();
  List<Panorama>? _panoramas;
  PanoramaGraph? _graph;
  Panorama? _selectedPanorama;
  Panorama? _currentPanorama;
  Object? _error;
  bool _viewerOpen = false;
  bool _mapVisible = true;
  double? _arrivalYaw;
  bool _directionsMode = false;
  bool _selectingDestination = false;
  Panorama? _routeFrom;
  Panorama? _routeTo;

  @override
  void initState() {
    super.initState();
    _loadPanoramas();
  }

  Future<void> _loadPanoramas() async {
    setState(() {
      _error = null;
      _panoramas = null;
      _graph = null;
      _selectedPanorama = null;
      _currentPanorama = null;
      _viewerOpen = false;
      _directionsMode = false;
      _selectingDestination = false;
      _routeFrom = null;
      _routeTo = null;
    });

    try {
      final loadedPanoramas = await _api.getPanoramas();
      final panoramasById = await _orientationStore.loadInto(loadedPanoramas);
      final panoramas = panoramasById.values.toList(growable: false);
      if (panoramas.isEmpty) {
        throw const ApiException(
          'No panoramas found. Add an x_y_z.jpg image to backend/images.',
        );
      }
      if (!mounted) return;
      setState(() {
        _panoramas = panoramas;
        _graph = PanoramaGraph(panoramas);
        _selectedPanorama = panoramas.first;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _startStreetView() {
    final selected = _selectedPanorama;
    if (selected == null) return;
    setState(() {
      _currentPanorama = selected;
      _viewerOpen = true;
      _mapVisible = true;
      _arrivalYaw = null;
    });
  }

  void _startDirections(List<Panorama> route) {
    if (route.isEmpty) return;
    setState(() {
      _currentPanorama = route.first;
      _selectedPanorama = route.first;
      _viewerOpen = true;
      _mapVisible = true;
      _arrivalYaw = null;
    });
  }

  void _move(PanoramaDirection direction) {
    final current = _currentPanorama;
    final graph = _graph;
    if (current == null || graph == null) return;
    final target = graph.targetFrom(current, direction);
    if (target == null) return;
    final globalDirection = _globalDirection(direction);
    final targetYaw = target.orientation[globalDirection];
    setState(() {
      _currentPanorama = target;
      _arrivalYaw = targetYaw;
    });
  }

  String _globalDirection(PanoramaDirection direction) => switch (direction) {
    PanoramaDirection.right => '+X',
    PanoramaDirection.left => '-X',
    PanoramaDirection.forward => '+Y',
    PanoramaDirection.backward => '-Y',
  };

  Future<void> _assignOrientation(String direction) async {
    final current = _currentPanorama;
    final yaw = _viewerKey.currentState?.cameraYawDegrees;
    if (current == null || yaw == null) return;
    final updated = current.copyWithOrientation({
      ...current.orientation,
      direction: yaw,
    });
    await _orientationStore.save(updated);
    if (!mounted) return;
    setState(() => _replaceCurrentPanorama(updated));
  }

  void _replaceCurrentPanorama(Panorama updated) {
    _currentPanorama = updated;
    final panoramas = _panoramas;
    if (panoramas == null) return;
    _panoramas = [
      for (final panorama in panoramas)
        panorama.id == updated.id ? updated : panorama,
    ];
    _graph = PanoramaGraph(_panoramas!);
  }

  Future<void> _resetOrientation(String direction) async {
    final current = _currentPanorama;
    if (current == null || !current.orientation.containsKey(direction)) return;
    final updated = current.copyWithOrientation(
      {...current.orientation}..remove(direction),
    );
    await _orientationStore.save(updated);
    if (!mounted) return;
    setState(() => _replaceCurrentPanorama(updated));
  }

  Future<void> _resetAllOrientations() async {
    final current = _currentPanorama;
    if (current == null) return;
    final updated = current.copyWithOrientation({});
    await _orientationStore.clear(updated);
    if (!mounted) return;
    setState(() => _replaceCurrentPanorama(updated));
  }

  void _showOrientationAssignments() {
    final current = _currentPanorama;
    if (current == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Orientation assignments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final direction in _orientationDirections)
              ListTile(
                dense: true,
                title: Text(direction),
                trailing: current.orientation[direction] == null
                    ? const Text('✗ Not assigned')
                    : Text(
                        '${current.orientation[direction]!.toStringAsFixed(1)}°',
                      ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static const _orientationDirections = ['+X', '-X', '+Y', '-Y'];

  @override
  Widget build(BuildContext context) {
    final panoramas = _panoramas;
    final graph = _graph;
    final current = _currentPanorama;

    if (_viewerOpen && current != null && graph != null) {
      return _buildViewer(current, panoramas!, graph);
    }
    if (panoramas != null && graph != null) {
      return _buildStartScreen(panoramas, graph);
    }
    return Scaffold(
      backgroundColor: const Color(0xff101820),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator(color: Color(0xff54dcaa))
            : _ErrorCard(error: _error!, onRetry: _loadPanoramas),
      ),
    );
  }

  Widget _buildStartScreen(List<Panorama> panoramas, PanoramaGraph graph) {
    final selected = _selectedPanorama;
    final route = _routeFrom == null || _routeTo == null
        ? null
        : graph.shortestPath(from: _routeFrom!, to: _routeTo!);
    return Scaffold(
      backgroundColor: const Color(0xff101820),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandHeader(),
              const SizedBox(height: 22),
              Text(
                _directionsMode ? 'Plan a route' : 'Choose a starting point',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _directionsMode
                    ? 'Choose From or To below, then tap its point on the map.'
                    : 'Select a panorama node on the floor map to begin.',
                style: const TextStyle(color: Color(0xffaebdc6), fontSize: 14),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CoordinateMap(
                        panoramas: panoramas,
                        graph: graph,
                        selectedPanorama: selected,
                        route: route ?? const [],
                        onPanoramaSelected: _selectMapPanorama,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _directionsMode
                      ? _buildDirectionsControls(route)
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _directionsMode = true),
                            icon: const Icon(Icons.alt_route),
                            label: Text(
                              _routeFrom == null || _routeTo == null
                                  ? 'Get directions'
                                  : 'Edit directions',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff8ff0c9),
                              side: const BorderSide(color: Color(0xff39745f)),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Row(
                    children: [
                      Expanded(child: _SelectedPosition(panorama: selected)),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: route != null
                            ? () => _startDirections(route)
                            : selected == null
                            ? null
                            : _startStreetView,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff54dcaa),
                          foregroundColor: const Color(0xff10221b),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        icon: Icon(
                          route != null ? Icons.navigation : Icons.threesixty,
                        ),
                        label: Text(
                          route != null
                              ? 'Start directions'
                              : 'Start Street View',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectMapPanorama(Panorama panorama) {
    if (!_directionsMode) {
      setState(() => _selectedPanorama = panorama);
      return;
    }
    setState(() {
      if (_selectingDestination) {
        _routeTo = panorama;
        _selectingDestination = false;
      } else {
        _routeFrom = panorama;
        _selectingDestination = true;
      }
    });
  }

  Widget _buildDirectionsControls(List<Panorama>? route) {
    final hasRoute = route != null;
    final noRoute = _routeFrom != null && _routeTo != null && route == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _routeEndpointButton(
              label: 'From',
              panorama: _routeFrom,
              selected: !_selectingDestination,
              onPressed: () => setState(() => _selectingDestination = false),
            ),
            _routeEndpointButton(
              label: 'To',
              panorama: _routeTo,
              selected: _selectingDestination,
              onPressed: () => setState(() => _selectingDestination = true),
            ),
            TextButton(
              onPressed: () => setState(() => _directionsMode = false),
              child: const Text('Done'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          noRoute
              ? 'No connected route between these points.'
              : hasRoute
              ? '${route.length - 1} ${route.length == 2 ? 'segment' : 'segments'} · '
                    '${route.map((panorama) => panorama.id).join(' → ')}'
              : 'Tap the map to select ${_selectingDestination ? 'a destination' : 'a starting point'}.',
          style: TextStyle(
            color: noRoute ? const Color(0xffffb4ab) : const Color(0xffaebdc6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _routeEndpointButton({
    required String label,
    required Panorama? panorama,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? const Color(0xff8ff0c9) : Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xff54dcaa) : const Color(0xff526774),
        ),
      ),
      child: Text('$label: ${panorama?.id ?? 'Select on map'}'),
    );
  }

  Widget _buildViewer(
    Panorama current,
    List<Panorama> panoramas,
    PanoramaGraph graph,
  ) {
    final guidedRoute = _routeTo == null
        ? null
        : graph.shortestPath(from: current, to: _routeTo!);
    final nextDirection = guidedRoute != null && guidedRoute.length > 1
        ? graph.directionTo(guidedRoute[0], guidedRoute[1])
        : null;
    final imageUrl = Uri.parse(getApiBaseUrl())
        .resolve('/images/${Uri.encodeComponent(current.image)}')
        .toString();
    return Scaffold(
      backgroundColor: const Color(0xff101820),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PanoramaViewer(
                    key: _viewerKey,
                    imageUrl: imageUrl,
                    heading: current.heading,
                    yawOverride: _arrivalYaw,
                  ),
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => setState(() {
                            _viewerOpen = false;
                            _selectedPanorama = _currentPanorama;
                          }),
                          tooltip: 'Back to floor map',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xdd101820),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: _BrandHeader(compact: true)),
                        PopupMenuButton<String>(
                          tooltip: 'Orientation calibration',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'view') {
                              _showOrientationAssignments();
                            } else if (value == 'reset_all') {
                              _resetAllOrientations();
                            } else if (value.startsWith('reset:')) {
                              _resetOrientation(value.substring(6));
                            } else {
                              _assignOrientation(value);
                            }
                          },
                          itemBuilder: (context) => [
                            for (final direction in _orientationDirections)
                              PopupMenuItem(
                                value: direction,
                                child: Text('Set current view as $direction'),
                              ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'view',
                              child: Text('View orientation assignments'),
                            ),
                            for (final direction in _orientationDirections)
                              PopupMenuItem(
                                value: 'reset:$direction',
                                child: Text('Reset $direction assignment'),
                              ),
                            const PopupMenuItem(
                              value: 'reset_all',
                              child: Text('Reset all orientations'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_routeTo != null)
                    Positioned(
                      top: 58,
                      left: 12,
                      right: 12,
                      child: _GuidanceBanner(
                        nextDirection: nextDirection,
                        remainingSteps: guidedRoute == null
                            ? null
                            : guidedRoute.length - 1,
                      ),
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: PositionOverlay(panorama: current),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 450;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xff101820),
                      border: Border(top: BorderSide(color: Color(0xff34444f))),
                    ),
                    child: Row(
                      children: [
                        if (_mapVisible)
                          Expanded(
                            child: _MiniMap(
                              height: constraints.maxHeight - 8,
                              panoramas: panoramas,
                              graph: graph,
                              currentPanorama: current,
                              route: guidedRoute ?? const [],
                              onClose: () =>
                                  setState(() => _mapVisible = false),
                            ),
                          )
                        else
                          IconButton.filledTonal(
                            onPressed: () => setState(() => _mapVisible = true),
                            tooltip: 'Show minimap',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xff1a2832),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.map_outlined),
                          ),
                        const SizedBox(width: 8),
                        NavigationControls(
                          compact: compact,
                          availableDirections: graph
                              .neighborsOf(current)
                              .keys
                              .toSet(),
                          nextDirection: nextDirection,
                          onNavigate: _move,
                          onZoomOut: () => _viewerKey.currentState?.zoomBy(10),
                          onZoomIn: () => _viewerKey.currentState?.zoomBy(-10),
                          onReset: () => _viewerKey.currentState?.resetView(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            color: const Color(0xdd101820),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.explore_outlined,
            color: Color(0xff54dcaa),
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CAMPUS VIEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Ground Floor',
                style: TextStyle(color: Color(0xffc1cbd1), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedPosition extends StatelessWidget {
  const _SelectedPosition({required this.panorama});

  final Panorama? panorama;

  @override
  Widget build(BuildContext context) {
    final coordinate = panorama?.coordinate;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff1a2832),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xff54dcaa).withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECTED START',
              style: TextStyle(
                color: Color(0xff9eb0bc),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              coordinate == null
                  ? 'Tap a panorama node on the map'
                  : 'X: ${coordinate.x}    Y: ${coordinate.y}    Z: ${coordinate.z}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.height,
    required this.panoramas,
    required this.graph,
    required this.currentPanorama,
    required this.route,
    required this.onClose,
  });

  final double height;
  final List<Panorama> panoramas;
  final PanoramaGraph graph;
  final Panorama currentPanorama;
  final List<Panorama> route;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xff1a2832),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.map_outlined,
                color: Color(0xff54dcaa),
                size: 15,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'GROUND FLOOR',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                child: const Icon(
                  Icons.close,
                  color: Color(0xffaab7bf),
                  size: 17,
                ),
              ),
            ],
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CoordinateMap(
                panoramas: panoramas,
                graph: graph,
                currentPanorama: currentPanorama,
                route: route,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({
    required this.nextDirection,
    required this.remainingSteps,
  });

  final PanoramaDirection? nextDirection;
  final int? remainingSteps;

  @override
  Widget build(BuildContext context) {
    final arrived = remainingSteps == 0;
    final direction = nextDirection;
    final instruction = arrived
        ? 'You have arrived at your destination'
        : direction == null
        ? 'Route unavailable from this location'
        : 'Next: press ${_directionName(direction)}';
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xee101820),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: arrived
                  ? const Color(0xff54dcaa)
                  : const Color(0xff39745f),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Icon(
                  arrived ? Icons.flag_outlined : Icons.navigation_outlined,
                  color: const Color(0xff54dcaa),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        instruction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!arrived && remainingSteps != null)
                        Text(
                          '$remainingSteps ${remainingSteps == 1 ? 'move' : 'moves'} remaining',
                          style: const TextStyle(
                            color: Color(0xffaebdc6),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (direction != null)
                  Icon(
                    _directionIcon(direction),
                    color: const Color(0xff54dcaa),
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _directionName(PanoramaDirection direction) =>
      switch (direction) {
        PanoramaDirection.forward => 'Forward',
        PanoramaDirection.backward => 'Backward',
        PanoramaDirection.left => 'Left',
        PanoramaDirection.right => 'Right',
      };

  static IconData _directionIcon(PanoramaDirection direction) =>
      switch (direction) {
        PanoramaDirection.forward => Icons.arrow_upward,
        PanoramaDirection.backward => Icons.arrow_downward,
        PanoramaDirection.left => Icons.arrow_back,
        PanoramaDirection.right => Icons.arrow_forward,
      };
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xf51a2832),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, color: Color(0xffffc078)),
            const SizedBox(height: 9),
            const Text(
              'Can’t connect to Campus View',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xffc1cbd1), fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
