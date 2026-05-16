import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BmsImageViewer extends StatefulWidget {
  const BmsImageViewer({super.key, required this.imageProvider});

  final ImageProvider imageProvider;

  static void show(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => BmsImageViewer(imageProvider: imageProvider),
    );
  }

  @override
  State<BmsImageViewer> createState() => _BmsImageViewerState();
}

class _BmsImageViewerState extends State<BmsImageViewer> {
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

  void _zoom(double factor) {
    setState(() {
      _currentScale = (_currentScale * factor).clamp(1.0, 5.0);
      _transformationController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _zoom(0.9), // ~10% decrease
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoom(1.1), // ~10% increase
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: () {
              setState(() {
                _currentScale = 1.0;
                _transformationController.value = Matrix4.identity();
              });
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 5.0,
          onInteractionUpdate: (details) {
            // Update scale tracker if pinched manually
            _currentScale = _transformationController.value.getMaxScaleOnAxis();
          },
          child: Image(
            image: widget.imageProvider,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}
