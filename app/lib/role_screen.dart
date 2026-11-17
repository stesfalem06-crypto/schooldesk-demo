import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'school_book.dart';
import 'shell.dart';
import 'theme.dart';

class ChooseRoleScreen extends StatelessWidget {
  const ChooseRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Choose who you are',
      hint: 'One tap. No password.',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Pick the job you do today. You can switch later.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          _role(context, 'School admin', 'The whole school', 'admin'),
          _role(context, 'Director', 'Look and report', 'director'),
          _role(context, 'Homeroom teacher', 'Samuel, Grade 8A', 'homeroom'),
          _role(context, 'Subject teacher', 'Meron, English', 'subject'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              SchoolBook.instance.resetNow();
              if (context.mounted) saved(context, 'Sample data is new again');
            },
            child: const Text('Reset sample data'),
          ),
        ],
      ),
    );
  }

  Widget _role(BuildContext context, String title, String subtitle, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFFCFAF6),
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          key: Key('role-$title'),
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.read<AppModel>().enterRole(key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy, fontFamily: 'Georgia')),
                Text(subtitle, style: const TextStyle(fontSize: 16, color: navyInk)),
              ])),
              const Icon(Icons.arrow_forward, color: navy),
            ]),
          ),
        ),
      ),
    );
  }
}
