import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RawMediaPart {
  final String mimeType;
  final Uint8List bytes;
  final String fileName;

  RawMediaPart({
    required this.mimeType,
    required this.bytes,
    required this.fileName,
  });
}

class ProcessedAttachment {
  final String? extractedText;
  final Uint8List? rawBytesForGemini;
  final String mimeType;
  final List<RawMediaPart> rawMediaParts;
  final List<Uint8List> extractedImageBytes;
  final List<String> extractedImageUrls;

  ProcessedAttachment({
    this.extractedText,
    this.rawBytesForGemini,
    this.mimeType = 'application/octet-stream',
    this.rawMediaParts = const [],
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
        rawMediaParts: [
          RawMediaPart(mimeType: mime, bytes: fileBytes, fileName: fileName),
        ],
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

    // 5. Process PDF Document (Extract authentic embedded images & provide raw PDF to Gemini)
    if (ext == 'pdf') {
      List<Uint8List> extractedImages = [];
      try {
        extractedImages = extractImagesFromPdf(fileBytes);
      } catch (e) {
        debugPrint('Error extracting images from PDF: $e');
      }

      final imageUrls = await uploadExtractedImages(extractedImages);

      return ProcessedAttachment(
        rawBytesForGemini: fileBytes,
        mimeType: mime,
        rawMediaParts: [
          RawMediaPart(mimeType: mime, bytes: fileBytes, fileName: fileName),
        ],
        extractedImageBytes: extractedImages,
        extractedImageUrls: imageUrls,
      );
    }

    // 6. Native Multimodal Files (Audio, Video, etc.)
    return ProcessedAttachment(
      rawBytesForGemini: fileBytes,
      mimeType: mime,
      rawMediaParts: [
        RawMediaPart(mimeType: mime, bytes: fileBytes, fileName: fileName),
      ],
    );
  }

  /// Processes multiple uploaded files, extracting and combining their texts, media, and images.
  static Future<ProcessedAttachment> processAttachments({
    required List<Uint8List> filesBytes,
    required List<String> filesNames,
  }) async {
    final StringBuffer combinedText = StringBuffer();
    final List<RawMediaPart> allRawParts = [];
    final List<Uint8List> allExtractedImages = [];
    final List<String> allExtractedUrls = [];

    for (int i = 0; i < filesBytes.length && i < filesNames.length; i++) {
      final bytes = filesBytes[i];
      final name = filesNames[i];
      final processed = await processAttachment(fileBytes: bytes, fileName: name);

      if (processed.extractedText != null &&
          processed.extractedText!.trim().isNotEmpty) {
        if (filesBytes.length > 1) {
          combinedText.writeln('=== Document Source: $name ===');
        }
        combinedText.writeln(processed.extractedText!.trim());
        combinedText.writeln();
      }

      for (final part in processed.rawMediaParts) {
        allRawParts.add(part);
      }

      allExtractedImages.addAll(processed.extractedImageBytes);
      allExtractedUrls.addAll(processed.extractedImageUrls);
    }

    return ProcessedAttachment(
      extractedText:
          combinedText.isNotEmpty ? combinedText.toString().trim() : null,
      rawBytesForGemini:
          allRawParts.isNotEmpty ? allRawParts.first.bytes : null,
      mimeType: allRawParts.isNotEmpty
          ? allRawParts.first.mimeType
          : 'application/octet-stream',
      rawMediaParts: allRawParts,
      extractedImageBytes: allExtractedImages,
      extractedImageUrls: allExtractedUrls,
    );
  }

  /// Extracts authentic embedded images (JPEG, PNG, FlateDecode RGB) from a PDF document.
  static List<Uint8List> extractImagesFromPdf(Uint8List pdfBytes) {
    final List<Uint8List> extracted = [];
    final Set<int> seenLengths = {};

    void addValidImage(Uint8List imageBytes) {
      if (imageBytes.length < 4000) return; // Ignore tiny icons/bullets
      if (seenLengths.contains(imageBytes.length)) return;
      seenLengths.add(imageBytes.length);
      extracted.add(imageBytes);
    }

    // 1. PDF Object Stream Parser
    int idx = 0;
    while (idx < pdfBytes.length) {
      final streamPos = _findSequence(
        pdfBytes,
        [115, 116, 114, 101, 97, 109], // 'stream'
        idx,
      );
      if (streamPos == -1) break;

      // Find preceding dictionary start '<<'
      final dictStart = _findReverseSequence(
        pdfBytes,
        [60, 60], // '<<'
        streamPos,
        streamPos - 1200,
      );
      String dictText = '';
      if (dictStart != -1) {
        try {
          dictText = latin1.decode(pdfBytes.sublist(dictStart, streamPos));
        } catch (_) {}
      }

      // Skip past 'stream' and trailing newline (\r\n or \n)
      int startData = streamPos + 6;
      if (startData < pdfBytes.length && pdfBytes[startData] == 13) {
        startData++;
      }
      if (startData < pdfBytes.length && pdfBytes[startData] == 10) {
        startData++;
      }

      // Find 'endstream'
      final endstreamPos = _findSequence(
        pdfBytes,
        [101, 110, 100, 115, 116, 114, 101, 97, 109], // 'endstream'
        startData,
      );
      if (endstreamPos == -1) {
        idx = streamPos + 6;
        continue;
      }

      final streamBytes = pdfBytes.sublist(startData, endstreamPos);
      final isImage = dictText.contains('/Image') ||
          dictText.contains('/Subtype /Image') ||
          dictText.contains('/Subtype/Image');
      final isDct = dictText.contains('DCTDecode') || dictText.contains('/DCT');
      final isFlate =
          dictText.contains('FlateDecode') || dictText.contains('/Flate');

      // Case A: DCTDecode (JPEG) inside PDF stream
      if (isDct || isImage) {
        final soi = _findSequence(streamBytes, [0xFF, 0xD8, 0xFF], 0);
        if (soi != -1) {
          final eoi = _findReverseSequence(
            streamBytes,
            [0xFF, 0xD9],
            streamBytes.length,
          );
          if (eoi != -1 && eoi > soi) {
            final jpeg = streamBytes.sublist(soi, eoi + 2);
            addValidImage(jpeg);
            idx = endstreamPos + 9;
            continue;
          }
        }
      }

      // Case B: FlateDecode (uncompressed RGB) inside PDF stream
      if (isImage && isFlate && !isDct) {
        try {
          final widthMatch = RegExp(r'/Width\s+(\d+)').firstMatch(dictText);
          final heightMatch = RegExp(r'/Height\s+(\d+)').firstMatch(dictText);
          final isRgb = dictText.contains('/DeviceRGB');
          final isBpc8 = dictText.contains('/BitsPerComponent 8') ||
              !dictText.contains('/BitsPerComponent');

          if (widthMatch != null && heightMatch != null && isRgb && isBpc8) {
            final w = int.tryParse(widthMatch.group(1) ?? '');
            final h = int.tryParse(heightMatch.group(1) ?? '');
            if (w != null &&
                h != null &&
                w > 50 &&
                h > 50 &&
                w < 4000 &&
                h < 4000) {
              final decompressed = ZLibDecoder().decodeBytes(streamBytes);
              if (decompressed.length >= w * h * 3) {
                final bmp = _createBmpFromRgb(
                  w,
                  h,
                  Uint8List.fromList(decompressed),
                );
                addValidImage(bmp);
                idx = endstreamPos + 9;
                continue;
              }
            }
          }
        } catch (_) {}
      }

      idx = endstreamPos + 9;
    }

    // 2. Fallback Binary Scan: Find any standalone JPEGs or PNGs in PDF bytes
    if (extracted.isEmpty) {
      int scanIdx = 0;
      while (scanIdx < pdfBytes.length - 100) {
        final soi = _findSequence(pdfBytes, [0xFF, 0xD8, 0xFF], scanIdx);
        if (soi == -1) break;

        final m = pdfBytes[soi + 3];
        if (m == 0xE0 ||
            m == 0xE1 ||
            m == 0xDB ||
            m == 0xC0 ||
            m == 0xC2 ||
            m == 0xEE ||
            (m >= 0xE0 && m <= 0xEF)) {
          final eoi = _findSequence(pdfBytes, [0xFF, 0xD9], soi + 4);
          if (eoi != -1 &&
              (eoi - soi) > 4000 &&
              (eoi - soi) < 15 * 1024 * 1024) {
            final jpeg = pdfBytes.sublist(soi, eoi + 2);
            addValidImage(jpeg);
            scanIdx = eoi + 2;
            continue;
          }
        }
        scanIdx = soi + 3;
      }

      // Check for standalone PNGs
      int pngIdx = 0;
      while (pngIdx < pdfBytes.length - 100) {
        final pngHeader = _findSequence(
          pdfBytes,
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
          pngIdx,
        );
        if (pngHeader == -1) break;

        final iend = _findSequence(
          pdfBytes,
          [0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82],
          pngHeader + 8,
        );
        if (iend != -1 && (iend - pngHeader) > 4000) {
          final png = pdfBytes.sublist(pngHeader, iend + 8);
          addValidImage(png);
          pngIdx = iend + 8;
          continue;
        }
        pngIdx = pngHeader + 8;
      }
    }

    return extracted;
  }

  static int _findSequence(Uint8List data, List<int> pattern, int start) {
    if (pattern.isEmpty || start < 0 || start >= data.length) return -1;
    final int end = data.length - pattern.length;
    final int first = pattern[0];

    for (int i = start; i <= end; i++) {
      if (data[i] == first) {
        bool match = true;
        for (int j = 1; j < pattern.length; j++) {
          if (data[i + j] != pattern[j]) {
            match = false;
            break;
          }
        }
        if (match) return i;
      }
    }
    return -1;
  }

  static int _findReverseSequence(
    Uint8List data,
    List<int> pattern,
    int start, [
    int minPos = 0,
  ]) {
    if (pattern.isEmpty || start <= 0) return -1;
    final int from =
        (start < data.length ? start : data.length) - pattern.length;
    final int lowest = minPos >= 0 ? minPos : 0;
    final int first = pattern[0];

    for (int i = from; i >= lowest; i--) {
      if (data[i] == first) {
        bool match = true;
        for (int j = 1; j < pattern.length; j++) {
          if (data[i + j] != pattern[j]) {
            match = false;
            break;
          }
        }
        if (match) return i;
      }
    }
    return -1;
  }

  static Uint8List _createBmpFromRgb(
    int width,
    int height,
    Uint8List rgbBytes,
  ) {
    final rowSize = ((24 * width + 31) ~/ 32) * 4;
    final imageSize = rowSize * height;
    final fileSize = 54 + imageSize;

    final bmp = Uint8List(fileSize);
    final data = ByteData.view(bmp.buffer);

    bmp[0] = 0x42; // 'B'
    bmp[1] = 0x4D; // 'M'
    data.setUint32(2, fileSize, Endian.little);
    data.setUint16(6, 0, Endian.little);
    data.setUint16(8, 0, Endian.little);
    data.setUint32(10, 54, Endian.little);

    data.setUint32(14, 40, Endian.little);
    data.setInt32(18, width, Endian.little);
    data.setInt32(22, -height, Endian.little); // Top-down
    data.setUint16(26, 1, Endian.little);
    data.setUint16(28, 24, Endian.little);
    data.setUint32(30, 0, Endian.little);
    data.setUint32(34, imageSize, Endian.little);
    data.setInt32(38, 2835, Endian.little);
    data.setInt32(42, 2835, Endian.little);
    data.setUint32(46, 0, Endian.little);
    data.setUint32(50, 0, Endian.little);

    int srcIdx = 0;
    int dstRowStart = 54;

    for (int y = 0; y < height; y++) {
      int dstIdx = dstRowStart;
      for (int x = 0; x < width; x++) {
        if (srcIdx + 2 < rgbBytes.length) {
          final r = rgbBytes[srcIdx];
          final g = rgbBytes[srcIdx + 1];
          final b = rgbBytes[srcIdx + 2];
          srcIdx += 3;

          bmp[dstIdx] = b;
          bmp[dstIdx + 1] = g;
          bmp[dstIdx + 2] = r;
          dstIdx += 3;
        }
      }
      dstRowStart += rowSize;
    }

    return bmp;
  }

  /// Uploads extracted authentic images into Supabase Storage `quiz_images` bucket.
  static Future<List<String>> uploadExtractedImages(
    List<Uint8List> images,
  ) async {
    final List<String> urls = [];
    final client = Supabase.instance.client;

    for (int i = 0; i < images.length && i < 10; i++) {
      try {
        final bytes = images[i];
        String fileExt = 'jpg';
        String contentType = 'image/jpeg';

        if (bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47) {
          fileExt = 'png';
          contentType = 'image/png';
        } else if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
          fileExt = 'bmp';
          contentType = 'image/bmp';
        }

        final fileName =
            'extracted_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        await client.storage.from('quiz_images').uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(contentType: contentType),
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
