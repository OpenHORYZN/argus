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

  void submit() {
    if (_formKey.currentState!.validate()) {
      if (_xController.text.isEmpty) {
        _xController.text = "0";
      }
      if (_yController.text.isEmpty) {
        _yController.text = "0";
      }
      if (_zController.text.isEmpty) {
        _zController.text = "0";
      }
      Navigator.of(context).pop(FlutterWaypoint.localOffset(
          double.parse(_xController.text),
          double.parse(_yController.text),
          double.parse(_zController.text)));
    }
  }

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
                onPressed: submit,
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
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'X (in meters)',
                    ),
                    textInputAction: TextInputAction.next,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isEmpty) {
                        return null;
                      }
                      final doubleValue = double.tryParse(value ?? "0");
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
                    textInputAction: TextInputAction.next,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isEmpty) {
                        return null;
                      }
                      final doubleValue = double.tryParse(value ?? "0");
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
                    onFieldSubmitted: (value) {
                      submit();
                    },
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isEmpty) {
                        return null;
                      }
                      final doubleValue = double.tryParse(value ?? "0");
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
