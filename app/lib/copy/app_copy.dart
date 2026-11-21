import 'package:flutter/material.dart';

import '../settings/settings_controller.dart';

/// The copy table (`SDD §3.8`, user ruling A, 2026-11-21): every
/// user-facing string of the app resolves by key for the current
/// language — both languages ship complete, and no hardcoded Chinese UI
/// literal remains in a rendered surface. The table is exposed through
/// [CopyScope] above the navigator, so a language switch rebuilds every
/// route immediately.
class AppCopy {
  const AppCopy._({
    required this.tabChart,
    required this.tabMe,
    required this.firstRunHint,
    required this.firstRunDismiss,
    required this.readingHint,
    required this.playbackFailed,
    required this.retry,
    required this.practiceEntry,
    required this.selectConfirm,
    required this.selectBar,
    required this.selectCount,
    required this.cancel,
    required this.vowelHeader,
    required this.consonantHeader,
    required this.reviewLabel,
    required this.masteryTitle,
    required this.meEmptyNotice,
    required this.rowMastered,
    required this.rowLearning,
    required this.rowUnstarted,
    required this.phonemeUnit,
    required this.reviewStrip,
    required this.entryReview,
    required this.entrySettings,
    required this.entryAbout,
    required this.reviewTitle,
    required this.reviewEmpty,
    required this.startReview,
    required this.sessionUnavailable,
    required this.feedbackCorrect,
    required this.feedbackWrong,
    required this.taskPreparing,
    required this.skip,
    required this.submit,
    required this.audioPlay,
    required this.traceFirst,
    required this.penTooltip,
    required this.overlayTitle,
    required this.zoneMouth,
    required this.zoneWriting,
    required this.zoneAudio,
    required this.zoneWords,
    required this.traceHint,
    required this.clear,
    required this.strokePending,
    required this.mouthPending,
    required this.starMastered,
    required this.starLearning,
    required this.starUnstarted,
    required this.starDegraded,
    required this.overlayClear,
    required this.overlayDone,
    required this.settingsTitle,
    required this.languageLabel,
    required this.languageOptionZh,
    required this.languageOptionEn,
    required this.audioLabel,
    required this.audioOffNotice,
    required this.aboutTitle,
    required this.versionLabel,
    required this.sourceTitle,
    required this.sourceContingency,
    required this.isbnLabel,
    required this.ossNote,
    required this.feedbackNote,
    required this.deviceDisclosure,
    required this.dueToday,
    required this.dueInDays,
  });

  /// The zh-CN table (the default).
  const AppCopy.zh()
    : this._(
        tabChart: '音标',
        tabMe: '我',
        firstRunHint: '轻提示：点音标看详情；打开右上角开关可直读发音',
        firstRunDismiss: '知道了',
        readingHint: '直读模式：点按只发音',
        playbackFailed: '播放失败，重试',
        retry: '重试',
        practiceEntry: '练习',
        selectConfirm: '确定',
        selectBar: '请选择',
        selectCount: '已选 1 行',
        cancel: '取消',
        vowelHeader: '元音',
        consonantHeader: '辅音',
        reviewLabel: '复习',
        masteryTitle: '掌握度',
        meEmptyNotice: '开始练习后显示掌握度',
        rowMastered: '已掌握 3★',
        rowLearning: '学习中 1–2★',
        rowUnstarted: '未掌握 0★',
        phonemeUnit: '音位',
        reviewStrip: '待复习',
        entryReview: '复习',
        entrySettings: '设置',
        entryAbout: '关于',
        reviewTitle: '复习',
        reviewEmpty: '今日无到期复习',
        startReview: '开始复习',
        sessionUnavailable: '范围暂不可用',
        feedbackCorrect: '回答正确',
        feedbackWrong: '回答错误',
        taskPreparing: '题目准备中',
        skip: '跳过',
        submit: '确定',
        audioPlay: '播放',
        traceFirst: '请先在区域内描摹',
        penTooltip: '手写练习',
        overlayTitle: '手写练习',
        zoneMouth: '口型区',
        zoneWriting: '书写区',
        zoneAudio: '发音区',
        zoneWords: '例词例句',
        traceHint: '在此描摹',
        clear: '清除',
        strokePending: '笔顺准备中',
        mouthPending: '口型图准备中',
        starMastered: '已掌握',
        starLearning: '学习中',
        starUnstarted: '未掌握',
        starDegraded: '数据待同步',
        overlayClear: '清除重写',
        overlayDone: '完成',
        settingsTitle: '设置',
        languageLabel: '语言',
        languageOptionZh: '中文',
        languageOptionEn: 'English',
        audioLabel: '发音',
        audioOffNotice: '发音已关闭',
        aboutTitle: '关于',
        versionLabel: '版本',
        sourceTitle: '内容来源',
        sourceContingency: '暂以公开对照表为准，待授权数据后替换',
        isbnLabel: 'ISBN',
        ossNote: '开源说明：本应用使用的开源组件在其仓库中列明',
        feedbackNote: '反馈：问题与建议请通过项目仓库提交',
        deviceDisclosure: '数据仅保存在本设备',
        dueToday: '今天',
        dueInDays: '天后',
      );

