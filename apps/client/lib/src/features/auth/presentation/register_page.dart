import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../bloc/auth_bloc.dart';

/// Register page with name, email, and password form.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
          AuthRegisterRequested(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VioColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          if (state.status == AuthStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: VioColors.error,
                ),
              );
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo / Title ──────────────────────────
                    const Icon(
                      Icons.auto_awesome_mosaic_rounded,
                      size: 48,
                      color: VioColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vio',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: VioColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your account',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: VioColors.textSecondary),
                    ),
                    const SizedBox(height: 40),

                    // ── Name Field ────────────────────────────
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: VioColors.textPrimary),
                      decoration: _inputDecoration(
                        label: 'Name',
                        hint: 'Your display name',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Email Field ───────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: VioColors.textPrimary),
                      decoration: _inputDecoration(
                        label: 'Email',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Password Field ────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onRegister(),
                      style: const TextStyle(color: VioColors.textPrimary),
                      decoration: _inputDecoration(
                        label: 'Password',
                        hint: 'At least 8 characters',
                        icon: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: VioColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Register Button ───────────────────────
                    BlocBuilder<AuthBloc, AuthState>(
                      buildWhen: (prev, curr) => prev.status != curr.status,
                      builder: (context, state) {
                        final isLoading = state.status == AuthStatus.loading;
                        return SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _onRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VioColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  VioColors.primary.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Create Account'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Login Link ────────────────────────────
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            color: VioColors.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(color: VioColors.primary),
                            ),
                          ],
                        ),
                      ),
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

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return buildAuthInputDecoration(
      label: label,
      hint: hint,
      icon: icon,
    );
  }
}

InputDecoration buildAuthInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: VioColors.textSecondary, size: 20),
    labelStyle: const TextStyle(color: VioColors.textSecondary),
    hintStyle: const TextStyle(color: VioColors.textTertiary),
    filled: true,
    fillColor: VioColors.surfaceElevated,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: VioColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: VioColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: VioColors.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: VioColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: VioColors.error),
    ),
  );
}
