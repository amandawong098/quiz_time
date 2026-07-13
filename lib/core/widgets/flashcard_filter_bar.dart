import 'package:flutter/material.dart';

class FlashcardFilterBar extends StatelessWidget {
  final String searchQuery;
  final String? selectedRange;
  final Function(String) onSearchChanged;
  final Function(String?) onRangeChanged;
  final VoidCallback onReset;

  const FlashcardFilterBar({
    super.key,
    required this.searchQuery,
    required this.selectedRange,
    required this.onSearchChanged,
    required this.onRangeChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: TextEditingController(text: searchQuery)
            ..selection = TextSelection.collapsed(offset: searchQuery.length),
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search decks',
            prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.deepPurple),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedRange,
                decoration: const InputDecoration(
                  labelText: 'No. of Cards',
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: '1-5', child: Text('1-5')),
                  DropdownMenuItem(value: '5-10', child: Text('5-10')),
                  DropdownMenuItem(value: '10-20', child: Text('10-20')),
                  DropdownMenuItem(value: '>20', child: Text('>20')),
                ],
                onChanged: onRangeChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.deepPurple,
              tooltip: 'Reset filters',
            ),
          ],
        ),
      ],
    );
  }
}
