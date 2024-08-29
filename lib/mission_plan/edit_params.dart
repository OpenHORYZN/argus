import 'package:argus/src/rust/api/mission.dart';
import 'package:flutter/material.dart';

class ParamsEdit extends StatefulWidget {
  final FlutterMissionParams initialParams;
  final bool enabled;

  const ParamsEdit(
      {super.key, required this.initialParams, required this.enabled});

  @override
  State<ParamsEdit> createState() => _ParamsEditState();
}

class _ParamsEditState extends State<ParamsEdit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accelerationXYController;
  late TextEditingController _accelerationZController;
  late TextEditingController _velocityXYController;
  late TextEditingController _velocityZController;
  late TextEditingController _jerkXYController;
  late TextEditingController _jerkZController;

  @override
  void initState() {
    final tAcc = widget.initialParams.targetAcceleration;
    final tVel = widget.initialParams.targetVelocity;
    final tJerk = widget.initialParams.targetJerk;

    _accelerationXYController = TextEditingController(text: tAcc.x.toString());
    _accelerationZController = TextEditingController(text: tAcc.z.toString());
    _velocityXYController = TextEditingController(text: tVel.x.toString());
    _velocityZController = TextEditingController(text: tVel.z.toString());
    _jerkXYController = TextEditingController(text: tJerk.x.toString());
    _jerkZController = TextEditingController(text: tJerk.z.toString());

    super.initState();
  }

  String? _validateInput(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a value';
    }
    final doubleValue = double.tryParse(value);
    if (doubleValue == null) {
      return 'Please enter a valid number';
    }
    return null;
  }

  void _handleSubmit() {
    if (!widget.enabled) {
      Navigator.of(context).pop();
      return;
    }

    if (_formKey.currentState!.validate()) {
      final xyValue = double.parse(_accelerationXYController.text);
      Navigator.of(context).pop(
        FlutterMissionParams(
          targetAcceleration: FlutterVector3(
            x: xyValue,
            y: xyValue,
            z: double.parse(_accelerationZController.text),
          ),
          targetVelocity: FlutterVector3(
            x: xyValue,
            y: xyValue,
            z: double.parse(_velocityZController.text),
          ),
          targetJerk: FlutterVector3(
            x: xyValue,
            y: xyValue,
            z: double.parse(_jerkZController.text),
          ),
          disableYaw: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Column(children: [
          AppBar(
            leading: widget.enabled
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  )
                : null,
            title: widget.enabled
                ? const Text('Edit Mission Parameters')
                : const Text('Mission Parameters'),
            actions: [
              if (widget.enabled)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _handleSubmit,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Targets',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text('Acceleration: '),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextFormField(
                                autofocus: true,
                                controller: _accelerationXYController,
                                decoration: const InputDecoration(
                                  labelText: 'X/Y',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: _validateInput,
                                onEditingComplete: _handleSubmit,
                                readOnly: !widget.enabled,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextFormField(
                                controller: _accelerationZController,
                                decoration: const InputDecoration(
                                  labelText: 'Z',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: _validateInput,
                                onEditingComplete: _handleSubmit,
                                readOnly: !widget.enabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text('Velocity: '),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextFormField(
                                controller: _velocityXYController,
                                decoration: const InputDecoration(
                                  labelText: 'X/Y',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: _validateInput,
                                onEditingComplete: _handleSubmit,
                                readOnly: !widget.enabled,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextFormField(
                                controller: _velocityZController,
                                decoration: const InputDecoration(
                                  labelText: 'Z',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: _validateInput,
                                onEditingComplete: _handleSubmit,
                                readOnly: !widget.enabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text('Jerk: '),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextFormField(
                                controller: _jerkXYController,
                                decoration: const InputDecoration(
                                  labelText: 'X/Y',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: _validateInput,
                                onEditingComplete: _handleSubmit,
                                readOnly: !widget.enabled,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextFormField(
                                controller: _jerkZController,
                                decoration: const InputDecoration(
                                  labelText: 'Z',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: _validateInput,
                                onEditingComplete: _handleSubmit,
                                readOnly: !widget.enabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )),
          )
        ]));
  }
}
