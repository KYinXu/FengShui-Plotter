import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';

class GridInputForm extends StatefulWidget {
  final Function(Grid grid) onGridCreated;

  const GridInputForm({
    super.key,
    required this.onGridCreated,
  });

  @override
  State<GridInputForm> createState() => _GridInputFormState();
}

class _GridInputFormState extends State<GridInputForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final grid = Grid(
        lengthInches: double.parse(_lengthController.text),
        widthInches: double.parse(_widthController.text),
      );
      widget.onGridCreated(grid);
    }
  }

  String? _validateDimension(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return fieldName == 'length' 
          ? AppConstants.enterLengthError 
          : AppConstants.enterWidthError;
    }
    final n = double.tryParse(value);
    if (n == null || n <= 0) {
      return AppConstants.positiveIntegerError;
    }
    if (n > AppConstants.maxGridSize * 12) {
      return 'Maximum size is ${AppConstants.maxGridSize * 12} inches';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _lengthController,
              decoration: const InputDecoration(
                labelText: AppConstants.lengthLabel,
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => _validateDimension(value, 'length'),
            ),
          ),
          const SizedBox(width: AppConstants.defaultPadding),
          Expanded(
            child: TextFormField(
              controller: _widthController,
              decoration: const InputDecoration(
                labelText: AppConstants.widthLabel,
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => _validateDimension(value, 'width'),
            ),
          ),
          const SizedBox(width: AppConstants.defaultPadding),
          ElevatedButton(
            onPressed: _submit,
            child: const Text(AppConstants.createGridButton),
          ),
        ],
      ),
    );
  }
} 