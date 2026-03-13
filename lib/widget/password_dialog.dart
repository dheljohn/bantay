import 'package:flutter/material.dart';

class PasswordDialog {
  static Future<bool> show(
    BuildContext context, {
    required String correctPassword,
  }) async {
    String input = '';
    bool isWrong = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  title: const Text('Enter Password to stop'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        obscureText: true,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          counterText: '',
                          errorText: isWrong ? "Wrong password" : null,
                        ),
                        onChanged: (value) => input = value,
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        if (input == correctPassword) {
                          Navigator.pop(context, true);
                        } else {
                          setStateDialog(() => isWrong = true);
                          input = '';
                        }
                      },
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }
}
