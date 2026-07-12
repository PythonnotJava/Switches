import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/model_info.dart';
import '../../models/ip_rule.dart';
import '../../providers/app_provider.dart';
import '../widgets/capability_icons.dart';

class IpManagerPage extends StatefulWidget {
  const IpManagerPage({super.key});

  @override
  State<IpManagerPage> createState() => _IpManagerPageState();
}

class _IpManagerPageState extends State<IpManagerPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('IP 白名单管理'),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: '添加IP规则',
                onPressed: () => _showAddIpDialog(context, app),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('白名单模式',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                app.ipRules.isEmpty
                                    ? (app.config.restrictToWhitelist
                                        ? '严格模式已开启：当前无规则，仅本机(127.0.0.1)可访问，其余IP一律拒绝。'
                                        : '当前无IP规则，所有IP均可访问全部模型。本地机器(127.0.0.1)始终拥有全部权限。')
                                    : '已配置${app.ipRules.length}条规则，仅匹配规则的IP可访问。本机始终放行。',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: app.ipRules.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.security_rounded,
                                size: 64,
                                color: Colors.grey.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            Text('无IP规则',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text('点击右上角 + 添加规则',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: app.ipRules.length,
                        itemBuilder: (context, i) =>
                            _IpRuleCard(rule: app.ipRules[i], app: app),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddIpDialog(BuildContext context, AppProvider app) async {
    final result = await showDialog<IpRule>(
      context: context,
      builder: (ctx) => _IpRuleFormDialog(models: app.models),
    );
    if (result != null) {
      await app.addIpRule(result);
    }
  }
}

class _IpRuleCard extends StatelessWidget {
  final IpRule rule;
  final AppProvider app;

  const _IpRuleCard({required this.rule, required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rule.enabled
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    color: rule.enabled ? Colors.green : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.ipAddress,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                      if (rule.label.isNotEmpty)
                        Text(rule.label,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                    value: rule.enabled,
                    onChanged: (_) => app.toggleIpRule(rule.id)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: rule.allowAllModels
                  ? [
                      Chip(
                        avatar: const Icon(Icons.check_circle,
                            size: 16, color: Colors.green),
                        label: const Text('全部模型'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]
                  : rule.allowedModelIds.map((mid) {
                      final model = _findModel(mid);
                      return Chip(
                        avatar: model != null
                            ? Icon(
                                CapabilityIcons.iconFor(model.capabilities.first),
                                size: 14)
                            : null,
                        label: Text(model?.displayName ?? mid,
                            style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () {
                          final updated = rule.copyWith(
                            allowedModelIds:
                                List<String>.from(rule.allowedModelIds)
                                  ..remove(mid),
                          );
                          app.updateIpRule(updated);
                        },
                      );
                    }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(context),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('编辑'),
                ),
                TextButton.icon(
                  onPressed: () => app.deleteIpRule(rule.id),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('删除'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ModelInfo? _findModel(String id) {
    try {
      return app.models.firstWhere((m) => m.id == id);
    } catch (e) {
      debugPrint('[Switches] IP findModel: $e');
      return null;
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final result = await showDialog<IpRule>(
      context: context,
      builder: (ctx) => _IpRuleFormDialog(models: app.models, existingRule: rule),
    );
    if (result != null) {
      await app.updateIpRule(result);
    }
  }
}

class _IpRuleFormDialog extends StatefulWidget {
  final List<ModelInfo> models;
  final IpRule? existingRule;

  const _IpRuleFormDialog({required this.models, this.existingRule});

  @override
  State<_IpRuleFormDialog> createState() => _IpRuleFormDialogState();
}

class _IpRuleFormDialogState extends State<_IpRuleFormDialog> {
  late TextEditingController _ipCtrl;
  late TextEditingController _labelCtrl;
  late Set<String> _selectedModelIds;
  bool _allowAll = true;

  bool get isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: widget.existingRule?.ipAddress ?? '');
    _labelCtrl = TextEditingController(text: widget.existingRule?.label ?? '');
    _selectedModelIds = Set.from(widget.existingRule?.allowedModelIds ?? []);
    _allowAll = widget.existingRule?.allowAllModels ?? true;
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? '编辑IP规则' : '添加IP规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _ipCtrl,
              decoration: const InputDecoration(
                labelText: 'IP地址',
                hintText: '如: 192.168.1.100 或 192.168.1.0/24',
                helperText: '支持单个IP或CIDR格式',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: '备注标签',
                hintText: '如: 办公室电脑',
              ),
            ),
            const SizedBox(height: 20),
            Text('模型分配', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('允许所有模型'),
              subtitle: const Text('关闭后可指定具体模型'),
              value: _allowAll,
              onChanged: (v) => setState(() => _allowAll = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_allowAll) ...[
              const SizedBox(height: 8),
              Text('选择允许的模型:',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              ...widget.models.where((m) => m.enabled).map((model) {
                return CheckboxListTile(
                  title: Text(model.displayName,
                      style: const TextStyle(fontSize: 14)),
                  subtitle:
                      CapabilityIcons(capabilities: model.capabilities.toList()),
                  value: _selectedModelIds.contains(model.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedModelIds.add(model.id);
                      } else {
                        _selectedModelIds.remove(model.id);
                      }
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (_ipCtrl.text.trim().isEmpty) return;
            final rule = IpRule(
              id: widget.existingRule?.id,
              ipAddress: _ipCtrl.text.trim(),
              label: _labelCtrl.text.trim(),
              allowedModelIds: _allowAll ? [] : _selectedModelIds.toList(),
              createdAt: widget.existingRule?.createdAt,
            );
            Navigator.pop(context, rule);
          },
          child: Text(isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }
}
