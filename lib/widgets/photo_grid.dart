import 'package:flutter/material.dart';

class PhotoItem {
  final String url;
  final bool blurred;
  PhotoItem(this.url, this.blurred);
}

class PhotoGrid extends StatelessWidget {
  final List<PhotoItem> photos;
  const PhotoGrid({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final p = photos[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(p.url, fit: BoxFit.cover),
              if (p.blurred)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      },
    );
  }
}
