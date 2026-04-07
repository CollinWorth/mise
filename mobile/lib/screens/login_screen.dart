import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  bool _isRegister = false;
  final _nameCtrl = TextEditingController();

  Future<void> _submit() async {
    setState(() { _loading = true; _error = ''; });
    try {
      if (_isRegister) {
        final r = await Api.post('/users/', {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
        });
        if (r.statusCode != 200) {
          setState(() { _error = jsonDecode(r.body)['detail'] ?? 'Registration failed'; });
          return;
        }
      }
      final r = await Api.post('/users/login', {
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        await Api.setSession(data['access_token'], data['user']);
        widget.onLogin();
      } else {
        setState(() { _error = 'Invalid email or password'; });
      }
    } catch (e) {
      setState(() { _error = 'Could not connect to server'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'mise',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: Color(0xFF1A1918),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegister ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                if (_isRegister) ...[
                  _field(_nameCtrl, 'Name', false),
                  const SizedBox(height: 14),
                ],
                _field(_emailCtrl, 'Email', false, type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(_passCtrl, 'Password', true),
                const SizedBox(height: 8),

                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8622A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isRegister ? 'Create account' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
                  child: Text(
                    _isRegister ? 'Already have an account? Sign in' : "Don't have an account? Register",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, bool obscure, {TextInputType? type}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}
