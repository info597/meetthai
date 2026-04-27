import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _supa = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;

  AppStrings get _t => AppStrings.of(context);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<bool> _isDeletedUser(String userId) async {
    try {
      final row = await _supa
          .from('profiles')
          .select('is_deleted')
          .eq('user_id', userId)
          .maybeSingle();

      return row?['is_deleted'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    setState(() => _loading = true);

    try {
      AuthResponse res;

      if (_isLogin) {
        res = await _supa.auth.signInWithPassword(
          email: email,
          password: pass,
        );
      } else {
        res = await _supa.auth.signUp(
          email: email,
          password: pass,
        );
      }

      if (!mounted) return;

      final user = res.user ?? _supa.auth.currentUser;
      if (user == null) {
        _snack(_t.errorLoginNoUser);
        return;
      }

      final isDeleted = await _isDeletedUser(user.id);
      if (isDeleted) {
        await _supa.auth.signOut();
        if (!mounted) return;
        _snack('Dieser Account wurde deaktiviert.');
        return;
      }

      await SupabaseService.instance.ensureProfileExists();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      final msg = e.message.toLowerCase();

      if (msg.contains('email not confirmed') ||
          msg.contains('not confirmed')) {
        _snack(_t.emailNotConfirmed);
        return;
      }

      _snack('${_t.authError}: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _snack('${_t.error}: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? _t.login : _t.register;
    final subtitle = _isLogin ? _t.loginSubtitle : _t.registerSubtitle;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        const Icon(
                          Icons.favorite_rounded,
                          size: 56,
                          color: Color(0xFFE91E63),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t.appName,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(
                                    labelText: _t.email,
                                    prefixIcon: const Icon(Icons.mail_outline),
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) {
                                      return _t.enterEmail;
                                    }
                                    if (!s.contains('@')) {
                                      return _t.invalidEmail;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: _t.password,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() => _obscure = !_obscure);
                                      },
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = v ?? '';
                                    if (s.isEmpty) {
                                      return _t.enterPassword;
                                    }
                                    if (s.length < 6) {
                                      return _t.passwordTooShort;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _submit,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(title),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          setState(() => _isLogin = !_isLogin);
                                        },
                                  child: Text(
                                    _isLogin ? _t.noAccount : _t.haveAccount,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _t.loginScreenActive,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}