import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// 模型能力图标组件
class CapabilityIcons extends StatelessWidget {
  final List<ModelCapability> capabilities;

  const CapabilityIcons({super.key, required this.capabilities});

  @override
  Widget build(BuildContext context) {
    if (capabilities.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = capabilities.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: sorted.map((cap) {
        return Tooltip(
          message: cap.label,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _capabilityIcon(cap),
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }

  static IconData _capabilityIcon(ModelCapability cap) {
    switch (cap) {
      case ModelCapability.text:
        return Icons.text_fields_rounded;
      case ModelCapability.imageInput:
        return Icons.image_rounded;
      case ModelCapability.imageOutput:
        return Icons.image_outlined;
      case ModelCapability.audioInput:
        return Icons.mic_rounded;
      case ModelCapability.audioOutput:
        return Icons.volume_up_rounded;
      case ModelCapability.videoInput:
        return Icons.videocam_rounded;
      case ModelCapability.functionCalling:
        return Icons.functions_rounded;
      case ModelCapability.streaming:
        return Icons.waves_rounded;
      case ModelCapability.reasoning:
        return Icons.psychology_rounded;
      case ModelCapability.jsonMode:
        return Icons.data_object_rounded;
    }
  }

  static IconData iconFor(ModelCapability cap) => _capabilityIcon(cap);
}
