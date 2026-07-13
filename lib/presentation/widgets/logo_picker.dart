import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/services/logo_service.dart';
import '../../../theme/app_theme.dart';

/// Tappable logo picker — shows the current logo (or a placeholder icon),
/// opens a bottom sheet with Gallery / Camera / Remove options on tap.
class LogoPicker extends StatelessWidget {
  const LogoPicker({
    super.key,
    required this.currentPath,
    required this.onChanged,
  });

  final String? currentPath;
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final choice = await showModalBottomSheet<_LogoAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, _LogoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, _LogoAction.camera),
            ),
            if (currentPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove logo',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, _LogoAction.remove),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (choice == null) return;

    switch (choice) {
      case _LogoAction.gallery:
        final path = await LogoService.pickFromGallery();
        if (path != null) onChanged(path);
        break;
      case _LogoAction.camera:
        final path = await LogoService.pickFromCamera();
        if (path != null) onChanged(path);
        break;
      case _LogoAction.remove:
        await LogoService.delete(currentPath);
        onChanged(null);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = currentPath != null && File(currentPath!).existsSync();
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.subtleContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: hasLogo
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(currentPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 32),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 28, color: theme.colorScheme.primary),
                        const SizedBox(height: 4),
                        Text(
                          'Add logo',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Optional • PNG/JPG',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

enum _LogoAction { gallery, camera, remove }
