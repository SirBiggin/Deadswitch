import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isSetup;
  final bool isReauth;
  const LoginScreen({super.key, this.isSetup = false, this.isReauth = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) { setState(() => _error = 'PIN must be at least 4 digits'); return; }

    if (widget.isSetup) {
      if (pin != _confirmCtrl.text.trim()) { setState(() => _error = 'PINs do not match'); return; }
      await SettingsService.setPin(pin);
    } else {
      final stored = await SettingsService.pin;
      if (pin != stored) { setState(() => _error = 'Incorrect PIN'); return; }
    }
    if (!mounted) return;
    if (widget.isReauth) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isReauth,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('☠', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              Text(widget.isSetup ? 'Create PIN' : 'DeadSwitch',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              if (widget.isReauth) ...[
                const SizedBox(height: 8),
                const Text('Enter PIN to unlock',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                autofocus: widget.isReauth,
                decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
              ),
              if (widget.isSetup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFc87e7e))),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563eb),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(widget.isSetup ? 'Create PIN' : 'Unlock',
                      style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
