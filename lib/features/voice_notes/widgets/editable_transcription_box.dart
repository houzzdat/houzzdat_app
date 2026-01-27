import 'package:flutter/material.dart';

class EditableTranscriptionBox extends StatefulWidget {
  final String initialText;
  final bool canEdit;
  final Function(String) onSave;

  const EditableTranscriptionBox({
    Key? key,
    required this.initialText,
    required this.canEdit,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditableTranscriptionBox> createState() =>
      _EditableTranscriptionBoxState();
}

class _EditableTranscriptionBoxState extends State<EditableTranscriptionBox> {
  late TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(EditableTranscriptionBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcription',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          enabled: widget.canEdit && _editing,
          maxLines: null,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixIcon: widget.canEdit
                ? IconButton(
                    icon: Icon(_editing ? Icons.save : Icons.edit),
                    onPressed: () {
                      if (_editing) {
                        widget.onSave(_controller.text);
                      }
                      setState(() => _editing = !_editing);
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}