  /// The en-US mirror: complete, key-for-key with the zh table.
  const AppCopy.en()
    : this._(
        tabChart: 'Phonemes',
        tabMe: 'Me',
        firstRunHint: 'Tip: tap a symbol for details; the top-right switch reads aloud directly',
        firstRunDismiss: 'Got it',
        readingHint: 'Reading mode: taps only play audio',
        playbackFailed: 'Playback failed, retry',
        retry: 'Retry',
        practiceEntry: 'Practice',
        selectConfirm: 'Confirm',
        selectBar: 'Select a row',
        selectCount: '1 row selected',
        cancel: 'Cancel',
        vowelHeader: 'Vowels',
        consonantHeader: 'Consonants',
        reviewLabel: 'Review',
        masteryTitle: 'Mastery',
        meEmptyNotice: 'Start practicing to see mastery',
        rowMastered: 'Mastered 3★',
        rowLearning: 'Learning 1–2★',
        rowUnstarted: 'Not started 0★',
        phonemeUnit: 'phonemes',
        reviewStrip: 'Due for review',
        entryReview: 'Review',
        entrySettings: 'Settings',
        entryAbout: 'About',
        reviewTitle: 'Review',
        reviewEmpty: 'Nothing due for review today',
        startReview: 'Start review',
        sessionUnavailable: 'Range unavailable',
        feedbackCorrect: 'Correct',
        feedbackWrong: 'Incorrect',
        taskPreparing: 'Preparing',
        skip: 'Skip',
        submit: 'Confirm',
        audioPlay: 'Play',
        traceFirst: 'Trace in the area first',
        penTooltip: 'Handwriting',
        overlayTitle: 'Handwriting',
        zoneMouth: 'Mouth',
        zoneWriting: 'Writing',
        zoneAudio: 'Pronunciation',
        zoneWords: 'Examples',
        traceHint: 'Trace here',
        clear: 'Clear',
        strokePending: 'Stroke order pending',
        mouthPending: 'Mouth image pending',
        starMastered: 'Mastered',
        starLearning: 'Learning',
        starUnstarted: 'Not started',
        starDegraded: 'Data pending sync',
        overlayClear: 'Clear and rewrite',
        overlayDone: 'Done',
        settingsTitle: 'Settings',
        languageLabel: 'Language',
        languageOptionZh: '中文',
        languageOptionEn: 'English',
        audioLabel: 'Audio',
        audioOffNotice: 'Audio is off',
        aboutTitle: 'About',
        versionLabel: 'Version',
        sourceTitle: 'Content source',
        sourceContingency: 'Public tables for now, pending licensed data',
        isbnLabel: 'ISBN',
        ossNote: 'Open source: the components this app uses are listed in their repositories',
        feedbackNote: 'Feedback: file issues and suggestions through the project repository',
        deviceDisclosure: 'Your data stays on this device only',
        dueToday: 'Today',
        dueInDays: 'd',
      );

  final String tabChart;
  final String tabMe;
  final String firstRunHint;
  final String firstRunDismiss;
  final String readingHint;
  final String playbackFailed;
  final String retry;
  final String practiceEntry;
  final String selectConfirm;
  final String selectBar;
  final String selectCount;
  final String cancel;
  final String vowelHeader;
  final String consonantHeader;
  final String reviewLabel;
  final String masteryTitle;
  final String meEmptyNotice;
  final String rowMastered;
  final String rowLearning;
  final String rowUnstarted;
  final String phonemeUnit;
  final String reviewStrip;
  final String entryReview;
  final String entrySettings;
  final String entryAbout;
  final String reviewTitle;
  final String reviewEmpty;
  final String startReview;
  final String sessionUnavailable;
  final String feedbackCorrect;
  final String feedbackWrong;
  final String taskPreparing;
  final String skip;
  final String submit;
  final String audioPlay;
  final String traceFirst;
  final String penTooltip;
  final String overlayTitle;
  final String zoneMouth;
  final String zoneWriting;
  final String zoneAudio;
  final String zoneWords;
  final String traceHint;
  final String clear;
  final String strokePending;
  final String mouthPending;
  final String starMastered;
  final String starLearning;
  final String starUnstarted;
  final String starDegraded;
  final String overlayClear;
  final String overlayDone;
  final String settingsTitle;
  final String languageLabel;
  final String languageOptionZh;
  final String languageOptionEn;
  final String audioLabel;
  final String audioOffNotice;
  final String aboutTitle;
  final String versionLabel;
  final String sourceTitle;
  final String sourceContingency;
  final String isbnLabel;
  final String ossNote;
  final String feedbackNote;
  final String deviceDisclosure;
  final String dueToday;
  final String dueInDays;

  /// The due-day label of a queued phoneme: due today shows the today
  /// word, otherwise the whole days until it is due.
  String dueLabel(int days) => days <= 0 ? dueToday : '$days $dueInDays';

  /// The copy for one language.
  static AppCopy ofLanguage(AppLanguage language) => switch (language) {
    AppLanguage.zhCn => const AppCopy.zh(),
    AppLanguage.enUs => const AppCopy.en(),
  };
}

/// The copy scope above the navigator: every route resolves its strings
/// through [of], and a language change rebuilds the scope's child (the
/// whole navigator) so the switch applies immediately.
class CopyScope extends InheritedWidget {
  const CopyScope({super.key, required this.copy, required super.child});

  final AppCopy copy;

  static AppCopy of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CopyScope>()?.copy ??
      const AppCopy.zh();

  @override
  bool updateShouldNotify(CopyScope oldWidget) => oldWidget.copy != copy;
}
