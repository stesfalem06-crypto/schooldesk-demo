import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens.dart';
import 'theme.dart';
import 'vault.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel(Vault());
  await model.boot();
  runApp(ChangeNotifierProvider.value(value: model, child: const SchoolApp()));
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SchoolDesk',
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
    return const HomeScreen();
  }
}
