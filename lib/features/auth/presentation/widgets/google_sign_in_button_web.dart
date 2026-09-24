// lib/features/auth/presentation/widgets/google_sign_in_button_web.dart
//
// Real implementation, selected by google_sign_in_button.dart's conditional
// export on real web compile targets. Never imported directly — always go
// through google_sign_in_button.dart.
import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) => web_only.renderButton();
}
