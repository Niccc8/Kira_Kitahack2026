/// StorageImage — Smart Firebase Storage / generic URL image loader.
///
/// Features:
/// - In-memory cache: images loaded once are instant on revisit
/// - Firebase Storage URLs: uses `getData()` via Firebase SDK
/// - gs:// URLs: resolved via `refFromURL()`
/// - Regular URLs: standard `Image.network()`
/// - Clean loading state (no icon flash)
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Loads an image from a URL — auto-detects Firebase Storage vs regular URL.
class StorageImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget? fallback;

  const StorageImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  /// Clear the in-memory image cache (e.g. on logout).
  static void clearCache() => _StorageImageState._cache.clear();

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  /// In-memory cache keyed by URL → loaded bytes.
  static final Map<String, Uint8List> _cache = {};

  /// Per-URL dedup: avoid parallel fetches for the same URL.
  static final Map<String, Future<Uint8List?>> _inflight = {};

  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  /// Is this a Firebase Storage URL (https or gs://)?
  static bool _isFirebaseUrl(String url) =>
      url.contains('firebasestorage.googleapis.com') ||
      url.startsWith('gs://');

  /// Is this a bundled asset path? (asset:path/to/image)
  static bool _isAssetUrl(String url) => url.startsWith('asset:');

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _startLoad();
    }
  }

  void _startLoad() {
    final url = widget.url;

    // Already cached — instant display
    if (_cache.containsKey(url)) {
      _bytes = _cache[url];
      _loading = false;
      _failed = false;
      return;
    }

    // Not a Firebase URL — let Image.network handle it
    if (!_isFirebaseUrl(url)) {
      _loading = false;
      return;
    }

    // Start async fetch (deduped)
    _loading = true;
    _failed = false;
    _bytes = null;

    final future = _inflight.putIfAbsent(url, () => _fetchBytes(url));
    future.then((data) {
      _inflight.remove(url);
      if (data != null) _cache[url] = data;
      if (mounted) {
        setState(() {
          _bytes = data;
          _loading = false;
          _failed = data == null;
        });
      }
    });
  }

  /// Fetches image bytes via Firebase Storage SDK.
  static Future<Uint8List?> _fetchBytes(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      return await ref.getData(10 * 1024 * 1024); // 10 MB max
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Asset-based images
    if (_isAssetUrl(widget.url)) {
      final assetPath = widget.url.substring(6); // strip "asset:"
      return Image.asset(
        assetPath,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.fallback ?? const SizedBox(),
      );
    }

    // Non-Firebase URLs — use regular Image.network
    if (!_isFirebaseUrl(widget.url)) {
      return Image.network(
        widget.url,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.fallback ?? const SizedBox(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildShimmer();
        },
      );
    }

    // Firebase Storage — cached or loading
    if (_loading) return _buildShimmer();
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.fallback ?? const SizedBox(),
      );
    }
    // Failed — show fallback
    return widget.fallback ?? const SizedBox();
  }

  /// Subtle shimmer placeholder — no icon flash.
  Widget _buildShimmer() {
    return Container(
      color: Colors.white.withValues(alpha: 0.04),
    );
  }
}
