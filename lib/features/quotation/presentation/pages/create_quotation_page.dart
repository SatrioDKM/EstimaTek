import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/quotation_model.dart';
import '../../data/repositories/quotation_repository.dart';
import 'quotation_detail_page.dart';

class CreateQuotationPage extends StatefulWidget {
  const CreateQuotationPage({super.key});

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final QuotationRepository _repository = QuotationRepository();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveQuotation() async {
    if (_formKey.currentState!.validate()) {
      final newQuote = QuotationModel(
        id: const Uuid().v4(),
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        projectAddress: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _repository.createQuotation(newQuote);

      if (mounted) {
        // Pop the create page and push the detail page
        Navigator.pop(context, true);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuotationDetailPage(quotation: newQuote)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Penawaran Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'Nama Customer',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'No. WhatsApp',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'Alamat Proyek',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'Catatan Tambahan',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveQuotation,
                child: const Text('Simpan & Mulai Desain'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
