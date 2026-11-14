import 'dart:io';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'edition.dart';
import 'local_server.dart';
import 'demo_home.dart';
import 'role_screen.dart';
import 'screens.dart';
import 'shell.dart';
import 'startup_log.dart';
import 'theme.dart';
import 'vault.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    logStartup(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logStartup(error, stack);
    return true;
  };
  ErrorWidget.builder = (details) {
    logStartup(details.exception, details.stack);
    return StartupProblem(message: 'Something went wrong while drawing this screen.', onRetry: () {});
  };
  runApp(const StartupApp());
}

class StartupApp extends StatefulWidget {
  const StartupApp({super.key});

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  AppModel? model;
  String? problem;
  bool starting = true;

  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    setState(() { starting = true; problem = null; });
    try {
      if (demoEdition) {
        final next = AppModel(Vault());
        await next.bootDemo();
        if (mounted) setState(() { model = next; starting = false; problem = null; });
        return;
      }
      var server = await startBundledServer();
      if (server == LocalServer.notReady) {
        await Future<void>.delayed(const Duration(seconds: 2));
        server = await startBundledServer();
      }
      final next = AppModel(Vault());
      await next.boot();
      if (demoEdition && server == LocalServer.ready) {
        await next.setBase('http://127.0.0.1:$localPort');
        if (Platform.environment['SCHOOLDESK_SMOKE'] == 'admin') {
          await next.signIn('admin', 'admin1850');
        }
      } else if (server == LocalServer.ready && (next.base == null || next.base!.isEmpty)) {
        final skip = await next.vault.read('skip_local');
        if (skip != '1') await next.setBase('http://127.0.0.1:$localPort');
      }
      if (demoEdition && (server != LocalServer.ready || !next.licensed)) {
        setState(() {
          starting = false;
          model = null;
          problem = 'The demo school is still starting. It does not need an unlock code.';
        });
        return;
      }
      setState(() { model = next; starting = false; problem = null; });
    } catch (error, stack) {
      await logStartup(error, stack);
      if (mounted) setState(() { starting = false; problem = 'SchoolDesk could not open. The details are in the startup log.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (problem != null && model == null) {
      return MaterialApp(theme: schoolTheme(), home: StartupProblem(message: problem!, onRetry: boot));
    }
    if (starting || model == null) {
      return MaterialApp(theme: schoolTheme(), home: const StartingScreen());
    }
    if (problem != null) {
      return MaterialApp(theme: schoolTheme(), home: StartupProblem(message: problem!, onRetry: boot));
    }
    return ChangeNotifierProvider.value(value: model!, child: const SchoolApp());
  }
}

class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SchoolScaffold(
      title: 'Starting…',
      hint: 'The school program on this computer is opening.',
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class StartupProblem extends StatelessWidget {
  const StartupProblem({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Could not open',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: failRed, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      ),
    );
  }
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
    if (demoEdition) {
      if (model.user.isEmpty) return const ChooseRoleScreen();
      return DeskHost(home: const DemoHome(), pages: rolePages);
    }
    if (model.base == null) return const ConnectScreen();
    if (!model.licensed) return const LockScreen();
    if (model.token == null || model.token!.isEmpty || model.user.isEmpty) return const LoginScreen();
    return DeskHost(home: const HomeScreen(), pages: rolePages);
  }
}
