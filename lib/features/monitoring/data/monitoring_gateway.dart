import 'dart:convert';
import 'package:flutter/services.dart';

class MonitoringGateway {
  const MonitoringGateway();
  static const channel = MethodChannel('br.com.zelo/monitoring');
  Future<Map<String, dynamic>> snapshot(String uid) async =>
      jsonDecode(
            (await channel.invokeMethod<String>('snapshot', {'uid': uid}))!,
          )
          as Map<String, dynamic>;
  Future<void> start(String uid, String id, String position) =>
      channel.invokeMethod('start', {
        'uid': uid,
        'sessionId': id,
        'position': position,
      });
  Future<void> stop(String uid) => channel.invokeMethod('stop', {'uid': uid});
  Future<void> detach(String uid) =>
      channel.invokeMethod('detach', {'uid': uid});
  Future<void> changePosition(String uid, String position) =>
      channel.invokeMethod('position', {'uid': uid, 'position': position});
  Future<void> resolve(String uid, String id, String outcome) => channel
      .invokeMethod('resolve', {'uid': uid, 'id': id, 'outcome': outcome});
  Future<void> acknowledge(String uid, List<String> ids) =>
      channel.invokeMethod('ack', {'uid': uid, 'ids': ids});
  Future<void> clear(String uid) => channel.invokeMethod('clear', {'uid': uid});
}
