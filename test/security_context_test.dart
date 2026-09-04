@TestOn('vm')
library;

import 'package:connect_kit/src/client/http_client_io.dart';
import 'package:connect_kit/src/client/root_certificates.dart';
import 'package:test/test.dart';

void main() {
  group('securityContextForAddress', () {
    test('pinned SecurityContext for https/wss', () {
      expect(securityContextForAddress(Uri.parse('https://api.example.com')), isNotNull);
      expect(securityContextForAddress(Uri.parse('wss://api.example.com')), isNotNull);
    });

    test('null, for plain h2c, on http and ws', () {
      expect(securityContextForAddress(Uri.parse('http://localhost:8080')), isNull);
      expect(securityContextForAddress(Uri.parse('ws://localhost:8080')), isNull);
    });

    test('the pinned context builds, so every bundled root PEM parses', () {
      // setTrustedCertificatesBytes throws on a malformed PEM, so building validates them.
      expect(rpcSecurityContext, returnsNormally);
    });
  });

  group('RootCertificates.trustedRoots (pinned trust set)', () {
    test('covers Let\'s Encrypt (X1 + X2) and Google Trust Services (R1-R4)', () {
      const roots = RootCertificates.trustedRoots;
      // The pinned set replaces the platform trust store, so every CA a backend can serve has to
      // be present: Let's Encrypt RSA and ECDSA chains, and Google Trust Services.
      expect('-----BEGIN CERTIFICATE-----'.allMatches(roots), hasLength(6));
      for (final pem in const [
        RootCertificates.letsEncrypt,
        RootCertificates.letsEncryptEcdsa,
        RootCertificates.gtsRootR1,
        RootCertificates.gtsRootR2,
        RootCertificates.gtsRootR3,
        RootCertificates.gtsRootR4,
      ]) {
        expect(roots, contains(pem));
        expect(pem, endsWith('-----END CERTIFICATE-----'));
      }
    });
  });

  group('defaultAcceptCompressions', () {
    test('the VM advertises and decodes gzip responses', () {
      expect(defaultAcceptCompressions.map((c) => c.name), contains('gzip'));
    });
  });
}
