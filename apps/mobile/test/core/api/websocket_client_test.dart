import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/api/websocket_client.dart';

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  test('WebSocketClient creates with baseUrl', () {
    final client = WebSocketClient(baseUrl: 'http://localhost:3000');
    expect(client, isNotNull);
    client.dispose();
  });

  test('events stream is broadcast stream', () {
    final client = WebSocketClient(baseUrl: 'http://localhost:3000');
    expect(client.events.isBroadcast, true);
    client.dispose();
  });

  test('dispose closes without error', () {
    final client = WebSocketClient(baseUrl: 'http://localhost:3000');
    expect(() => client.dispose(), returnsNormally);
  });

  test('disconnect without connect does not throw', () {
    final client = WebSocketClient(baseUrl: 'http://localhost:3000');
    expect(() { client.disconnect(); client.dispose(); }, returnsNormally);
  });
}
