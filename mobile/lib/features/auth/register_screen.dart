import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';
import '../../widgets/app_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();

  UserRole _role = UserRole.student;
  AppLanguage _language = AppLanguage.english;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authControllerProvider.notifier)
        .register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          passwordConfirm: _passwordConfirm.text,
          role: _role,
          preferredLanguage: _language,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isSubmitting;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to sign in',
          onPressed: busy
              ? null
              : () {
                  ref.read(authControllerProvider.notifier).clearError();
                  context.goNamed(AppRoutes.loginName);
                },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create your account',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Start listening and speaking today.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (auth.errorMessage != null) ...[
                      AppErrorBanner(message: auth.errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    AppTextField(
                      label: 'Name',
                      controller: _name,
                      hint: 'Amir',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      enabled: !busy,
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true)
                          ? 'Please enter a name.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      enabled: !busy,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Please enter an email.';
                        if (!text.contains('@')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      enabled: !busy,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please choose a password.';
                        }
                        if (value.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                      trailing: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Confirm password',
                      controller: _passwordConfirm,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !busy,
                      onSubmitted: (_) => busy ? null : _submit(),
                      validator: (value) {
                        if (value != _password.text) {
                          return 'The two passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    _RoleSelector(
                      value: _role,
                      enabled: !busy,
                      onChanged: (role) => setState(() => _role = role),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    _LanguageSelector(
                      value: _language,
                      enabled: !busy,
                      onChanged: (language) =>
                          setState(() => _language = language),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const Text('Creating account...')
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearError();
                              context.goNamed(AppRoutes.loginName);
                            },
                      child: const Text('Already have an account? Sign in'),
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

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final UserRole value;
  final ValueChanged<UserRole> onChanged;
  final bool enabled;

  static const _labels = {
    UserRole.student: 'Student',
    UserRole.parent: 'Parent',
    UserRole.teacher: 'Teacher',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am a',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<UserRole>(
          segments: [
            for (final entry in _labels.entries)
              ButtonSegment(value: entry.key, label: Text(entry.value)),
          ],
          selected: {value},
          onSelectionChanged: enabled
              ? (selection) => onChanged(selection.first)
              : null,
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language to practise',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<AppLanguage>(
          segments: [
            for (final language in AppLanguage.values)
              ButtonSegment(value: language, label: Text(language.label)),
          ],
          selected: {value},
          onSelectionChanged: enabled
              ? (selection) => onChanged(selection.first)
              : null,
          showSelectedIcon: false,
        ),
      ],
    );
  }
}
