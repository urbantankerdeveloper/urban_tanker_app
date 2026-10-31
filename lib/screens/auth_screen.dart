import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/page_components.dart';
import '../app/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _credential = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _signup = false;
  bool _resetPassword = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _credential.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_resetPassword) {
      await widget.controller.requestPasswordReset(_credential.text.trim());
    } else if (_signup) {
      await widget.controller.signUp(
        email: _credential.text,
        password: _password.text,
        name: _name.text,
        phone: _phone.text,
      );
    } else {
      await widget.controller.signIn(_credential.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppPageInsets.standard,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('URBAN TANKER',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: aqua,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w800,
                                )),
                    const SizedBox(height: 18),
                    Text(
                      _signup
                          ? 'Start with reliable water.'
                          : _resetPassword
                              ? 'Reset your password.'
                              : 'Water, organised.',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(_signup
                        ? 'Create a customer account to book and track deliveries.'
                        : _resetPassword
                            ? 'We will email reset instructions if the account exists.'
                            : 'Sign in to your role workspace and keep every delivery moving.'),
                    const SizedBox(height: 28),
                    if (_signup) ...[
                      TextFormField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                                ? 'Enter your name.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: '10-digit mobile'),
                        validator: (value) => value == null ||
                                !RegExp(r'^\d{10}$').hasMatch(value)
                            ? 'Enter a valid 10-digit mobile number.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _credential,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _signup || _resetPassword
                            ? 'Email'
                            : 'Email or username',
                      ),
                      validator: (value) {
                        final credential = value?.trim() ?? '';
                        if (credential.isEmpty) {
                          return _signup || _resetPassword
                              ? 'Enter your email address.'
                              : 'Enter your email or username.';
                        }
                        if (_resetPassword &&
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(credential)) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    if (!_resetPassword) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                        ),
                        validator: _signup
                            ? (value) => value == null || value.length < 8
                                ? 'Use at least 8 characters.'
                                : null
                            : null,
                      ),
                    ],
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          AppStateView.isNetworkError(
                            controller.errorMessage!,
                          )
                              ? 'No network connection. Check your internet connection and try again.'
                              : controller.errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    if (controller.successMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        controller.successMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: controller.busy ? null : _submit,
                      child: controller.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_signup
                              ? 'Create account'
                              : _resetPassword
                                  ? 'Send reset instructions'
                                  : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: controller.busy
                          ? null
                          : () => setState(() {
                                if (_signup || _resetPassword) {
                                  _signup = false;
                                  _resetPassword = false;
                                } else {
                                  _signup = true;
                                }
                                controller.clearError();
                              }),
                      child: Text(_signup || _resetPassword
                          ? 'Back to sign in'
                          : 'New here? Create a customer account'),
                    ),
                    if (!_signup && !_resetPassword)
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => setState(() {
                                  _resetPassword = true;
                                  controller.clearError();
                                }),
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
