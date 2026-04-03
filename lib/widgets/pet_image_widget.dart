import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Unified image widget with priority:
///   1. [photoUrl]    — remote URL (future backend / Firebase Storage)
///   2. [photoBase64] — Base64-encoded bytes (current Pet local storage)
///   3. [photoPath]   — local file path (current reports / community storage)
///   4. [placeholder] — custom or default icon fallback
class PetImageWidget extends StatelessWidget {
  final String? photoUrl;
  final String? photoBase64;
  final String? photoPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const PetImageWidget({
    super.key,
    this.photoUrl,
    this.photoBase64,
    this.photoPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  Widget _fallback() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F4F3),
            borderRadius: borderRadius,
          ),
          child: const Icon(
            Icons.pets_rounded,
            color: Color(0xFF0F7C82),
          ),
        );
  }

  Widget _clip(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Remote URL — backend-ready path
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return _clip(
        Image.network(
          photoUrl!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }

    // 2. Base64 — existing Pet model storage
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64!);
        return _clip(
          Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        );
      } catch (_) {}
    }

    // 3. Local file path — non-web only
    if (!kIsWeb && photoPath != null && photoPath!.trim().isNotEmpty) {
      return _clip(
        Image.file(
          File(photoPath!),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }

    // 4. Placeholder
    return _fallback();
  }
}

/// Returns an [ImageProvider] using the same priority as [PetImageWidget].
/// Useful for [BoxDecoration.image] or [CircleAvatar.backgroundImage].
/// Returns null when no image source is available.
ImageProvider? petImageProvider({
  String? photoUrl,
  String? photoBase64,
  String? photoPath,
}) {
  if (photoUrl != null && photoUrl.trim().isNotEmpty) {
    return NetworkImage(photoUrl);
  }
  if (photoBase64 != null && photoBase64.isNotEmpty) {
    try {
      return MemoryImage(base64Decode(photoBase64));
    } catch (_) {}
  }
  if (!kIsWeb && photoPath != null && photoPath.trim().isNotEmpty) {
    return FileImage(File(photoPath));
  }
  return null;
}

/// Returns true when at least one image source is non-empty.
bool hasAnyImage({
  String? photoUrl,
  String? photoBase64,
  String? photoPath,
}) {
  if (photoUrl != null && photoUrl.trim().isNotEmpty) return true;
  if (photoBase64 != null && photoBase64.isNotEmpty) return true;
  if (photoPath != null && photoPath.trim().isNotEmpty) return true;
  return false;
}
