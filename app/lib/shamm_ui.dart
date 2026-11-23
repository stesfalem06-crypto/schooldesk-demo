import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'edition.dart';
import 'shell.dart';
import 'theme.dart';

/// Opens a live call. The real call screen replaces this when the app starts.
Widget Function(BuildContext context, String id, String name) startCall =
    (context, id, name) => CallBoard(name: name, status: 'Calling $name', onEnd: () => Navigator.pop(context));

class PinLogin extends StatefulWidget {
  const PinLogin({super.key, this.names = const [], this.onSubmit});

  final List<String> names;
  final Future<String?> Function(String name, String pin)? onSubmit;

  @override
  State<PinLogin> createState() => _PinLoginState();
}

class _PinLoginState extends State<PinLogin> {
  List<Map<String, dynamic>> people = [];
  String? chosenId;
  String chosenName = '';
  String pin = '';
  String? problem;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.names.isNotEmpty) {
      people = [for (final name in widget.names) {'id': name, 'display_name': name}];
    } else {
      load();
    }
  }

  Future<void> load() async {
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/auth/people'));
      people = (raw as List).whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> submit() async {
    if (chosenId == null || pin.length != 4) {
      setState(() => problem = 'Tap your name, then type 4 numbers');
      return;
    }
    setState(() { busy = true; problem = null; });
    String? msg;
    if (widget.onSubmit != null) {
      msg = await widget.onSubmit!(chosenName, pin);
    } else {
      msg = await context.read<AppModel>().signInPin(chosenId!, pin);
    }
    if (mounted) setState(() { busy = false; problem = msg; pin = msg == null ? pin : ''; });
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Sign in',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tap your name', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final person in people)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: chosenId == person['id'].toString() ? leafDark : leaf,
                  minimumSize: const Size(64, 64),
                ),
                onPressed: () => setState(() { chosenId = person['id'].toString(); chosenName = person['display_name'].toString(); problem = null; }),
                child: Text(person['display_name'].toString(), style: const TextStyle(fontSize: 22)),
              ),
            ),
          const SizedBox(height: 8),
          Text(pin.isEmpty ? 'Type your 4 numbers' : pin, textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 8)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.1,
            children: [
              for (final key in ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'Clear', '0', 'Go'])
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (key == 'Clear') setState(() => pin = '');
                            else if (key == 'Go') submit();
                            else if (pin.length < 4) setState(() => pin += key);
                          },
                    child: Text(key, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          if (problem != null) Text(problem!, style: const TextStyle(color: failRed, fontSize: 18)),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.previewPeople, this.previewMessages});

  final List<String>? previewPeople;
  final List<String>? previewMessages;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> people = [];
  List<Map<String, dynamic>> messages = [];
  String withId = 'staff';
  String withName = 'All staff';
  final box = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.previewPeople != null) {
      people = [for (final name in widget.previewPeople!) {'id': name, 'display_name': name}];
      messages = [for (final text in widget.previewMessages ?? const []) {'from_name': 'Hanna Berhe', 'body': text}];
      loading = false;
    } else {
      loadPeople();
    }
  }

  Future<void> loadPeople() async {
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/auth/people'));
      people = (raw as List).whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
    } catch (_) {}
    await loadMessages();
  }

  Future<void> loadMessages() async {
    if (widget.previewPeople != null) return;
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/chat/messages?with=$withId'));
      messages = (raw as List).whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> send() async {
    final text = box.text.trim();
    if (text.isEmpty) return;
    if (widget.previewPeople != null) {
      setState(() { messages = [...messages, {'from_name': 'You', 'body': text}]; box.clear(); });
      return;
    }
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/chat/messages', {'to': withId, 'body': text}));
      box.clear();
      await loadMessages();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Messages',
      hint: withName,
      body: Column(children: [
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              personChip('staff', 'All staff'),
              for (final person in people) personChip(person['id'].toString(), person['display_name'].toString()),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final msg in messages)
                      Card(
                        child: ListTile(
                          title: Text(msg['from_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(msg['body']?.toString() ?? '', style: const TextStyle(fontSize: 18, color: ink)),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(child: TextField(controller: box, decoration: const InputDecoration(hintText: 'Type a message'), onSubmitted: (_) => send())),
            const SizedBox(width: 8),
            FilledButton(onPressed: send, child: const Text('Send')),
          ]),
        ),
      ]),
    );
  }

  Widget personChip(String id, String name) {
    final on = withId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(children: [
        ChoiceChip(
          label: Text(name, style: const TextStyle(fontSize: 16)),
          selected: on,
          onSelected: (_) {
            setState(() { withId = id; withName = name; loading = widget.previewPeople == null; });
            loadMessages();
          },
        ),
        if (id != 'staff')
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => startCall(context, id, name)));
            },
          ),
      ]),
    );
  }
}

class CallBoard extends StatelessWidget {
  const CallBoard({super.key, required this.name, required this.status, this.onEnd});

  final String name;
  final String status;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Call',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_in_talk, size: 72, color: leaf),
            const SizedBox(height: 12),
            Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            const Text('This call stays on the school network.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: failRed, minimumSize: const Size(220, 64)),
              onPressed: onEnd,
              child: const Text('End call'),
            ),
          ]),
        ),
      ),
    );
  }
}

class TimetableBoard extends StatelessWidget {
  const TimetableBoard({super.key, required this.rows});

  final List<Map<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Timetable',
      hint: 'Your week',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final row in rows)
            Card(
              child: ListTile(
                title: Text('${row['day']}  period ${row['period']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                subtitle: Text('${row['class']}  ${row['subject']}  ${row['teacher']}', style: const TextStyle(fontSize: 18, color: ink)),
              ),
            ),
        ],
      ),
    );
  }
}

class UpdatePrompt extends StatelessWidget {
  const UpdatePrompt({super.key, this.onInstall, this.onLater});

  final VoidCallback? onInstall;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Update',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.system_update, size: 72, color: leaf),
            const SizedBox(height: 16),
            const Text('Update available, install', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('The school records stay on the school computer.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            FilledButton(onPressed: onInstall, child: const Text('Install')),
            const SizedBox(height: 8),
            TextButton(onPressed: onLater, child: const Text('Later', style: TextStyle(fontSize: 18))),
          ]),
        ),
      ),
    );
  }
}

Future<void> offerUpdate(BuildContext context, AppModel model) async {
  if (demoEdition) return;
  try {
    final info = await model.ask((api) => api.get('/api/v1/client/info')) as Map;
    final version = info['version']?.toString() ?? '';
    if (version.isEmpty || version == clientVersion || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update available, install', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        content: const Text('The school records stay on the school computer.', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await installClient(model);
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  } catch (_) {}
}

Future<void> installClient(AppModel model) async {
  final name = Platform.isAndroid ? 'client.apk' : 'client-windows.exe';
  final bytes = await model.ask((api) => api.bytes('/api/v1/client/file/$name'));
  if (bytes is! List<int>) return;
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes);
  if (Platform.isAndroid) {
    await const MethodChannel('school/update').invokeMethod('install', {'path': file.path});
  } else if (Platform.isWindows) {
    await Process.start(file.path, [], mode: ProcessStartMode.detached);
  }
}

Future<String?> scanSchoolCode() async {
  try {
    final text = await const MethodChannel('school/scan').invokeMethod<String>('scan');
    if (text == null || text.isEmpty) return null;
    return text.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'^shamm://'), '');
  } catch (_) {
    return null;
  }
}
