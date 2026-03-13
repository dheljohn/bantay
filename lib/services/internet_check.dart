import 'dart:async';
import 'dart:io';

class InternetService {
  InternetService._privateConstructor();
  static final InternetService instance = InternetService._privateConstructor();

  Future<bool> get hasInternet async {
    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 3), // 👈 timeout inside connect itself
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } on OSError {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<bool> get onStatusChange async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield await hasInternet;
    }
  }
}
