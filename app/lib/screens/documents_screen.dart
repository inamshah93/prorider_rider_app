import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:velo_core/velo_core.dart';

import '../providers/app_providers.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  List<dynamic> _docs = [];
  bool _loading = true;
  String _type = 'cnic';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiProvider).get('/rider/documents');
      setState(() {
        _docs = (res.data['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final form = FormData.fromMap({
      'document_type': _type,
      'file': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    await ref.read(apiProvider).postMultipart('/rider/documents', form);
    ref.invalidate(riderProfileProvider);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC documents')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Upload CNIC, license, or bike registration for admin verification.'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Document type', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'cnic', child: Text('CNIC')),
                            DropdownMenuItem(value: 'license', child: Text('Driving license')),
                            DropdownMenuItem(value: 'bike_registration', child: Text('Bike registration')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'cnic'),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _upload, icon: const Icon(Icons.upload_file), label: const Text('Upload')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Uploaded', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_docs.isEmpty)
                  const Text('No documents yet.')
                else
                  ..._docs.map((d) {
                    final doc = d as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text('${doc['document_type']}'.replaceAll('_', ' ')),
                        subtitle: Text('${doc['status']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
