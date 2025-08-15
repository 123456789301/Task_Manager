import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'employee';
  bool _isSignup = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isSignup) {
        await AuthService.signup(_email.text.trim(), _password.text, _name.text.trim(), _phone.text.trim(), _role);
      } else {
        await AuthService.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TaskFlow Login/Signup')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                if (_isSignup) ...[
                  const SizedBox(height: 8),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name')),
                  const SizedBox(height: 8),
                  TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (E.164, e.g., +91...)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField(
                    value: _role,
                    items: const [
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'employee'),
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_isSignup ? 'Sign up' : 'Login'),
                ),
                TextButton(
                  onPressed: () => setState(() => _isSignup = !_isSignup),
                  child: Text(_isSignup ? 'Have an account? Login' : 'No account? Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
