import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProcessedAttachment {
  final String? extractedText;
  final Uint8List? rawBytesForGemini;
  final String mimeType;
  final List<Uint8List> extractedImageBytes;
  final List<String> extractedImageUrls;

  ProcessedAttachment({
    this.extractedText,
    this.rawBytesForGemini,
    required this.mimeType,
    this.extractedImageBytes = const [],
    this.extractedImageUrls = const [],
  });
}

class AIAttachmentHelper {
  /// Resolves the accurate MIME type for any uploaded file format.
  static String resolveMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      // Audio
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/x-m4a';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';

      // Video
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';

      // Images
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';

      // Documents & Text
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
      case 'markdown':
        return 'text/markdown';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'text/xml';
      case 'html':
      case 'htm':
        return 'text/html';

      // Office
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      // Code Formats
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'cpp':
      case 'c':
      case 'h':
      case 'cs':
      case 'sql':
      case 'rs':
      case 'go':
      case 'kt':
      case 'swift':
      case 'rb':
      case 'php':
        return 'text/plain';

      default:
        return 'application/octet-stream';
    }
  }

  static bool isImage(String fileName) {
    final mime = resolveMimeType(fileName);
    return mime.startsWith('image/');
  }

  static bool isAudio(String fileName) {
    final mime = resolveMimeType(fileName);
    return mime.startsWith('audio/');
  }

  static bool isPptx(String fileName) {
    return fileName.toLowerCase().endsWith('.pptx');
  }

  static bool isDocx(String fileName) {
    return fileName.toLowerCase().endsWith('.docx');
  }

  /// Processes any uploaded file: extracts text & images from PPTX/DOCX,
  /// prepares image bytes, or packages native PDF/Audio bytes for Gemini AI.
  static Future<ProcessedAttachment> processAttachment({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final mime = resolveMimeType(fileName);
    final ext = fileName.split('.').last.toLowerCase();

    // 1. Process PPTX (PowerPoint Presentation)
    if (ext == 'pptx') {
      try {
        final archive = ZipDecoder().decodeBytes(fileBytes);
        final StringBuffer slideText = StringBuffer();
        final List<Uint8List> extractedImages = [];

        for (final file in archive) {
          if (!file.isFile) continue;

          // Extract text from slide XMLs
          if (file.name.startsWith('ppt/slides/slide') &&
              file.name.endsWith('.xml')) {
            try {
              final xmlContent = utf8.decode(file.content as List<int>);
              // Extract text inside <a:t>...</a:t>
              final matches =
                  RegExp(r'<a:t>(.*?)</a:t>').allMatches(xmlContent);
              for (final m in matches) {
                final t = m.group(1);
                if (t != null && t.trim().isNotEmpty) {
                  slideText.writeln(t.trim());
                }
              }
            } catch (_) {}
          }

          // Extract authentic images and diagrams from ppt/media/
          if (file.name.startsWith('ppt/media/')) {
            try {
              final bytes = Uint8List.fromList(file.content as List<int>);
              if (bytes.length > 5000) {
                // Filter out tiny 1px icons/spacers
                extractedImages.add(bytes);
              }
            } catch (_) {}
          }
        }

        // Upload extracted images to Supabase storage
        final imageUrls = await uploadExtractedImages(extractedImages);

        return ProcessedAttachment(
          extractedText: slideText.isNotEmpty ? slideText.toString() : null,
          mimeType: 'text/plain',
          extractedImageBytes: extractedImages,
          extractedImageUrls: imageUrls,
        );
      } catch (e) {
        debugPrint('Error decoding PPTX archive: $e');
      }
    }

    // 2. Process DOCX (Word Document)
    if (ext == 'docx') {
      try {
        final archive = ZipDecoder().decodeBytes(fileBytes);
        final StringBuffer docText = StringBuffer();
        final List<Uint8List> extractedImages = [];

        for (final file in archive) {
          if (!file.isFile) continue;

          if (file.name == 'word/document.xml') {
            try {
              final xmlContent = utf8.decode(file.content as List<int>);
              final matches =
                  RegExp(r'<w:t>(.*?)</w:t>').allMatches(xmlContent);
              for (final m in matches) {
                final t = m.group(1);
                if (t != null && t.trim().isNotEmpty) {
                  docText.writeln(t.trim());
                }
              }
            } catch (_) {}
          }

          if (file.name.startsWith('word/media/')) {
            try {
              final bytes = Uint8List.fromList(file.content as List<int>);
              if (bytes.length > 5000) {
                extractedImages.add(bytes);
              }
            } catch (_) {}
          }
        }

        final imageUrls = await uploadExtractedImages(extractedImages);

        return ProcessedAttachment(
          extractedText: docText.isNotEmpty ? docText.toString() : null,
          mimeType: 'text/plain',
          extractedImageBytes: extractedImages,
          extractedImageUrls: imageUrls,
        );
      } catch (e) {
        debugPrint('Error decoding DOCX archive: $e');
      }
    }

    // 3. Process Direct Image Upload
    if (isImage(fileName)) {
      final imageUrls = await uploadExtractedImages([fileBytes]);
      return ProcessedAttachment(
        rawBytesForGemini: fileBytes,
        mimeType: mime,
        extractedImageBytes: [fileBytes],
        extractedImageUrls: imageUrls,
      );
    }

    // 4. Process Text / Code Files
    if (mime.startsWith('text/') ||
        ext == 'json' ||
        ext == 'xml' ||
        ext == 'csv' ||
        ext == 'dart' ||
        ext == 'py' ||
        ext == 'js' ||
        ext == 'ts' ||
        ext == 'java' ||
        ext == 'cpp' ||
        ext == 'sql') {
      try {
        final text = utf8.decode(fileBytes);
        return ProcessedAttachment(
          extractedText: text,
          mimeType: 'text/plain',
        );
      } catch (_) {}
    }

    // 5. Native Multimodal Files (PDF, Audio, Video, etc.)
    return ProcessedAttachment(
      rawBytesForGemini: fileBytes,
      mimeType: mime,
    );
  }

  /// Uploads extracted authentic images into Supabase Storage `quiz_images` bucket.
  static Future<List<String>> uploadExtractedImages(
    List<Uint8List> images,
  ) async {
    final List<String> urls = [];
    final client = Supabase.instance.client;

    for (int i = 0; i < images.length && i < 10; i++) {
      try {
        final fileName =
            'extracted_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await client.storage.from('quiz_images').uploadBinary(
              fileName,
              images[i],
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        final publicUrl =
            client.storage.from('quiz_images').getPublicUrl(fileName);
        urls.add(publicUrl);
      } catch (e) {
        debugPrint('Error uploading extracted image $i: $e');
      }
    }

    return urls;
  }
}
