import 'package:flutter/material.dart';

class TakeoffEdit extends StatefulWidget {
  final Function(double)? onSubmit;
  final double initialAltitude;

  const TakeoffEdit(
      {super.key, required this.onSubmit, required this.initialAltitude});

  @override
  State<TakeoffEdit> createState() => _TakeoffEditState();
}

class _TakeoffEditState extends State<TakeoffEdit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _altController;

  @override
  void initState() {
    _altController =
        TextEditingController(text: widget.initialAltitude.toString());
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
                controller: _altController,
                decoration: const InputDecoration(
                  labelText: 'Takeoff Height (in meters)',
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
                        {widget.onSubmit!(double.parse(_altController.text))}
                    }
                },
              ),
            ],
          )),
    );
  }
}
