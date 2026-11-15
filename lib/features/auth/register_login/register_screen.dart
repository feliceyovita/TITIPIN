
import 'package:flutter/material.dart';
import 'package:titipin/core/theme/app_theme.dart';
import '../widgets/widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan setujui Syarat dan Ketentuan terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data registrasi berhasil divalidasi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  AuthWidgets.header(),
                  const SizedBox(height: 19),

                  AuthWidgets.card(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 21,
                      vertical: 20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Buat akun baru untuk memulai perjalanan di Titipin!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 17),

                          AuthWidgets.label('Nama Lengkap'),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 12),
                            decoration: AuthWidgets.input(
                              hint: 'Masukkan nama lengkap',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama lengkap harus diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          AuthWidgets.label('Email'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 12),
                            decoration: AuthWidgets.input(
                              hint: 'email@gmail.com',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email harus diisi';
                              }
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return 'Masukkan email yang valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          AuthWidgets.label('No Handphone'),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 12),
                            decoration: AuthWidgets.input(
                              hint: '08xxxxxxxxxx',
                              icon: Icons.phone_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nomor handphone harus diisi';
                              }
                              if (value.trim().length < 10) {
                                return 'Nomor handphone tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          AuthWidgets.label('Password'),
                          AuthWidgets.passwordField(
                            controller: _passwordController,
                            obscure: _obscurePassword,
                            onToggle: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            hint: 'Masukkan password Anda',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password harus diisi';
                              }
                              if (value.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          AuthWidgets.label('Konfirmasi Password'),
                          AuthWidgets.passwordField(
                            controller: _confirmPasswordController,
                            obscure: _obscureConfirmPassword,
                            onToggle: () {
                              setState(() {
                                _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                              });
                            },
                            hint: 'Konfirmasi Password',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Konfirmasi password harus diisi';
                              }
                              if (value != _passwordController.text) {
                                return 'Password tidak sama';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 13),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 25,
                                height: 25,
                                child: Checkbox(
                                  value: _acceptedTerms,
                                  activeColor: AppColors.primary,
                                  onChanged: (value) {
                                    setState(() {
                                      _acceptedTerms = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textPrimary,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Saya setuju dengan ',
                                        ),
                                        const TextSpan(
                                          text: 'Syarat dan Ketentuan',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                            TextDecoration.underline,
                                          ),
                                        ),
                                        const TextSpan(text: ' serta '),
                                        const TextSpan(
                                          text: 'Kebijakan Privasi',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                            TextDecoration.underline,
                                          ),
                                        ),
                                        const TextSpan(text: ' Titipin.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          AuthWidgets.primaryButton(
                            text: 'Daftar',
                            onPressed: _register,
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Sudah punya akun? ',
                                style: TextStyle(fontSize: 11),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}
