import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_mark.dart';
import '../home_screen.dart';

/// Đăng nhập + Đăng ký GỘP MỘT MÀN (UI v2): toggle đổi tiêu đề/nút/field Họ tên,
/// không còn push sang màn Register riêng.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegister = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = _isRegister
        ? await auth.register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          )
        : await auth.login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ??
              (_isRegister ? 'Đăng ký thất bại' : 'Đăng nhập thất bại')),
        ),
      );
    }
  }

  Future<void> _continueAsGuest() async {
    await context.read<AuthProvider>().continueAsGuest();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg,
              30,
              AppTheme.spaceLg,
              AppTheme.spaceMd,
            ),
            children: [
              const BrandMark(),
              const SizedBox(height: 44),
              Text(
                _isRegister
                    ? 'Tạo không gian\nhọc của riêng bạn.'
                    : 'Chào mừng\nquay trở lại.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                _isRegister
                    ? 'Lưu lại từ mới, luyện nói và theo dõi tiến bộ mỗi ngày.'
                    : 'Tiếp tục hành trình học ngôn ngữ của bạn, từng câu một.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.moss.withValues(alpha: .66),
                    ),
              ),
              const SizedBox(height: 30),
              if (_isRegister) ...[
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  if (!value.contains('@')) return 'Email chưa đúng định dạng';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => auth.isLoading ? null : _submit(),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  helperText: _isRegister ? 'Tối thiểu 6 ký tự' : null,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu';
                  }
                  if (_isRegister && value.length < 6) {
                    return 'Mật khẩu tối thiểu 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 19,
                        width: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.ivory,
                        ),
                      )
                    : Text(_isRegister ? 'Bắt đầu học' : 'Đăng nhập'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: auth.isLoading ? null : _continueAsGuest,
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Dùng với tư cách khách'),
              ),
              const SizedBox(height: 6),
              Text(
                'Không cần tài khoản hay mạng: dịch offline, lưu từ vựng và lịch sử ngay trên máy. '
                'Đăng nhập sau để đồng bộ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.moss.withValues(alpha: .55),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isRegister ? 'Đã có tài khoản?' : 'Chưa có tài khoản?',
                    style:
                        TextStyle(color: AppTheme.moss.withValues(alpha: .65)),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? 'Đăng nhập' : 'Đăng ký ngay'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Dịch • Luyện tập • Ghi nhớ',
                  style: TextStyle(
                    color: AppTheme.moss.withValues(alpha: .42),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
