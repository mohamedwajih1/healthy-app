import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../chat/chat_list_screen.dart';
import '../../../features/users/ui/requests_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context
        .watch<AuthProvider>();
    final user = authProvider.userModel;
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        ModernProfileHeader(user: user),
        const SizedBox(height: 24),
        const Text(
          'الإعدادات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (user?.role != 'admin')
          SwitchListTile(
            title: const Text("تفعيل وضع أخصائي"),
            value:
                authProvider.userModel?.role ==
                "specialist",
            onChanged: (value) async {
              final authProvider = context
                  .read<AuthProvider>();

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(authProvider.user!.uid)
                  .update({
                    'role': value
                        ? 'specialist'
                        : 'user',
                  });

              await authProvider.updateProfile();

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? "تم تفعيل وضع الأخصائي 👨‍⚕️"
                        : "تم إلغاء وضع الأخصائي 👤",
                  ),
                ),
              );
            },
          ),
        if ((user?.nutritionistId ?? '')
            .isNotEmpty)
          ElevatedButton(
            onPressed: () async {
              final myUserId = context
                  .read<AuthProvider>()
                  .user!
                  .uid;

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(myUserId)
                  .update({
                    'nutritionistId': null,
                  });

              await context
                  .read<AuthProvider>()
                  .updateProfile();

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    "تم إلغاء المتابعة",
                  ),
                ),
              );
            },
            child: const Text(
              "إلغاء متابعة الأخصائي",
            ),
          ),
        const SizedBox(height: 12),
        if (user?.role == 'admin')
          ModernSettingsTile(
            icon: Icons
                .admin_panel_settings_rounded,
            title: 'صلاحيات الأدمن',
            color: Colors.deepPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AdminDashboardScreen(),
                ),
              );
            },
          ),
        Opacity(
          opacity: (user?.role == 'admin')
              ? 0.5
              : 1.0,
          child: ModernSettingsTile(
            icon: Icons.person_rounded,
            title: 'تعديل الملف الشخصي',
            color: Colors.blue,
            onTap: (user?.role == 'admin')
                ? null // Disabled for admin
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          _EditProfileScreen(
                            user: user,
                          ),
                    ),
                  ),
          ),
        ),
        ModernSettingsTile(
          icon: Icons.chat_bubble_rounded,
          title: 'الشات',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const ChatListScreen(),
              ),
            );
          },
        ),
        if (user?.role != 'admin')
          ModernSettingsTile(
            icon: Icons.notifications_rounded,
            title: 'طلبات المتابعة',
            color: Colors.orange,
            onTap: () {
              final userId = context
                  .read<AuthProvider>()
                  .user!
                  .uid;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestsScreen(
                    myUserId: userId,
                  ),
                ),
              );
            },
          ),
        ModernSettingsTile(
          icon: Icons.help_rounded,
          title: 'المساعدة والدعم',
          color: Colors.green,
          onTap: () {},
        ),
        ModernSettingsTile(
          icon: Icons.info_rounded,
          title: 'عن التطبيق',
          color: Colors.purple,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        ModernSettingsTile(
          icon: Icons.logout_rounded,
          title: 'تسجيل الخروج',
          color: Colors.red,
          onTap: () =>
              _showModernLogoutDialog(context),
        ),
      ],
    );
  }

  void _showModernLogoutDialog(
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'هل أنت متأكد من تسجيل الخروج؟',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<AuthProvider>()
                  .signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

class ModernProfileHeader
    extends StatelessWidget {
  final dynamic user;

  const ModernProfileHeader({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary
                .withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    0.1,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary,
              child: Text(
                user?.name
                        .substring(0, 1)
                        .toUpperCase() ??
                    'U',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'مستخدم',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  final dynamic user;

  const _EditProfileScreen({required this.user});

  @override
  State<_EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user?.name ?? '',
    );
    _emailController = TextEditingController(
      text: widget.user?.email ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary,
                child: Text(
                  widget.user?.name
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: const Icon(
                    Icons.person,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: const Icon(
                    Icons.email,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لا يمكن تغيير البريد الإلكتروني',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(
                                color:
                                    Colors.white,
                                strokeWidth: 2,
                              ),
                        )
                      : const Text(
                          'حفظ التغييرات',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = widget.user?.id;
      final newName = _nameController.text.trim();

      if (userId != null) {
        // Check if username already exists for another user
        final existingUser =
            await FirebaseFirestore.instance
                .collection('users')
                .where('name', isEqualTo: newName)
                .where(
                  FieldPath.documentId,
                  isNotEqualTo: userId,
                )
                .get();

        if (existingUser.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              const SnackBar(
                content: Text(
                  'هذا الاسم مستخدم بالفعل، اختر اسما آخر',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        // Check if email already exists for another user
        final existingEmail =
            await FirebaseFirestore.instance
                .collection('users')
                .where(
                  'email',
                  isEqualTo: _emailController.text
                      .trim(),
                )
                .where(
                  FieldPath.documentId,
                  isNotEqualTo: userId,
                )
                .get();

        if (existingEmail.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              const SnackBar(
                content: Text(
                  'هذا البريد مستخدم بالفعل',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
              'name': newName,
              'updatedAt':
                  FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'تم حفظ التغييرات بنجاح',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class ModernSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  const ModernSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }
}
