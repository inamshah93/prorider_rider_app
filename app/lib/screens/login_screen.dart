import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velo_core/velo_core.dart';

import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController(text: '03009876543');
  final _password = TextEditingController(text: 'password');
  bool _loading = false;
  String? _errorMessage;
  String? _errorDetail;
  Map<String, List<String>> _fieldErrors = {};

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage == null && _fieldErrors.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _errorDetail = null;
      _fieldErrors = {};
    });
  }

  Future<void> _submit() async {
    _clearError();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref.read(authRepoProvider).login(_phone.text.trim(), _password.text, app: 'rider');
      ref.invalidate(authStateProvider);
      ref.invalidate(riderProfileProvider);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.displayMessage;
        _errorDetail = e.detail;
        _fieldErrors = e.fieldErrors;
      });
      _formKey.currentState?.validate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
        _errorDetail = e.runtimeType.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _phoneValidator(String? value) {
    final base = FormValidators.phone(value);
    if (base != null) return base;
    final phoneErrors = _fieldErrors['phone'];
    if (phoneErrors != null && phoneErrors.isNotEmpty) return phoneErrors.first;
    return null;
  }

  String? _passwordValidator(String? value) {
    final base = FormValidators.required(value, field: 'Password');
    if (base != null) return base;
    final passwordErrors = _fieldErrors['password'];
    if (passwordErrors != null && passwordErrors.isNotEmpty) return passwordErrors.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const ProRiderLogo(size: 72),
                const SizedBox(height: 16),
                Text(
                  'ProRider Rider',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                ),
                const Text('Last-mile delivery partner app'),
                const SizedBox(height: 32),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: colors.error, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: colors.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_errorDetail != null && _errorDetail!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorDetail!,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _clearError(),
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '03009876543',
                  ),
                  validator: _phoneValidator,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  onChanged: (_) => _clearError(),
                  validator: _passwordValidator,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'Signing in…' : 'Sign in'),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Text(
                    'API: $kApiBaseUrl',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
