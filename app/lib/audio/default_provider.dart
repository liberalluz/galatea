// Platform switch for the default audio provider (ADR-0002, ADR-0004):
// the Web build uses the browser's speech synthesis; everywhere else the
// unsupported stub reports failures through the shared contract until the
// native batch lands.
export 'audio_provider_unsupported.dart'
    if (dart.library.js_interop) 'audio_provider_web_speech.dart';
