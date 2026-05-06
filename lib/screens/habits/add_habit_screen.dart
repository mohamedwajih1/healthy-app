import '../../utils/constants.dart';
import 'package:flutter/material.dart';
import '../../models/habit_model.dart';
import 'package:provider/provider.dart';
import '../../widgets/custom_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/habit_provider.dart';
import '../../widgets/custom_text_field.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  HabitCategory _selectedCategory = HabitCategory.exercise;
  HabitFrequency _selectedFrequency = HabitFrequency.daily;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAddHabit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final habitProvider = context.read<HabitProvider>();

    if (authProvider.user == null) {
      _showSnackBar('خطأ: المستخدم غير مسجل', isError: true);
      return;
    }

    final habitData = HabitModel(
      id: '',
      userId: authProvider.user!.uid,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _selectedCategory,
      frequency: _selectedFrequency,
      createdAt: DateTime.now(),
      targetDays: 7, 
    );

    try {
      final success = await habitProvider.addHabit(habitData);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        _showSnackBar('تم إضافة العادة بنجاح! 🎉', isError: false);
      } else {
        _showSnackBar(habitProvider.error ?? 'فشل إضافة العادة', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('خطأ: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final isLoading = habitProvider.isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'إضافة عادة جديدة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Header with Icon
                _buildHeader(theme),
                const SizedBox(height: 32),

                // Name Field Card
                _buildCard(
                  child: CustomTextField(
                    controller: _nameController,
                    label: 'اسم العادة',
                    hint: 'مثال: المشي 30 دقيقة',
                    prefixIcon: Icons.edit_outlined,
                    maxLength: AppConstants.maxHabitNameLength,
                    enabled: !isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'من فضلك أدخل اسم العادة';
                      }
                      if (value.length < 3) {
                        return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Description Field Card
                _buildCard(
                  child: CustomTextField(
                    controller: _descriptionController,
                    label: 'الوصف (اختياري)',
                    hint: 'أضف تفاصيل عن العادة...',
                    prefixIcon: Icons.description_outlined,
                    maxLength: AppConstants.maxDescriptionLength,
                    maxLines: 3,
                    enabled: !isLoading,
                  ),
                ),
                const SizedBox(height: 24),

                // Category Section
                _buildSectionTitle('التصنيف', Icons.category_outlined),
                const SizedBox(height: 12),
                _buildCard(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: HabitCategory.values.map((category) {
                      return _buildCategoryChip(category, isLoading);
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Frequency Section
                _buildSectionTitle('التكرار', Icons.repeat_outlined),
                const SizedBox(height: 12),
                _buildCard(
                  child: Column(
                    children: HabitFrequency.values.map((frequency) {
                      return _buildFrequencyTile(frequency, isLoading);
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Add Button
                _buildAddButton(isLoading),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_task_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ابدأ عادة جديدة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'املأ البيانات التالية لإنشاء عادة جديدة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(HabitCategory category, bool isLoading) {
    final info = AppConstants.categoryInfo[category.name];
    final isSelected = _selectedCategory == category;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info?['icon'] ?? '✨', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              info?['name'] ?? '',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        onSelected: isLoading
            ? null
            : (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                  });
                }
              },
        backgroundColor: Colors.grey[50],
        selectedColor: (info?['color'] as Color?)?.withOpacity(0.2),
        checkmarkColor: info?['color'],
        elevation: isSelected ? 2 : 0,
        pressElevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? (info?['color'] as Color?) ?? Colors.grey
                : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyTile(HabitFrequency frequency, bool isLoading) {
    final isSelected = _selectedFrequency == frequency;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: RadioListTile<HabitFrequency>(
        value: frequency,
        groupValue: _selectedFrequency,
        onChanged: isLoading
            ? null
            : (value) {
                setState(() {
                  _selectedFrequency = value!;
                });
              },
        title: Text(
          _getFrequencyName(frequency),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          _getFrequencyDescription(frequency),
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAddButton(bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomButton(
        text: 'إضافة العادة',
        onPressed: _handleAddHabit,
        isLoading: isLoading,
        icon: Icons.check_rounded,
      ),
    );
  }

  String _getFrequencyName(HabitFrequency frequency) {
    switch (frequency) {
      case HabitFrequency.daily:
        return 'يومياً';
      case HabitFrequency.weekly:
        return 'أسبوعياً';
      case HabitFrequency.custom:
        return 'مخصص';
    }
  }

  String _getFrequencyDescription(HabitFrequency frequency) {
    switch (frequency) {
      case HabitFrequency.daily:
        return 'كل يوم';
      case HabitFrequency.weekly:
        return 'مرة واحدة في الأسبوع';
      case HabitFrequency.custom:
        return 'حدد الأيام المناسبة لك';
    }
  }
}
