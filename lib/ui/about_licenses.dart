import 'package:flutter/foundation.dart';

/// Registers the licenses that aren't Dart packages, so they show up on
/// Flutter's license page ("Összes licenc") next to the packages'.
void registerExtraLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['espeak-ng'],
      'espeak-ng (text to phonemes, used by sherpa-onnx) is licensed under '
      'the GNU General Public License v3.0 or later.\n'
      'Full text: https://www.gnu.org/licenses/gpl-3.0.txt\n'
      'Source: https://github.com/espeak-ng/espeak-ng',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Piper'],
      "Piper (the voice models' format and training tools) is licensed "
      'under the MIT License.\n'
      'Source: https://github.com/rhasspy/piper\n\n'
      'Permission is hereby granted, free of charge, to any person obtaining '
      'a copy of this software and associated documentation files (the '
      '"Software"), to deal in the Software without restriction, including '
      'without limitation the rights to use, copy, modify, merge, publish, '
      'distribute, sublicense, and/or sell copies of the Software, and to '
      'permit persons to whom the Software is furnished to do so, subject to '
      'the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be '
      'included in all copies or substantial portions of the Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, '
      'EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
      'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND '
      'NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS '
      'BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN '
      'ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN '
      'CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
      'SOFTWARE.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Voice models: MIT (Imre, Berta)'],
      'The Hungarian voices Imre and Berta are licensed under the MIT '
      'License (see the Piper entry for the text).\n'
      'Model cards: https://huggingface.co/rhasspy/piper-voices',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Voice models: CC0 (Anna, NST)'],
      'The voices Anna (Hungarian) and NST (Swedish) are released under '
      'CC0 1.0 (public domain dedication).\n'
      'https://creativecommons.org/publicdomain/zero/1.0/',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Voice model: CC BY 4.0 (Alma)'],
      'The voice Alma (Swedish) is trained on the NST Swedish TTS dataset '
      '(Språkbanken, National Library of Norway) and released under the '
      'Creative Commons Attribution 4.0 International license.\n'
      'Model card: https://huggingface.co/rhasspy/piper-voices/blob/main/sv/'
      'sv_SE/alma/medium/MODEL_CARD\n'
      'https://creativecommons.org/licenses/by/4.0/',
    );
  });
}
