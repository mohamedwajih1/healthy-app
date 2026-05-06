import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text("📊 إحصائيات التطبيق"),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          int total = users.length;

          int specialists = users.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return (data['role'] ?? '') == 'specialist';
          }).length;

          int admins = users.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return (data['role'] ?? '') == 'admin';
          }).length;

          int banned = users.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return (data['isBanned'] ?? false) == true;
          }).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _card("👥 إجمالي المستخدمين", total, Colors.blue),
                _card("👨‍⚕️ الأخصائيين", specialists, Colors.green),
                _card("👑 الأدمن", admins, Colors.deepPurple),
                _card("🚫 المحظورين", banned, Colors.red),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "📊 توزيع المستخدمين",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          double chartHeight = constraints.maxWidth * 0.65;

                          return SizedBox(
                            height: chartHeight,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (total + 1).toDouble(),

                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  horizontalInterval: 1,
                                  getDrawingHorizontalLine: (value) {
                                    if (value == 0) {
                                      return FlLine(color: Colors.transparent);
                                    }
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.2),
                                      strokeWidth: 1,
                                      dashArray: [6, 4],
                                    );
                                  },
                                  getDrawingVerticalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.1),
                                      strokeWidth: 1,
                                      dashArray: [6, 4],
                                    );
                                  },
                                ),

                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: 0,
                                      color: Colors.grey.withOpacity(0.5),
                                      strokeWidth: 1,
                                    ),
                                  ],
                                ),

                                borderData: FlBorderData(
                                  show: true,
                                  border: Border(
                                    left: BorderSide(
                                      color: Colors.black.withOpacity(0.5),
                                      width: 1.3,
                                    ),
                                    bottom: BorderSide(
                                      color: Colors.black.withOpacity(0.5),
                                      width: 1.3,
                                    ),
                                  ),
                                ),

                                titlesData: FlTitlesData(
                                  // ✅ التعديل هنا فقط
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      reservedSize: 45, // ← زودنا المساحة
                                      getTitlesWidget: (value, meta) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6, // ← بعدنا الأرقام
                                          ),
                                          child: Text(
                                            value.toInt().toString(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),

                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),

                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 70,
                                      getTitlesWidget: (value, meta) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: _label(
                                            value.toInt() == 0
                                                ? "👤"
                                                : value.toInt() == 1
                                                ? "👨‍⚕️"
                                                : value.toInt() == 2
                                                ? "👑"
                                                : "🚫",
                                            value.toInt() == 0
                                                ? "مستخدم"
                                                : value.toInt() == 1
                                                ? "أخصائي"
                                                : value.toInt() == 2
                                                ? "أدمن"
                                                : "محظور",
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                barGroups: [
                                  _bar(0, total, Colors.blue),
                                  _bar(1, specialists, Colors.green),
                                  _bar(2, admins, Colors.deepPurple),
                                  _bar(3, banned, Colors.red),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(String title, int value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, int y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y.toDouble(),
          color: color,
          width: 26,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(9),
            bottom: Radius.circular(0),
          ),
        ),
      ],
    );
  }

  Widget _label(String icon, String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
