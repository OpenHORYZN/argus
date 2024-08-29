import 'package:flutter/material.dart';

class DelayEdit extends StatefulWidget {
  final Function(double)? onSubmit;
  final double initialDelay;

  const DelayEdit(
      {super.key, required this.onSubmit, required this.initialDelay});

  @override
  State<DelayEdit> createState() => _DelayEditState();
}

class _DelayEditState extends State<DelayEdit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _delayController;

  @override
  void initState() {
    _delayController =
        TextEditingController(text: widget.initialDelay.toString());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14.0),
      child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _delayController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Time Delay (in seconds)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  final doubleValue = double.tryParse(value);
                  if (doubleValue == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onEditingComplete: () => {
                  if (_formKey.currentState!.validate())
                    {
                      if (widget.onSubmit != null)
                        {widget.onSubmit!(double.parse(_delayController.text))}
                    }
                },
              ),
            ],
          )),
    );
  }
}
