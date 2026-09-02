import 'package:flutter/material.dart';
import '../services/ai_quiz_service.dart';

/// Opens the dynamic Gemini Model Selector modal bottom sheet.
Future<String?> showGeminiModelSelectorSheet({
  required BuildContext context,
  required String currentModel,
  VoidCallback? onApiKeyRequested,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GeminiModelSelectorSheet(
      currentModel: currentModel,
      onApiKeyRequested: onApiKeyRequested,
    ),
  );
}

class GeminiModelSelectorSheet extends StatefulWidget {
  final String currentModel;
  final VoidCallback? onApiKeyRequested;

  const GeminiModelSelectorSheet({
    super.key,
    required this.currentModel,
    this.onApiKeyRequested,
  });

  @override
  State<GeminiModelSelectorSheet> createState() =>
      _GeminiModelSelectorSheetState();
}

class _GeminiModelSelectorSheetState extends State<GeminiModelSelectorSheet> {
  List<GeminiModelInfo> _models = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasApiKey = false;
  late String _selectedModel;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.currentModel;
    _loadModels(forceRefresh: false);
  }

  Future<void> _loadModels({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiKey = await AIQuizService.getApiKey();
    _hasApiKey = apiKey != null && apiKey.isNotEmpty;

    if (!_hasApiKey) {
      // Fallback to static models when no key configured
      final fallback = await AIQuizService.fetchLiveModelsWithFallback();
      if (mounted) {
        setState(() {
          _models = fallback;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final liveModels = await AIQuizService.fetchAvailableModelDetailsForApiKey(
        apiKey!,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _models = liveModels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Try fallback to cache or default if network fails
        final fallback = await AIQuizService.fetchLiveModelsWithFallback();
        setState(() {
          _models = fallback;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildModelBadge(String modelId) {
    String label;
    Color bg;
    Color fg;

    if (modelId.contains('flash')) {
      label = 'FLASH';
      bg = Colors.teal.shade50;
      fg = Colors.teal.shade700;
    } else if (modelId.contains('pro')) {
      label = 'PRO';
      bg = Colors.deepPurple.shade50;
      fg = Colors.deepPurple.shade700;
    } else if (modelId.contains('thinking') || modelId.contains('exp')) {
      label = 'EXP';
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    } else {
      label = 'AI';
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Gemini Model',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _hasApiKey
                                    ? Colors.green
                                    : Colors.orangeAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _hasApiKey
                                  ? 'Live Authorized Models'
                                  : 'No API Key configured',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Refresh Button
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh live models from Google',
                    onPressed: _isLoading
                        ? null
                        : () => _loadModels(forceRefresh: true),
                  ),

                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // API key prompt if key is missing
            if (!_hasApiKey)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Showing standard models. Add your API key to discover your authorized live models.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (widget.onApiKeyRequested != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onApiKeyRequested!();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Set Key',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Error banner if any
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live refresh warning: $_errorMessage (showing cached/fallback models)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Models List
            Flexible(
              child: _isLoading && _models.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Discovering available models from Google AI Studio...',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _models.length,
                      separatorBuilder: (ctx, idx) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (ctx, idx) {
                        final model = _models[idx];
                        final isSelected = model.id == _selectedModel;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.deepPurple.withValues(alpha: 0.15)
                                  : (isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade100),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.smart_toy_outlined,
                              size: 18,
                              color:
                                  isSelected ? Colors.deepPurple : Colors.grey,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  model.displayName,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 14,
                                    color:
                                        isSelected ? Colors.deepPurple : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildModelBadge(model.id),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                model.id,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              if (model.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  model.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.25,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.deepPurple,
                                  size: 22,
                                )
                              : null,
                          onTap: () async {
                            setState(() => _selectedModel = model.id);
                            await AIQuizService.saveSelectedModel(model.id);
                            if (ctx.mounted) {
                              Navigator.pop(ctx, model.id);
                            }
                          },
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
