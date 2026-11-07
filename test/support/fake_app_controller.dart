import 'package:zelo_mobile/core/application/app_controller.dart';

class FakeAppController extends AppController {
  @override
  Future<AppSnapshot> build() async => const AppSnapshot(prepared: true);
  @override
  Future<void> poll() async {}
}
