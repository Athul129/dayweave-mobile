import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../application/auth_controller.dart';
import 'auth_error.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  String? _error;
  bool _confirmationSent = false;

  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      final response = _signup
          ? await controller.signUp(email: _email.text.trim(), password: _password.text, displayName: _name.text.trim())
          : await controller.signIn(email: _email.text.trim(), password: _password.text);
      if (mounted && _signup && response.session == null) setState(() => _confirmationSent = true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error, signingIn: !_signup));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  String? _required(String? value, String label) => value == null || value.trim().isEmpty ? '$label is required.' : null;
  String? _emailValidator(String? value) {
    final required = _required(value, 'Email');
    if (required != null) return required;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim()) ? null : 'Enter a valid email address.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(DayweaveSpacing.xl), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: _confirmationSent ? _confirmation(theme) : _form(theme))))));
  }

  Widget _header(ThemeData theme) => Column(children: [Image.asset('assets/images/dayweave-mark.webp', width: 72, height: 72), const SizedBox(height: 18), Text('dayweave', style: theme.textTheme.displayMedium), const SizedBox(height: 8), Text(_signup ? 'Make a little room for what matters.' : 'A quieter way to meet the day.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge)]);

  Widget _form(ThemeData theme) => Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _header(theme), const SizedBox(height: 32), Text(_signup ? 'Create your account' : 'Welcome back', style: theme.textTheme.headlineSmall), const SizedBox(height: 20),
    if (_signup) ...[_field(_name, 'Display name', 'How should we call you?', validator: (v) => _required(v, 'Display name')), const SizedBox(height: 14)],
    _field(_email, 'Email', 'you@example.com', keyboard: TextInputType.emailAddress, validator: _emailValidator), const SizedBox(height: 14),
    _field(_password, 'Password', 'Your password', obscure: true, validator: (v) { final e = _required(v, 'Password'); return e ?? (v!.length < 6 ? 'Use at least 6 characters.' : null); }),
    if (_signup) ...[const SizedBox(height: 14), _field(_confirm, 'Confirm password', 'Enter it again', obscure: true, validator: (v) => v != _password.text ? 'Passwords do not match.' : null)],
    if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))), const SizedBox(height: 22),
    FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_signup ? 'Create account' : 'Sign in'))), const SizedBox(height: 14),
    TextButton(onPressed: _busy ? null : () => setState(() { _signup = !_signup; _error = null; }), child: Text(_signup ? 'Already have an account? Sign in' : 'New here? Create an account')),
  ]));

  Widget _field(TextEditingController controller, String label, String hint, {bool obscure = false, TextInputType? keyboard, String? Function(String?)? validator}) => TextFormField(controller: controller, obscureText: obscure, keyboardType: keyboard, textInputAction: TextInputAction.next, validator: validator, decoration: InputDecoration(labelText: label, hintText: hint));
  Widget _confirmation(ThemeData theme) => Column(children: [_header(theme), const SizedBox(height: 32), Text('Check your email', style: theme.textTheme.headlineSmall), const SizedBox(height: 12), const Text('We sent a confirmation link to your email address. Open it, then return to Dayweave to continue.', textAlign: TextAlign.center), const SizedBox(height: 24), OutlinedButton(onPressed: () => setState(() => _confirmationSent = false), child: const Text('Back to sign in'))]);
}
