import 'package:flutter/material.dart';

import '../../copy/app_copy.dart';
import '../../settings/settings_controller.dart';

/// The settings page (`SDD §3.8`, wireframe P7): the language switch
/// with zh-CN as the default — a switch re-renders the whole navigator
/// on the same frame through the copy scope — and the audio toggle; the
/// choice persists through the settings controller's store.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.controller});

  /// Injectable controller for unit harnesses; production resolves the
  /// shell-owned one from the settings scope.
  final SettingsController? controller;

  @override
  Widget build(BuildContext context) {
    final copy = CopyScope.of(context);
    final settings = controller ?? SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(copy.settingsTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            key: const ValueKey('settings-page'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                copy.languageLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<AppLanguage>(
                key: const ValueKey('language-switch'),
                segments: [
                  ButtonSegment<AppLanguage>(
                    value: AppLanguage.zhCn,
                    label: Text(
                      copy.languageOptionZh,
                      key: const ValueKey('language-option-zh'),
                    ),
                  ),
                  ButtonSegment<AppLanguage>(
                    value: AppLanguage.enUs,
                    label: Text(
                      copy.languageOptionEn,
                      key: const ValueKey('language-option-en'),
                    ),
                  ),
                ],
                selected: {settings.language},
                onSelectionChanged: (selection) =>
                    settings.setLanguage(selection.first),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                key: const ValueKey('audio-toggle'),
                title: Text(copy.audioLabel),
                value: settings.audioOn,
                onChanged: settings.setAudioOn,
              ),
            ],
          );
        },
      ),
    );
  }
}
