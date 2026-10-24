import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:peripage_app/config/theme.dart';
import 'package:peripage_app/core/printing/domain/print_job_entity.dart';
import 'package:peripage_app/presentation/common/widgets/glass/glass_panel.dart';

/// Shows a 1-bit page on a paper strip that slowly feeds out of a glass slot whenever the page changes.
class ThermalPreview extends StatefulWidget {
  const ThermalPreview({super.key, required this.bitmap, this.paperWidth = 210});

  final PreviewBitmap? bitmap;
  final double paperWidth;

  @override
  State<ThermalPreview> createState() => _ThermalPreviewState();
}

class _ThermalPreviewState extends State<ThermalPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _feed = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(ThermalPreview old) {
    super.didUpdateWidget(old);
    if (old.bitmap != widget.bitmap) _decode();
  }

  @override
  void dispose() {
    _feed.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final bitmap = widget.bitmap;
    if (bitmap == null) {
      setState(() => _image = null);
      return;
    }
    final rgba = Uint8List(bitmap.width * bitmap.height * 4);
    for (var i = 0; i < bitmap.pixels.length; i++) {
      final v = bitmap.pixels[i] == 1 ? 0 : 255;
      rgba[i * 4] = v;
      rgba[i * 4 + 1] = v;
      rgba[i * 4 + 2] = v;
      rgba[i * 4 + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, bitmap.width, bitmap.height, ui.PixelFormat.rgba8888, completer.complete);
    final image = await completer.future;
    if (!mounted) return image.dispose();

    setState(() {
      _image?.dispose();
      _image = image;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _feed.value = 1;
    } else {
      unawaited(_feed.forward(from: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final paperHeight = image == null ? 0.0 : widget.paperWidth * image.height / image.width;

    return Column(
      children: [
        SizedBox(
          width: widget.paperWidth + 26,
          height: 12,
          child: const GlassPanel(radius: 6, padding: EdgeInsets.zero, child: SizedBox.expand()),
        ),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: _feed,
                builder: (context, _) => Align(
                  alignment: Alignment.topCenter,
                  heightFactor: Curves.easeInOutCubic.transform(_feed.value),
                  child: Container(
                    width: widget.paperWidth,
                    height: paperHeight,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -14)],
                    ),
                    child: image == null ? null : RawImage(image: image, fit: BoxFit.fill, filterQuality: FilterQuality.none),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder shown before a file is picked.
class EmptyPreview extends StatelessWidget {
  const EmptyPreview({super.key, required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.glass;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 36, color: colors.muted.withValues(alpha: .6)),
          const SizedBox(height: 10),
          Text(hint, textAlign: TextAlign.center, style: TextStyle(color: colors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
