import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/user_profile.dart';
import '../../../core/widgets/data_table_wrapper.dart';
import '../../auth/services/auth_service.dart';
import '../widgets/add_staff_dialog.dart';

final allProfilesProvider = FutureProvider<List<UserProfile>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final currentUserId = ref.watch(currentUserProvider).value?.id;
  final allProfiles = await authService.getAllProfiles();
  return allProfiles.where((p) => p.id != currentUserId).toList();
});

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Listesi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.adminDashboardRoute);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showAddStaffDialog(context, ref),
            tooltip: 'Personel Ekle',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('Kayıtlı personel bulunamadı.'));
          }

          if (isDesktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: DataTableWrapper(
                    title: 'Sistem Personelleri',
                    columns: const [
                      DataColumn(label: Text('Ad Soyad')),
                      DataColumn(label: Text('Kullanıcı Adı')),
                      DataColumn(label: Text('Şifre')),
                      DataColumn(label: Text('Yetki')),
                      DataColumn(label: Text('İşlemler')),
                    ],
                    rows: profiles.map((profile) {
                      final username = profile.email.split('@')[0];
                      return DataRow(
                        cells: [
                          DataCell(Text(profile.displayName, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(username)),
                          DataCell(Text(profile.password ?? "-")),
                          DataCell(Text(profile.role == 'admin' ? 'Yönetici' : 'Personel')),
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _confirmDelete(context, ref, profile),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(profile.displayName),
                  subtitle: Text('Kullanıcı: ${profile.email.split('@')[0]}\nŞifre: ${profile.password ?? "-"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, ref, profile),
                  ),
                ),
              ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AddStaffDialog(
        onSuccess: () => ref.invalidate(allProfilesProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: Text('${profile.displayName} adlı personeli silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authServiceProvider).deleteProfile(profile.id);
                ref.invalidate(allProfilesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personel silindi.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
            child: const Text('SİL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
