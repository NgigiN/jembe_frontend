import 'package:farm_tracker/core/di/service_locator.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CreateFarmPage extends StatefulWidget {
  const CreateFarmPage({super.key});

  @override
  State<CreateFarmPage> createState() => _CreateFarmPageState();
}

class _CreateFarmPageState extends State<CreateFarmPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  int _fiscalYearStartMonth = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await sl<FarmRemoteDataSource>().createFarm(
        name: sanitizeText(_nameController.text),
        location: sanitizeText(_locationController.text),
        fiscalYearStartMonth: _fiscalYearStartMonth,
      );
      if (!mounted) return;
      context.read<FarmBloc>().add(RefreshFarms());
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(context, 'Could not create the farm. Try again.'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Farm')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValidatedNameField(
                key: const Key('create_farm_name'),
                controller: _nameController,
                labelText: 'Farm Name',
                validator: (value) => requiredName(value, fieldLabel: 'Farm name'),
              ),
              const SizedBox(height: 16),
              ValidatedLocationField(
                controller: _locationController,
                labelText: 'Location (optional)',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _fiscalYearStartMonth,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Farm year starts in'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('January')),
                  DropdownMenuItem(value: 2, child: Text('February')),
                  DropdownMenuItem(value: 3, child: Text('March')),
                  DropdownMenuItem(value: 4, child: Text('April')),
                  DropdownMenuItem(value: 5, child: Text('May')),
                  DropdownMenuItem(value: 6, child: Text('June')),
                  DropdownMenuItem(value: 7, child: Text('July')),
                  DropdownMenuItem(value: 8, child: Text('August')),
                  DropdownMenuItem(value: 9, child: Text('September')),
                  DropdownMenuItem(value: 10, child: Text('October')),
                  DropdownMenuItem(value: 11, child: Text('November')),
                  DropdownMenuItem(value: 12, child: Text('December')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _fiscalYearStartMonth = value);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('create_farm_submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Farm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
