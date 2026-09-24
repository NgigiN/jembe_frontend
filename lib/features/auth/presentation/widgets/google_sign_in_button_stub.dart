// lib/features/auth/presentation/widgets/google_sign_in_button_stub.dart
//
// No-op fallback, selected everywhere dart:js_interop isn't available
// (mobile flutter analyze's parse pass, flutter test's VM platform). Never
// actually reached at runtime outside a VM test — WebSignInPage is only
// ever reached from lib/main_web.dart, a real web compile target.
import 'package:flutter/widgets.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
