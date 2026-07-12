import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/model_info.dart';
import '../../models/provider_model.dart';
import '../../providers/app_provider.dart';
import '../widgets/capability_icons.dart';

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key});

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('LLM 服务商'),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: '添加服务商',
                onPressed: () => _showAddProviderDialog(context, app),
              ),
            ],
          ),
          body: app.providers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 64,
                          color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('暂无服务商',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('点击右上角 + 添加',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: app.providers.length,
                  itemBuilder: (context, i) {
                    return _ProviderCard(
                      provider: app.providers[i],
                      modelCount:
                          app.modelsForProvider(app.providers[i].id).length,
                      onToggle: () => app.toggleProvider(app.providers[i].id),
                      onEdit: () =>
                          _showEditProviderDialog(context, app, app.providers[i]),
                      onDelete: () =>
                          _confirmDelete(context, app, app.providers[i]),
                      onFetchModels: () =>
                          _fetchAndNotify(context, app, app.providers[i].id),
                      onTestConnection: () =>
                          _testConnection(context, app, app.providers[i].id),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _fetchAndNotify(
      BuildContext context, AppProvider app, String providerId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('正在获取模型列表...'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final models = await app.fetchProviderModels(providerId);
      if (!context.mounted) return;
      // 立即移除加载中的 snackbar（hideCurrentSnackBar 是渐隐，会残留在对话框下方）
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      final provider =
          app.providers.firstWhere((p) => p.id == providerId);
      await _showDetectedModelsDialog(context, provider, models);
    } catch (e) {
      debugPrint('[Switches] fetchModels: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取失败：$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 展示检测到的模型（全部用 chip 平铺，有多少展示多少）
  Future<void> _showDetectedModelsDialog(
    BuildContext context,
    LLMProvider provider,
    List<ModelInfo> models,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _DetectedModelsDialog(
        provider: provider,
        models: models,
      ),
    );
  }

  Future<void> _testConnection(
      BuildContext context, AppProvider app, String providerId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('正在测试连接...'),
        ]),
        duration: Duration(seconds: 10),
      ),
    );
    final ok = await app.testProviderConnection(providerId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '连接成功 ✓' : '连接失败 ✗${app.error ?? ""}'),
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 添加服务商 → 自动拉取模型
  Future<void> _showAddProviderDialog(
      BuildContext context, AppProvider app) async {
    final result = await showDialog<LLMProvider>(
      context: context,
      builder: (ctx) => _ProviderFormDialog(),
    );
    if (result == null) return;

    await app.addProvider(result);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加 ${result.name}')),
    );

    // 自动检测模型（如果有API Key）
    if (result.apiKey.isNotEmpty) {
      await _fetchAndNotify(context, app, result.id);
    }
  }

  Future<void> _showEditProviderDialog(
      BuildContext context, AppProvider app, LLMProvider provider) async {
    final result = await showDialog<LLMProvider>(
      context: context,
      builder: (ctx) => _ProviderFormDialog(provider: provider),
    );
    if (result != null) {
      await app.updateProvider(result);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppProvider app, LLMProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务商'),
        content: Text('确定删除「${provider.name}」及其所有模型吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await app.deleteProvider(provider.id);
    }
  }
}

// ============= 服务商卡片 =============

class _ProviderCard extends StatelessWidget {
  final LLMProvider provider;
  final int modelCount;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFetchModels;
  final VoidCallback onTestConnection;

  const _ProviderCard({
    required this.provider,
    required this.modelCount,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onFetchModels,
    required this.onTestConnection,
  });

  @override
  Widget build(BuildContext context) {
    final hasKey = provider.apiKey.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderAvatar(provider: provider),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!provider.enabled)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('已禁用',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _ProviderTypeBadge(type: provider.type),
                          Text('$modelCount 个模型',
                              style: Theme.of(context).textTheme.bodySmall),
                          _ConnectionDot(hasKey: hasKey),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(value: provider.enabled, onChanged: (_) => onToggle()),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasKey
                  ? 'API Key: ${provider.apiKey.substring(0, 8)}...${provider.apiKey.substring(provider.apiKey.length - 4)}'
                  : 'API Key: 未设置',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: hasKey ? Colors.green : Colors.red,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              provider.baseUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Colors.grey,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            // 操作按钮：窄屏自动折行，避免溢出
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 0,
              children: [
                TextButton.icon(
                  onPressed: onTestConnection,
                  icon: const Icon(Icons.wifi_find_rounded, size: 18),
                  label: const Text('测速'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                TextButton.icon(
                  onPressed: onFetchModels,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('获取模型'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('编辑'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('删除'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 服务商头像：自定义图标 > 首字
class _ProviderAvatar extends StatelessWidget {
  final LLMProvider provider;
  const _ProviderAvatar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = AppThemeHelper.providerColor(provider.type);

    if (provider.hasIcon) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          provider.iconUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => _fallbackAvatar(color),
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                ),
              ),
            );
          },
        ),
      );
    }

    return _fallbackAvatar(color);
  }

  Widget _fallbackAvatar(Color color) {
    // 无自定义图标时，用服务商名称首字（名称为空则退回类型首字）
    final source =
        provider.name.trim().isNotEmpty ? provider.name.trim() : provider.displayType;
    final initial = source.isNotEmpty ? source.characters.first : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// 连接状态圆点
class _ConnectionDot extends StatelessWidget {
  final bool hasKey;
  const _ConnectionDot({required this.hasKey});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hasKey ? 'API Key 已设置' : 'API Key 未设置',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasKey ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

// ============= 类型标签 =============

class _ProviderTypeBadge extends StatelessWidget {
  final String type;
  const _ProviderTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = AppThemeHelper.providerColor(type);
    final label = AppConstants.providerDisplayNames[type] ?? type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ============= 表单对话框 =============

class _ProviderFormDialog extends StatefulWidget {
  final LLMProvider? provider;
  const _ProviderFormDialog({this.provider});

  @override
  State<_ProviderFormDialog> createState() => _ProviderFormDialogState();
}

class _ProviderFormDialogState extends State<_ProviderFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _iconUrlCtrl;
  late String _selectedType;
  bool _iconUrlExpanded = false;
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.provider != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.provider?.name ?? '');
    _apiKeyCtrl = TextEditingController(text: widget.provider?.apiKey ?? '');
    _baseUrlCtrl = TextEditingController(text: widget.provider?.baseUrl ?? '');
    _iconUrlCtrl = TextEditingController(text: widget.provider?.iconUrl ?? '');
    _selectedType = widget.provider?.type ?? 'openai';
    _iconUrlExpanded = (widget.provider?.iconUrl ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _iconUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 480 ? size.width * 0.86 : 400.0;

    return AlertDialog(
      title: Text(isEditing ? '编辑服务商' : '添加服务商'),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('类型', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: AppConstants.supportedProviders.map((type) {
                  return ButtonSegment<String>(
                    value: type,
                    label: Text(AppConstants.providerDisplayNames[type]!),
                    icon: Icon(_providerIcon(type), size: 18),
                  );
                }).toList(),
                selected: {_selectedType},
                onSelectionChanged: (v) {
                  setState(() {
                    _selectedType = v.first;
                    _baseUrlCtrl.text =
                        AppConstants.providerDefaultBaseUrls[_selectedType]!;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '如: 我的OpenAI',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://api.openai.com',
                ),
              ),
              const SizedBox(height: 12),
              // 自定义图标（可折叠）
              InkWell(
                onTap: () =>
                    setState(() => _iconUrlExpanded = !_iconUrlExpanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _iconUrlExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '自定义图标（可选）',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.primary),
                      ),
                      if (_iconUrlCtrl.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            _iconUrlCtrl.text,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) =>
                                const Icon(Icons.broken_image, size: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_iconUrlExpanded) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _iconUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: '图标URL',
                    hintText: 'https://... 留空则显示服务商首字',
                    helperText: '设置后将显示为服务商头像，不设置则使用首字',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final provider = LLMProvider(
                id: widget.provider?.id,
                name: _nameCtrl.text.trim(),
                type: _selectedType,
                apiKey: _apiKeyCtrl.text.trim(),
                baseUrl: _baseUrlCtrl.text.trim().isEmpty
                    ? null
                    : _baseUrlCtrl.text.trim(),
                iconUrl: _iconUrlCtrl.text.trim(),
                createdAt: widget.provider?.createdAt,
              );
              Navigator.pop(context, provider);
            }
          },
          child: Text(isEditing ? '保存并检测模型' : '添加并检测模型'),
        ),
      ],
    );
  }

  IconData _providerIcon(String type) {
    switch (type) {
      case 'openai':
        return Icons.auto_awesome;
      case 'gemini':
        return Icons.stars_rounded;
      case 'claude':
        return Icons.psychology_rounded;
      default:
        return Icons.cloud;
    }
  }
}

// ============= 主题辅助 =============
class AppThemeHelper {
  static Color providerColor(String type) {
    return Color(AppConstants.providerColors[type] ?? 0xFF6C5CE7);
  }
}

// ============= 检测到的模型对话框 =============

/// 导入服务商后展示检测到的模型：全部用 chip 平铺，有多少展示多少
class _DetectedModelsDialog extends StatefulWidget {
  final LLMProvider provider;
  final List<ModelInfo> models;

  const _DetectedModelsDialog({
    required this.provider,
    required this.models,
  });

  @override
  State<_DetectedModelsDialog> createState() => _DetectedModelsDialogState();
}

class _DetectedModelsDialogState extends State<_DetectedModelsDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final color = AppThemeHelper.providerColor(widget.provider.type);
    final all = widget.models;
    final filtered = _query.isEmpty
        ? all
        : all.where((m) {
            final q = _query.toLowerCase();
            return m.name.toLowerCase().contains(q) ||
                m.displayName.toLowerCase().contains(q);
          }).toList();

    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 560 ? size.width * 0.92 : 520.0;
    final maxListHeight = size.height * 0.5;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download_done_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '检测到 ${all.length} 个模型',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '来自 ${widget.provider.name}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (all.length > 8)
              TextField(
                decoration: const InputDecoration(
                  hintText: '筛选模型...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            if (all.length > 8) const SizedBox(height: 12),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('没有匹配的模型',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxListHeight),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: filtered
                              .map((m) => _ModelChip(model: m, color: color))
                              .toList(),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              _query.isEmpty
                  ? '共 ${all.length} 个，已全部保存到模型库'
                  : '匹配 ${filtered.length} / 共 ${all.length} 个',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// 单个模型 chip：名称 + 能力图标
class _ModelChip extends StatelessWidget {
  final ModelInfo model;
  final Color color;

  const _ModelChip({required this.model, required this.color});

  @override
  Widget build(BuildContext context) {
    final caps = model.capabilities.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Tooltip(
      message: caps.isEmpty
          ? model.name
          : '${model.name}\n${caps.map((c) => c.label).join(' · ')}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                model.displayName,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (caps.isNotEmpty) ...[
              const SizedBox(width: 8),
              ...caps.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    CapabilityIcons.iconFor(c),
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
