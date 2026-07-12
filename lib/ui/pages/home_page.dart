import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _logFilter = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('仪表盘'),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServerStatusCard(app: app),
                const SizedBox(height: 24),
                // 统计卡片：响应式网格，窄屏 2 列、宽屏 3 列，所有卡片等宽等高
                _StatGrid(
                  stats: [
                    _StatData(
                      icon: Icons.cloud_done_rounded,
                      label: '服务商',
                      value:
                          '${app.enabledProviderCount}/${app.providers.length}',
                      color: Colors.blue,
                    ),
                    _StatData(
                      icon: Icons.model_training_rounded,
                      label: '可用模型',
                      value: '${app.enabledModelCount}/${app.models.length}',
                      color: Colors.green,
                    ),
                    _StatData(
                      icon: Icons.security_rounded,
                      label: 'IP规则',
                      value: '${app.ipRules.length}',
                      color: Colors.orange,
                    ),
                    _StatData(
                      icon: Icons.trending_up_rounded,
                      label: '总请求',
                      value: '${app.totalRequests}',
                      color: Colors.purple,
                    ),
                    _StatData(
                      icon: Icons.check_circle_outline,
                      label: '成功率',
                      value:
                          '${(app.successRate * 100).toStringAsFixed(1)}%',
                      color: app.successRate > 0.9
                          ? Colors.green
                          : app.successRate > 0.7
                              ? Colors.orange
                              : Colors.red,
                    ),
                    _StatData(
                      icon: Icons.error_outline,
                      label: '失败',
                      value: '${app.errorRequests}',
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _EndpointInfoCard(port: app.config.port),
                const SizedBox(height: 24),
                // 模型使用排行
                if (app.modelUsageCount.isNotEmpty) ...[
                  Text('模型使用排行',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ModelUsageChart(usage: app.modelUsageCount),
                  const SizedBox(height: 24),
                ],
                // 请求日志
                Row(
                  children: [
                    Text('请求日志',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (app.requestLogs.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _confirmClearLogs(context, app),
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: const Text('清空'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _RequestLogs(
                  logs: app.requestLogs,
                  filterQuery: _logFilter,
                  onFilterChanged: (v) =>
                      setState(() => _logFilter = v),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmClearLogs(BuildContext context, AppProvider app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空所有请求日志和统计数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await app.clearRequestLogs();
    }
  }
}

class _ServerStatusCard extends StatelessWidget {
  final AppProvider app;
  const _ServerStatusCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: app.serverRunning
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
              child: Icon(
                app.serverRunning
                    ? Icons.cloud_rounded
                    : Icons.cloud_off_rounded,
                color: app.serverRunning ? Colors.green : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.serverRunning ? '服务运行中' : '服务已停止',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              app.serverRunning ? Colors.green : Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.serverRunning
                        ? '端口 ${app.config.port}  |  OpenAI: /v1  ·  Claude: /v1/messages'
                        : '点击按钮启动服务',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: app.toggleServer,
              icon: Icon(app.serverRunning ? Icons.stop : Icons.play_arrow),
              label: Text(app.serverRunning ? '停止' : '启动'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    app.serverRunning ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计卡片数据
class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

/// 响应式统计网格：按可用宽度决定列数，所有卡片等宽等高
class _StatGrid extends StatelessWidget {
  final List<_StatData> stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 窄屏 2 列，宽屏 3 列
        final columns = constraints.maxWidth < 480 ? 2 : 3;
        const spacing = 16.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats
              .map((s) => SizedBox(
                    width: itemWidth,
                    child: _StatCard(data: s),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: data.color, size: 30),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(data.value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: data.color)),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointInfoCard extends StatelessWidget {
  final int port;
  const _EndpointInfoCard({required this.port});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.api_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('API 端点',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 16),
            // OpenAI 兼容格式
            _protocolLabel(context, 'OpenAI 兼容格式'),
            const SizedBox(height: 8),
            _endpointRow(context, 'POST', '/v1/chat/completions',
                '聊天补全（支持流式）'),
            const Divider(height: 20),
            _endpointRow(context, 'GET', '/v1/models', '模型列表（仅对外 OpenAI）'),
            const SizedBox(height: 16),
            // Claude Messages 格式
            _protocolLabel(context, 'Claude Messages 格式'),
            const SizedBox(height: 8),
            _endpointRow(context, 'POST', '/v1/messages',
                '消息补全（支持流式）'),
            const SizedBox(height: 16),
            _protocolLabel(context, '通用'),
            const SizedBox(height: 8),
            _endpointRow(context, 'GET', '/health', '健康检查'),
            const SizedBox(height: 12),
            _copyRow(context, 'OpenAI Base URL',
                'http://localhost:$port/v1'),
            const SizedBox(height: 8),
            _copyRow(context, 'Claude Base URL',
                'http://localhost:$port'),
          ],
        ),
      ),
    );
  }

  Widget _protocolLabel(BuildContext context, String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
      ],
    );
  }

  Widget _copyRow(BuildContext context, String label, String url) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    )),
          ),
          Expanded(
            child: SelectableText(
              url,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _endpointRow(
      BuildContext context, String method, String path, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: method == 'POST' ? Colors.green : Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(method,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(width: 12),
        Text(path,
            style:
                const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(desc,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ),
      ],
    );
  }
}

/// 模型使用排行
class _ModelUsageChart extends StatelessWidget {
  final Map<String, int> usage;
  const _ModelUsageChart({required this.usage});

  @override
  Widget build(BuildContext context) {
    final sorted = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxCount = top.isNotEmpty ? top.first.value.toDouble() : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: top.map((e) {
            final ratio = e.value / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      e.key,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 16,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${e.value}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RequestLogs extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final String filterQuery;
  final ValueChanged<String> onFilterChanged;

  const _RequestLogs({
    required this.logs,
    required this.filterQuery,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 过滤
    var filtered = logs;
    if (filterQuery.isNotEmpty) {
      final q = filterQuery.toLowerCase();
      filtered = logs.where((l) {
        final ip = (l['ip'] as String? ?? '').toLowerCase();
        final model = (l['model'] as String? ?? '').toLowerCase();
        return ip.contains(q) || model.contains(q);
      }).toList();
    }

    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('暂无请求记录',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey)),
          ),
        ),
      );
    }

    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索IP或模型名...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            onChanged: onFilterChanged,
          ),
        ),
        if (filterQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '匹配 ${filtered.length} 条',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
          ),
        // 日志列表：固定最大高度 + 独立懒加载滚动，
        // 避免日志越积越多撑高页面 / 一次性构建全部项造成卡顿。
        Card(
          clipBehavior: Clip.antiAlias,
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('无匹配记录',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _LogTile(log: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 单条请求日志（抽成独立 widget 便于列表复用与重建隔离）
class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final timeStr = log['time'] as String? ?? '';
    final time = DateTime.tryParse(timeStr) ?? DateTime.now();
    final ip = log['ip'] as String? ?? 'unknown';
    final model = log['model'] as String? ?? 'unknown';
    final status = log['status'] as int? ?? 0;
    final isSuccess = status >= 200 && status < 300;

    return ListTile(
      dense: true,
      leading: Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        color: isSuccess ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(model,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
      subtitle: Row(
        children: [
          Icon(Icons.language_rounded, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(ip, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          Text(
            'HTTP $status',
            style: TextStyle(
                fontSize: 11,
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
      trailing: Text(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
