import 'package:busha_pay/src/merchant_api.dart';
import 'package:busha_pay/src/sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'busha_pay_test',
      packageName: 'co.example.busha_pay_test',
      version: '0.0.1',
      buildNumber: '1',
      buildSignature: '',
    );
    await BushaPay.init(publicKey: 'pub_test');
  });

  tearDownAll(BushaPay.resetForTesting);

  test('returns username on 200 with data.username present', () async {
    final client = MockClient((req) async {
      expect(req.url.path, '/v1/merchants');
      expect(req.headers['X-BU-PUBLIC-KEY'], 'pub_test');
      return http.Response('{"data":{"username":"Pushup Design Agency"}}', 200);
    });
    final name = await fetchMerchantName('pub_test', client: client);
    expect(name, 'Pushup Design Agency');
  });

  test('returns null on non-2xx', () async {
    final client = MockClient((_) async => http.Response('{"error":"nope"}', 404));
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  });

  test('returns null when body is not JSON', () async {
    final client = MockClient((_) async => http.Response('<html>oops</html>', 200));
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  });

  test('returns null when data.username is missing', () async {
    final client = MockClient((_) async => http.Response('{"data":{"logo":"x.png"}}', 200));
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  });

  test('returns null when data.username is empty string', () async {
    final client = MockClient((_) async => http.Response('{"data":{"username":""}}', 200));
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  });

  test('returns null when data.username is not a string', () async {
    final client = MockClient((_) async => http.Response('{"data":{"username":123}}', 200));
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  });

  test('returns null when data is missing entirely', () async {
    final client = MockClient((_) async => http.Response('{"username":"x"}', 200));
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  });

  test('returns null when the network throws', () async {
    final client = MockClient((_) async => throw Exception('socket exception'));
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  });

  test('returns null when the request times out', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(seconds: 6));
      return http.Response('{"data":{"username":"slow"}}', 200);
    });
    expect(await fetchMerchantName('pub_test', client: client), isNull);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('uses the live platform host by default', () async {
    BushaPay.resetForTesting();
    await BushaPay.init(publicKey: 'pub_live');
    final client = MockClient((req) async {
      expect(req.url.host, 'api.busha.io');
      return http.Response('{"data":{"username":"Live Co"}}', 200);
    });
    expect(await fetchMerchantName('pub_live', client: client), 'Live Co');
  });

  test('uses the sandbox host when env is sandbox', () async {
    BushaPay.resetForTesting();
    await BushaPay.init(publicKey: 'pub_sb', environment: BushaEnvironment.sandbox);
    final client = MockClient((req) async {
      expect(req.url.host, 'api.sandbox.busha.so');
      return http.Response('{"data":{"username":"Sandbox Co"}}', 200);
    });
    expect(await fetchMerchantName('pub_sb', client: client), 'Sandbox Co');
  });
}
