import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class SignInWithGoogleButton extends StatelessWidget {
  const SignInWithGoogleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return web.renderButton(
      configuration: web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        size: web.GSIButtonSize.large,
        theme: web.GSIButtonTheme.outline,
        text: web.GSIButtonText.continueWith,
        // optional: shape/logoAlignment/locale/minimumWidth …
      ),
    );
  }
}
