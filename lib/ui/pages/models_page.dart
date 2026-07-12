import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/model_info.dart';
import '../../providers/app_provider.dart';
import '../widgets/capability_icons.dart';

class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  String _searchQuery = '';
  String? _filterProviderId;
  ModelCapability? _filterCapability;
  bool _cardView = true;

  /// 服务商标识首字：优先名称首字，名称空则用类型显示名首字
  static String _providerInitial(String name, String type) {
    final source = name.trim().isNotEmpty
        ? name.trim()
        : (AppConstants.providerDisplayNames[type] ?? type);
    return source.isNotEmpty ? source.characters.first.toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        // 构建筛选后的模型列表
        var filtered = app.models.toList();

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filtered = filtered.where((m) {
            return m.name.toLowerCase().contains(query) ||
                m.displayName.toLowerCase().contains(query);
          }).toList();
        }

        if (_filterProviderId != null) {
          filtered = filtered
              .where((m) => m.providerId == _filterProviderId)
              .toList();
        }

        if (_filterCapability != null) {
          filtered = filtered
              .where((m) => m.capabilities.contains(_filterCapability))
              .toList();
        }

        // 分组
        final grouped = <String, List<ModelInfo>>{};
        for (final m in filtered) {
          final providerId = m.providerId;
          final provider = app.providers.firstWhere(
            (p) => p.id == providerId,
            orElse: () => app.providers.first,
          );
          final key = provider.name;
          grouped.putIfAbsent(key, () => []).add(m);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('模型库'),
            centerTitle: false,
            actions: [
              Text('${app.enabledModelCount}/${app.models.length} 可用',
                  style: Theme.of(context).textTheme.bodySmall),
              IconButton(
                icon: Icon(_cardView ? Icons.list_rounded : Icons.grid_view_rounded),
                tooltip: _cardView ? '列表视图' : '卡片视图',
                onPressed: () => setState(() => _cardView = !_cardView),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: app.providers.isEmpty
              ? _buildEmptyState(context, Icons.cloud_off_rounded, '请先添加服务商',
                  '在「服务商」页面添加后，点击获取模型')
              : app.models.isEmpty
                  ? _buildEmptyState(context, Icons.download_rounded, '暂无模型',
                      '在「服务商」页面点击「获取模型」')
                  : Column(
                      children: [
                        _buildSearchBar(context, app),
                        Expanded(
                          child: _cardView
                              ? _buildCardView(context, app, grouped)
                              : _buildListView(context, app, filtered),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppProvider app) {
    final providerNames = <String, String>{};
    for (final p in app.providers) {
      providerNames[p.id] = p.name;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          // 搜索框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索模型名称...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          // 筛选芯片
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 服务商筛选
                FilterChip(
                  label: const Text('全部服务商'),
                  selected: _filterProviderId == null,
                  onSelected: (_) => setState(() {
                    _filterProviderId = null;
                    _filterCapability = null;
                  }),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ...app.providers.map((p) {
                  final isSelected = _filterProviderId == p.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            Color(AppConstants.providerColors[p.type] ?? 0xFF6C5CE7),
                        child: Text(
                          (AppConstants.providerDisplayNames[p.type] ?? '?')[0],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                      label: Text(p.name),
                      selected: isSelected,
                      onSelected: (v) => setState(() {
                        _filterProviderId = v ? p.id : null;
                        _filterCapability = null;
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                const SizedBox(width: 4),
                // 能力筛选
                FilterChip(
                  label: const Text('全部能力'),
                  selected: _filterCapability == null,
                  onSelected: (_) => setState(() => _filterCapability = null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ...ModelCapability.values.take(6).map((cap) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(CapabilityIcons.iconFor(cap), size: 16),
                      label: Text(cap.label),
                      selected: _filterCapability == cap,
                      onSelected: (v) =>
                          setState(() => _filterCapability = v ? cap : null),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView(BuildContext context, AppProvider app,
      Map<String, List<ModelInfo>> grouped) {
    if (grouped.isEmpty) {
      return Center(
        child: Text('没有匹配的模型',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final providerName = grouped.keys.elementAt(i);
        final models = grouped[providerName]!;
        final firstModel = models.first;
        final provider = app.providers.firstWhere(
          (p) => p.id == firstModel.providerId,
          orElse: () => app.providers.first,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: _filterProviderId != null || _searchQuery.isNotEmpty,
            leading: CircleAvatar(
              backgroundColor: Color(
                      AppConstants.providerColors[provider.type] ?? 0xFF6C5CE7)
                  .withValues(alpha: 0.15),
              child: Text(
                _providerInitial(provider.name, provider.type),
                style: TextStyle(
                    color: Color(AppConstants.providerColors[provider.type] ??
                        0xFF6C5CE7),
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(providerName,
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(
                '${models.where((m) => m.enabled).length}/${models.length} 个模型启用'),
            children: models.map((model) {
              return _ModelListTile(
                model: model,
                upstreamType: provider.type,
                onToggle: () => app.toggleModel(model.id),
                onProtocolChanged: (p) =>
                    app.updateModel(model.copyWith(exposedProtocol: p)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildListView(
      BuildContext context, AppProvider app, List<ModelInfo> models) {
    if (models.isEmpty) {
      return Center(
        child: Text('没有匹配的模型',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: models.length,
      itemBuilder: (context, i) {
        final model = models[i];
        final provider = app.providers.firstWhere(
          (p) => p.id == model.providerId,
          orElse: () => app.providers.first,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Color(
                      AppConstants.providerColors[provider.type] ?? 0xFF6C5CE7)
                  .withValues(alpha: 0.15),
              child: Text(
                _providerInitial(provider.name, provider.type),
                style: TextStyle(
                    color: Color(AppConstants.providerColors[provider.type] ??
                        0xFF6C5CE7),
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            title: Text(model.displayName,
                style: TextStyle(
                    fontFamily: 'monospace',
                    color: model.enabled ? null : Colors.grey)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CapabilityIcons(capabilities: model.capabilities.toList()),
                const SizedBox(height: 6),
                _ProtocolSelector(
                  upstreamType: provider.type,
                  exposed: model.exposedProtocol,
                  onChanged: (p) =>
                      app.updateModel(model.copyWith(exposedProtocol: p)),
                ),
              ],
            ),
            trailing: Switch(
              value: model.enabled,
              onChanged: (_) => app.toggleModel(model.id),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      },
    );
  }
}

class _ModelListTile extends StatelessWidget {
  final ModelInfo model;
  final String upstreamType;
  final VoidCallback onToggle;
  final ValueChanged<String> onProtocolChanged;

  const _ModelListTile({
    required this.model,
    required this.upstreamType,
    required this.onToggle,
    required this.onProtocolChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        model.displayName,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'monospace',
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!model.enabled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('已禁用',
                            style:
                                TextStyle(fontSize: 10, color: Colors.orange)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                CapabilityIcons(capabilities: model.capabilities.toList()),
                const SizedBox(height: 6),
                _ProtocolSelector(
                  upstreamType: upstreamType,
                  exposed: model.exposedProtocol,
                  onChanged: onProtocolChanged,
                ),
              ],
            ),
          ),
          Switch(
            value: model.enabled,
            onChanged: (_) => onToggle(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// 协议转换选择器：展示 上游协议 → 对外协议，可切换对外协议
class _ProtocolSelector extends StatelessWidget {
  final String upstreamType; // openai / gemini / claude
  final String exposed; // openai / claude
  final ValueChanged<String> onChanged;

  const _ProtocolSelector({
    required this.upstreamType,
    required this.exposed,
    required this.onChanged,
  });

  String _label(String p) => p == 'claude' ? 'Claude' : 'OpenAI';

  @override
  Widget build(BuildContext context) {
    final upstreamLabel =
        AppConstants.providerDisplayNames[upstreamType] ?? upstreamType;
    return Row(
      children: [
        Icon(Icons.swap_horiz_rounded,
            size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text('$upstreamLabel → 对外',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(width: 6),
        // OpenAI / Claude 二选一
        ...['openai', 'claude'].map((p) {
          final selected = exposed == p;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: selected ? null : () => onChanged(p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _label(p),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
