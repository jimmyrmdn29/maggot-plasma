import 'package:flutter/material.dart';

// =========================================================================
// WIDGET: PICKER COVER (THUMBNAIL)
// =========================================================================
class CoverPicker extends StatelessWidget {
  final String? coverUrl;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const CoverPicker({
    super.key,
    required this.coverUrl,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Cover (thumbnail)",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey[200],
            child: (coverUrl != null && coverUrl!.isNotEmpty)
                ? Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 32, color: Colors.grey),
                        SizedBox(height: 4),
                        Text("Belum ada cover", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: Text(isUploading ? "Mengupload..." : "Pilih Cover"),
                onPressed: isUploading ? null : onPick,
              ),
            ),
            if (coverUrl != null && coverUrl!.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Hapus cover",
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: isUploading ? null : onRemove,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
