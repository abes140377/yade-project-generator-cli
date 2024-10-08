import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason/mason.dart' hide packageVersion;
import 'package:pub_updater/pub_updater.dart';
import 'package:yade_cli/src/commands/commands.dart';
import 'package:yade_cli/src/version.dart';

/// Typedef for [io.exit].
typedef Exit = dynamic Function(int exitCode);

/// The package name.
const packageName = 'yade_cli';

/// The executable name.
const executableName = 'yade';

/// The executable description.
const executableDescription =
    'The YADE - Yet Another Development Environment CLI.';

/// {@template yade_command_runner}
/// A [CommandRunner] for the YADE CLI.
/// {@endtemplate}
class YadeCommandRunner extends CompletionCommandRunner<int> {
  /// {@macro yade_command_runner}
  YadeCommandRunner({
    Logger? logger,
    PubUpdater? pubUpdater,
    io.ProcessSignal? sigint,
    Exit? exit,
    io.Stdin? stdin,
  })  : _logger = logger ?? Logger(),
        _pubUpdater = pubUpdater ?? PubUpdater(),
        _sigint = sigint ?? io.ProcessSignal.sigint,
        _exit = exit ?? io.exit,
        stdin = stdin ?? io.stdin,
        super(executableName, executableDescription) {
    argParser.addFlags();
    addCommand(CreateCommand(logger: _logger));
    addCommand(UpdateCommand(logger: _logger));
  }

  final Logger _logger;
  final PubUpdater _pubUpdater;
  final io.ProcessSignal _sigint;
  final Exit _exit;

  /// The [io.Stdin] instance to be used by the commands.
  final io.Stdin stdin;

  @override
  Future<int> run(Iterable<String> args) async {
    late final ArgResults argResults;
    try {
      argResults = parse(args);
    } on UsageException catch (error) {
      _logger.err('$error');
      return ExitCode.usage.code;
    }

    _sigint.watch().listen(_onSigint);

    late final int exitCode;
    try {
      _logger.info(getAsciiArtContent());
      exitCode = await runCommand(argResults) ?? ExitCode.success.code;
      _logger.info('');
    } catch (error) {
      _logger.err('$error');
      exitCode = ExitCode.software.code;
    }

    if (argResults.command?.name != 'update' &&
        argResults.command?.name != 'completion') {
      await _checkForUpdates();
    }

    return exitCode;
  }

  ///
  String getAsciiArtContent() {
    return r'''
__  _____    ____  ______   ________    ____
\ \/ /   |  / __ \/ ____/  / ____/ /   /  _/
 \  / /| | / / / / __/    / /   / /    / /  
 / / ___ |/ /_/ / /___   / /___/ /____/ /   
/_/_/  |_/_____/_____/   \____/_____/___/   
Yet Another Development Environment CLI
  ''';
  }

  Future<void> _onSigint(io.ProcessSignal signal) async {
    await _checkForUpdates();
    _exit(0);
  }

  Future<void> _checkForUpdates() async {
    _logger.detail('[updater] checking for updates...');
    try {
      final latestVersion = await _pubUpdater.getLatestVersion(packageName);
      _logger.detail('[updater] latest version is $latestVersion.');

      final isUpToDate = packageVersion == latestVersion;
      if (isUpToDate) {
        _logger.detail('[updater] no updates available.');
        return;
      }

      if (!isUpToDate) {
        _logger.detail('[updater] update available.');
        final changelogLink = lightCyan.wrap(
          styleUnderlined.wrap(
            link(
              uri: Uri.parse(
                'https://github.com/verygoodopensource/yade/releases/tag/yade_cli-v$latestVersion',
              ),
            ),
          ),
        );
        _logger
          ..info('')
          ..info(
            '''
${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
${lightYellow.wrap('Changelog:')} $changelogLink
Run ${lightCyan.wrap('$executableName update')} to update''',
          );
      }
    } catch (error, stackTrace) {
      _logger.detail(
        '[updater] update check error.\n$error\n$stackTrace',
      );
    } finally {
      _logger.detail('[updater] update check complete.');
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }
    if (topLevelResults['version'] == true) {
      _logger.info(packageVersion);
      return ExitCode.success.code;
    }
    if (topLevelResults['verbose'] == true) {
      _logger.level = Level.verbose;
    }

    _logger.detail('[meta] $packageName $packageVersion');
    return super.runCommand(topLevelResults);
  }
}

extension on ArgParser {
  void addFlags() {
    addFlag(
      'version',
      negatable: false,
      help: 'Print the current version.',
    );
    addFlag(
      'verbose',
      negatable: false,
      help: 'Output additional logs.',
    );
  }
}
