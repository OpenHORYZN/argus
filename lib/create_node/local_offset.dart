import 'package:argus/src/rust/api/mission.dart';
import 'package:flutter/material.dart';

class LocalOffsetForm extends StatefulWidget {
  const LocalOffsetForm({super.key});

  @override
  State<LocalOffsetForm> createState() => _LocalOffsetFormState();
}

class _LocalOffsetFormState extends State<LocalOffsetForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _zController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Column(
        children: [
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: const Text('Enter Local Offset'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop(FlutterWaypoint.localOffset(
                        double.parse(_xController.text),
                        double.parse(_yController.text),
                        double.parse(_zController.text)));
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _xController,
                    decoration: const InputDecoration(
                      labelText: 'X (in meters)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value for X';
                      }
                      final doubleValue = double.tryParse(value);
                      if (doubleValue == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _yController,
                    decoration: const InputDecoration(
                      labelText: 'Y (in meters)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value for Y';
                      }
                      final doubleValue = double.tryParse(value);
                      if (doubleValue == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _zController,
                    decoration: const InputDecoration(
                      labelText: 'Z (in meters)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value for Z';
                      }
                      final doubleValue = double.tryParse(value);
                      if (doubleValue == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
