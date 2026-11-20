### Added
- Pronunciation button in the detail audio zone: play goes through the ADR-0002 audio service interface; the browser synthesizes the phoneme audio via Web Speech (`REQ-006`)
- The button exposes the four fixed states loading / ready / playing / failed (`TC-DETAIL-001`); on failure it shows the fixed `audio-failed` copy and tapping it retries playback
- Audio failure stays inside the audio zone; the other detail sections and the switcher keep working
- Speakable text per phoneme in the catalog (`tts` field, 48 entries): English approximations so the TTS engines can read what the phonetic glyphs cannot express
- Switching phonemes stops playback and resets the button to the ready state
