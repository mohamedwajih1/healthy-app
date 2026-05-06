import 'signup_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/custom_button.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController =
      TextEditingController();
  final _passwordController =
      TextEditingController();
  bool _obscurePassword = true;

  String? emailError;
  String? passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Main login handler - validates and authenticates user

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context
        .read<AuthProvider>();

    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!success) {
      final error =
          authProvider.error ??
          "بيانات غير صحيحة";

      setState(() {
        emailError = null;
        passwordError = null;

        if (error.contains('user') ||
            error.contains('email') ||
            error.contains('البريد') ||
            error.contains('مستخدم')) {
          emailError = error;
        } else {
          passwordError = error;
        }
      });
    } else {
      setState(() {
        emailError = null;
        passwordError = null;
      });
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SignupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context
        .watch<AuthProvider>();
    final isLoading =
        authProvider.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color.fromARGB(
        255,
        252,
        252,
        254,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 160,
                  width: 120,
                  child: LottieBuilder.asset(
                    'assets/animations/animation.json',
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 62),

                Text(
                  'مرحباً بك!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 8),

                Text(
                  'ابدأ رحلتك نحو حياة أفضل',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),

                const SizedBox(height: 48),

                CustomTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  hint: 'example@email.com',
                  prefixIcon:
                      Icons.email_outlined,
                  keyboardType:
                      TextInputType.emailAddress,
                  enabled: !isLoading,
                  errorText: emailError, // 🔥
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'من فضلك أدخل البريد الإلكتروني';
                    }
                    if (!value.contains('@') ||
                        !value.contains('.')) {
                      return 'البريد الإلكتروني غير صحيح';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  enabled: !isLoading,
                  errorText: passwordError, // 🔥
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons
                                .visibility_outlined
                          : Icons
                                .visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'من فضلك أدخل كلمة المرور';
                    }
                    if (value.length < 6) {
                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : _showForgotPasswordDialog,
                    child: Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                CustomButton(
                  text: 'تسجيل الدخول',
                  onPressed: isLoading
                      ? null
                      : () => _handleLogin(),
                  isLoading: isLoading,
                  icon: Icons.login,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    const Expanded(
                      child: Divider(),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                      child: Text(
                        'أو',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                CustomButton(
                  text: 'إنشاء حساب جديد',
                  onPressed: _navigateToSignup,
                  isOutlined: true,
                  icon: Icons.person_add,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'سنرسل لك رابط لإعادة تعيين كلمة المرور',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: emailController,
              label: 'البريد الإلكتروني',
              keyboardType:
                  TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text
                  .trim()
                  .isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'من فضلك أدخل البريد الإلكتروني',
                    ),
                  ),
                );
                return;
              }

              final authProvider = context
                  .read<AuthProvider>();
              final success = await authProvider
                  .resetPassword(
                    emailController.text.trim(),
                  );

              if (!context.mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'تم إرسال رابط إعادة التعيين'
                        : authProvider.error ??
                              'حدث خطأ',
                  ),
                  backgroundColor: success
                      ? Colors.green
                      : Colors.red,
                ),
              );
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }
}
