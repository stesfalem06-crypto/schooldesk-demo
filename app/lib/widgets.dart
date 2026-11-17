import 'package:material_ui/material_ui.dart';

import 'theme.dart';

List<Map<String, dynamic>> asMaps(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
}

class Numpad extends StatefulWidget {
  const Numpad({super.key, required this.title, this.hint = '', this.initial = ''});
  final String title;
  final String hint;
  final String initial;

  @override
  State<Numpad> createState() => _NumpadState();
}

class _NumpadState extends State<Numpad> {
  late String value = widget.initial;

  void push(String key) {
    setState(() {
      if (key == '⌫') {
        if (value.isNotEmpty) value = value.substring(0, value.length - 1);
        return;
      }
      if (key == '.' && value.contains('.')) return;
      if (value.length >= 6) return;
      value += key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (widget.hint.isNotEmpty) Text(widget.hint, style: const TextStyle(fontSize: 16, color: leaf)),
          const SizedBox(height: 8),
          Text(value.isEmpty ? '0' : value, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            childAspectRatio: 1.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final key in keys)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: key == '⌫' ? ink : leaf),
                  onPressed: () => push(key),
                  child: Text(key, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 18)))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, value.isEmpty ? '0' : value), child: const Text('Save'))),
            ],
          ),
          const SizedBox(height: 8),
          const Text(footerText, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: ink)),
        ],
      ),
    );
  }
}

Future<double?> askNumber(BuildContext context, String title, {String hint = '', String initial = ''}) async {
  final raw = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Numpad(title: title, hint: hint, initial: initial),
  );
  if (raw == null) return null;
  return double.tryParse(raw);
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20))));
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.text, this.onRetry, {super.key});
  final String text;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: failRed, size: 48),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ]),
      ),
    );
  }
}
