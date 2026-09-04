// Portability guard: web is a target, so `lib/` never imports `dart:io`, `dart:ui` or
// `dart:html` directly. Platform code sits behind the conditional imports in
// `client/transport.dart`; the `_io.dart` leaves are the exception, reachable only through one
// and needing `dart:io` for the pinned SecurityContext.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('lib stays platform-agnostic: no dart:io, dart:ui or dart:html', () {
    final banned = RegExp(r'''import\s+['"]dart:(io|ui|html)['"]''');
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('_io.dart')) continue; // the conditional-import leaf, see above
      for (final (index, line) in entity.readAsLinesSync().indexed) {
        if (banned.hasMatch(line)) offenders.add('${entity.path}:${index + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'lib must stay platform-agnostic (web target). Offending imports:\n${offenders.join('\n')}',
    );
  });
}
