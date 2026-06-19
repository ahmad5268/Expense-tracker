import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/secure_storage_service.dart';

class ExportButton extends ConsumerWidget {
  final String workspaceId;
  final String format;
  final int year;
  final int month;

  const ExportButton({
    required this.workspaceId,
    required this.format,
    required this.year,
    required this.month,
    super.key,
  });

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    const apiBase = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000');
    final storage = ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();
    final url =
        '$apiBase/workspaces/$workspaceId/reports/export?format=$format&year=$year&month=$month';
    await launchUrl(
      Uri.parse('$url&token=$token'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: Icon(format == 'csv' ? Icons.table_chart : Icons.picture_as_pdf),
      label: Text(format.toUpperCase()),
      onPressed: () => _download(context, ref),
    );
  }
}
