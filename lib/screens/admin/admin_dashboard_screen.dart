import 'package:flutter/material.dart';
import 'package:healty_app/screens/admin/statistics_screen.dart';
import 'package:healty_app/screens/admin/users_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👑 صلاحيات الأدمن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _item(
            'عرض المستخدمين',
            Icons.people,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UsersManagementScreen(),
                ),
              );
            },
          ),
          _item(
            'إحصائيات التطبيق',
            Icons.bar_chart,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          // _item(
          //   'إعادة تعيين كلمة المرور',
          //   Icons.lock_reset,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _item(String title, IconData icon, {VoidCallback? onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
