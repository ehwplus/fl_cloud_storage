import 'package:flutter/material.dart';

import 'sign_in_with_google_button_native.dart' if (dart.library.js) 'sign_in_with_google_button_web.dart';

class SignInWithGoogleButtonForWeb extends StatelessWidget {
  const SignInWithGoogleButtonForWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignInWithGoogleButton();
  }
}
