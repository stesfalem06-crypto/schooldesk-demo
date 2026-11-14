import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'edition.dart';
import 'local_server.dart';
import 'screens.dart';
import 'shell.dart';
import 'theme.dart';
import 'vault.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final local = await startBundledServer();
  final model = AppModel(Vault());
  await model.boot();
  if (local && (model.base == null || model.base!.isEmpty)) {
    final skip = await model.vault.read('skip_local');
    if (skip != '1') await model.setBase('http://127.0.0.1:$localPort');
  }
  runApp(ChangeNotifierProvider.value(value: model, child: const SchoolApp()));
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: demoEdition ? 'SchoolDesk Demo' : 'SchoolDesk',
      debugShowCheckedModeBanner: false,
      theme: schoolTheme(),
      home: const Gate(),
    );
  }
}

class Gate extends StatelessWidget {
  const Gate({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    if (model.base == null) return const ConnectScreen();
    if (!model.licensed) return const LockScreen();
    if (model.token == null || model.token!.isEmpty || model.user.isEmpty) return const LoginScreen();
    return DeskHost(home: const HomeScreen(), pages: rolePages);
  }
}
