// ignore_for_file: avoid_print
import 'dart:convert';

/// OpenAI ↔ Gemini ↔ Claude 协议转换器
///
/// 统一内部格式: OpenAI Chat Completions 格式
/// 对外暴露 OpenAI 兼容 API
class ProtocolConverter {
  /// OpenAI → Gemini 请求转换
  static Map<String, dynamic> openaiToGemini(
    Map<String, dynamic> openaiRequest,
    String model,
  ) {
    final geminiRequest = <String, dynamic>{
      'contents': <Map<String, dynamic>>[],
      'generationConfig': <String, dynamic>{},
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    };

    // 转换消息
    final messages = openaiRequest['messages'] as List<dynamic>? ?? [];
    final systemMessages = <String>[];
    final contents = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final role = msg['role'] as String? ?? 'user';
      final content = msg['content'];

      if (role == 'system') {
        if (content is String) {
          systemMessages.add(content);
        }
        continue;
      }

      // Gemini role mapping
      String geminiRole;
      switch (role) {
        case 'assistant':
          geminiRole = 'model';
          break;
        case 'function':
        case 'tool':
          geminiRole = 'function';
          break;
        default:
          geminiRole = 'user';
      }

      // Content handling
      if (content is String) {
        contents.add({
          'role': geminiRole,
          'parts': [{'text': content}],
        });
      } else if (content is List) {
        final parts = <Map<String, dynamic>>[];
        for (final part in content) {
          if (part is Map) {
            if (part['type'] == 'text') {
              parts.add({'text': part['text']});
            } else if (part['type'] == 'image_url') {
              final url = part['image_url']['url'] as String;
              if (url.startsWith('data:')) {
                final split = url.split(',');
                if (split.length == 2) {
                  final mimeMatch =
                      RegExp(r'data:(image/\w+);base64').firstMatch(split[0]);
                  final mime = mimeMatch?.group(1) ?? 'image/png';
                  parts.add({
                    'inlineData': {
                      'mimeType': mime,
                      'data': split[1],
                    },
                  });
                }
              }
            }
          }
        }
        contents.add({
          'role': geminiRole,
          'parts': parts.isEmpty ? [{'text': ''}] : parts,
        });
      }
    }

    geminiRequest['contents'] = contents;

    // 系统消息
    if (systemMessages.isNotEmpty) {
      geminiRequest['systemInstruction'] = {
        'parts': systemMessages.map((s) => {'text': s}).toList(),
      };
    }

    // 生成配置
    final genConfig = <String, dynamic>{};
    if (openaiRequest['max_tokens'] != null) {
      genConfig['maxOutputTokens'] = openaiRequest['max_tokens'];
    }
    if (openaiRequest['temperature'] != null) {
      genConfig['temperature'] = openaiRequest['temperature'];
    }
    if (openaiRequest['top_p'] != null) {
      genConfig['topP'] = openaiRequest['top_p'];
    }
    if (openaiRequest['stop'] != null) {
      genConfig['stopSequences'] = openaiRequest['stop'] is List
          ? openaiRequest['stop']
          : [openaiRequest['stop']];
    }
    if (genConfig.isNotEmpty) {
      geminiRequest['generationConfig'] = genConfig;
    }

    // 工具转换
    if (openaiRequest['tools'] != null) {
      geminiRequest['tools'] = [
        {
          'functionDeclarations':
              _openaiToolsToGemini(openaiRequest['tools'] as List),
        }
      ];
    }

    return geminiRequest;
  }

  /// OpenAI → Claude 请求转换
  static Map<String, dynamic> openaiToClaude(
    Map<String, dynamic> openaiRequest,
    String model,
  ) {
    final claudeRequest = <String, dynamic>{
      'model': model,
      'max_tokens': openaiRequest['max_tokens'] ?? 4096,
      'messages': <Map<String, dynamic>>[],
    };

    final messages = openaiRequest['messages'] as List<dynamic>? ?? [];
    String? systemPrompt;
    final claudeMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final role = msg['role'] as String? ?? 'user';
      final content = msg['content'];

      if (role == 'system') {
        if (content is String) {
          systemPrompt = '${systemPrompt ?? ''}$content\n';
        }
        continue;
      }

      // Claude只支持 user 和 assistant
      String claudeRole;
      switch (role) {
        case 'assistant':
          claudeRole = 'assistant';
          break;
        case 'function':
        case 'tool':
          claudeRole = 'user';
          break;
        default:
          claudeRole = 'user';
      }

      // Content handling
      if (content is String) {
        claudeMessages.add({
          'role': claudeRole,
          'content': [{'type': 'text', 'text': content}],
        });
      } else if (content is List) {
        final contentBlocks = <Map<String, dynamic>>[];
        for (final part in content) {
          if (part is Map) {
            if (part['type'] == 'text') {
              contentBlocks.add({'type': 'text', 'text': part['text']});
            } else if (part['type'] == 'image_url') {
              final url = part['image_url']['url'] as String;
              if (url.startsWith('data:')) {
                final split = url.split(',');
                if (split.length == 2) {
                  final mimeMatch =
                      RegExp(r'data:(image/\w+);base64').firstMatch(split[0]);
                  final mime = mimeMatch?.group(1) ?? 'image/png';
                  contentBlocks.add({
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': mime,
                      'data': split[1],
                    },
                  });
                }
              }
            }
          }
        }
        claudeMessages.add({
          'role': claudeRole,
          'content': contentBlocks.isEmpty
              ? [{'type': 'text', 'text': ''}]
              : contentBlocks,
        });
      }
    }

    claudeRequest['messages'] = claudeMessages;

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      claudeRequest['system'] = systemPrompt.trim();
    }

    if (openaiRequest['temperature'] != null) {
      claudeRequest['temperature'] = openaiRequest['temperature'];
    }
    if (openaiRequest['top_p'] != null) {
      claudeRequest['top_p'] = openaiRequest['top_p'];
    }
    if (openaiRequest['stop'] != null) {
      claudeRequest['stop_sequences'] = openaiRequest['stop'] is List
          ? openaiRequest['stop']
          : [openaiRequest['stop']];
    }

    // 工具转换
    if (openaiRequest['tools'] != null) {
      claudeRequest['tools'] =
          _openaiToolsToClaude(openaiRequest['tools'] as List);
    }

    return claudeRequest;
  }

  /// Gemini 响应 → OpenAI 格式
  static Map<String, dynamic> geminiToOpenAI(
      Map<String, dynamic> geminiResponse, String model) {
    final candidates = geminiResponse['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) {
      return _openaiErrorResponse('No response from Gemini');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>? ?? {};
    final parts = content['parts'] as List<dynamic>? ?? [];

    final textParts = <String>[];
    final toolCalls = <Map<String, dynamic>>[];

    for (final part in parts) {
      if (part is Map) {
        if (part.containsKey('text') && part['text'] != null) {
          textParts.add(part['text'].toString());
        }
        if (part.containsKey('functionCall')) {
          final fc = part['functionCall'] as Map<String, dynamic>;
          toolCalls.add({
            'id': 'call_${toolCalls.length}',
            'type': 'function',
            'function': {
              'name': fc['name'] ?? '',
              'arguments': jsonEncode(fc['args'] ?? {}),
            },
          });
        }
      }
    }

    final finishReason = _mapGeminiFinishReason(
        candidate['finishReason']?.toString() ?? 'STOP');

    final message = <String, dynamic>{
      'role': 'assistant',
      'content': textParts.isNotEmpty ? textParts.join('\n') : null,
    };

    if (toolCalls.isNotEmpty) {
      message['tool_calls'] = toolCalls;
      message['content'] = null;
    }

    return {
      'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
      'object': 'chat.completion',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': message,
          'finish_reason': finishReason,
        }
      ],
      'usage': {
        'prompt_tokens':
            geminiResponse['usageMetadata']?['promptTokenCount'] ?? 0,
        'completion_tokens':
            geminiResponse['usageMetadata']?['candidatesTokenCount'] ?? 0,
        'total_tokens':
            geminiResponse['usageMetadata']?['totalTokenCount'] ?? 0,
      },
    };
  }

  /// Claude 响应 → OpenAI 格式
  static Map<String, dynamic> claudeToOpenAI(
      Map<String, dynamic> claudeResponse, String model) {
    final content = claudeResponse['content'] as List<dynamic>? ?? [];
    final textParts = <String>[];
    final toolCalls = <Map<String, dynamic>>[];

    for (final block in content) {
      if (block is Map) {
        switch (block['type']) {
          case 'text':
            textParts.add(block['text'].toString());
            break;
          case 'tool_use':
            toolCalls.add({
              'id': block['id'] ?? 'call_${toolCalls.length}',
              'type': 'function',
              'function': {
                'name': block['name'] ?? '',
                'arguments': jsonEncode(block['input'] ?? {}),
              },
            });
            break;
        }
      }
    }

    final stopReason = claudeResponse['stop_reason']?.toString() ?? 'end_turn';
    final finishReason = _mapClaudeStopReason(stopReason);

    final message = <String, dynamic>{
      'role': 'assistant',
      'content': textParts.isNotEmpty ? textParts.join('\n') : null,
    };

    if (toolCalls.isNotEmpty) {
      message['tool_calls'] = toolCalls;
      message['content'] = null;
    }

    return {
      'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
      'object': 'chat.completion',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': message,
          'finish_reason': finishReason,
        }
      ],
      'usage': {
        'prompt_tokens':
            claudeResponse['usage']?['input_tokens'] ?? 0,
        'completion_tokens':
            claudeResponse['usage']?['output_tokens'] ?? 0,
        'total_tokens':
            (claudeResponse['usage']?['input_tokens'] ?? 0) +
                (claudeResponse['usage']?['output_tokens'] ?? 0),
      },
    };
  }

  /// Gemini SSE chunk → OpenAI SSE chunk
  static String geminiSSEToOpenAI(String geminiSSE, String model) {
    try {
      final data = jsonDecode(geminiSSE) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isEmpty) return '';

      final candidate = candidates[0] as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>? ?? {};
      final parts = content['parts'] as List<dynamic>? ?? [];

      String? text;
      for (final part in parts) {
        if (part is Map && part.containsKey('text') && part['text'] != null) {
          text = part['text'].toString();
        }
      }

      if (text == null) return '';

      final chunk = {
        'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
        'object': 'chat.completion.chunk',
        'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'model': model,
        'choices': [
          {
            'index': 0,
            'delta': {'content': text},
            'finish_reason': null,
          }
        ],
      };
      return 'data: ${jsonEncode(chunk)}\n\n';
    } catch (e) {
      print('[Switches] geminiSSE: $e');
      return '';
    }
  }

  /// Claude SSE chunk → OpenAI SSE chunk
  static String claudeSSEToOpenAI(String claudeSSE, String model) {
    try {
      final data = jsonDecode(claudeSSE) as Map<String, dynamic>;
      final type = data['type']?.toString();

      if (type == 'content_block_delta') {
        final delta = data['delta'] as Map<String, dynamic>? ?? {};
        final text = delta['text']?.toString();
        if (text != null) {
          final chunk = {
            'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
            'object': 'chat.completion.chunk',
            'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'model': model,
            'choices': [
              {
                'index': 0,
                'delta': {'content': text},
                'finish_reason': null,
              }
            ],
          };
          return 'data: ${jsonEncode(chunk)}\n\n';
        }
      } else if (type == 'message_stop') {
        final chunk = {
          'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
          'object': 'chat.completion.chunk',
          'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {},
              'finish_reason': 'stop',
            }
          ],
        };
        return 'data: ${jsonEncode(chunk)}\n\ndata: [DONE]\n\n';
      }
      return '';
    } catch (e) {
      print('[Switches] claudeSSE: $e');
      return '';
    }
  }

  // ======= Claude 入口：Claude → OpenAI（IR）请求转换 =======

  /// Claude /v1/messages 请求 → OpenAI Chat Completions（内部 IR）
  static Map<String, dynamic> claudeRequestToOpenAI(
      Map<String, dynamic> claudeRequest) {
    final messages = <Map<String, dynamic>>[];

    // system：可能是字符串或 text block 列表
    final system = claudeRequest['system'];
    if (system is String && system.isNotEmpty) {
      messages.add({'role': 'system', 'content': system});
    } else if (system is List) {
      final text = system
          .whereType<Map>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text']?.toString() ?? '')
          .join('\n');
      if (text.isNotEmpty) messages.add({'role': 'system', 'content': text});
    }

    final claudeMessages = claudeRequest['messages'] as List<dynamic>? ?? [];
    for (final msg in claudeMessages) {
      if (msg is! Map) continue;
      final role = msg['role']?.toString() ?? 'user';
      final content = msg['content'];
      messages.addAll(_claudeMessageToOpenAI(role, content));
    }

    final result = <String, dynamic>{
      'model': claudeRequest['model']?.toString() ?? '',
      'messages': messages,
      'max_tokens': claudeRequest['max_tokens'] ?? 4096,
    };
    if (claudeRequest['temperature'] != null) {
      result['temperature'] = claudeRequest['temperature'];
    }
    if (claudeRequest['top_p'] != null) {
      result['top_p'] = claudeRequest['top_p'];
    }
    if (claudeRequest['stop_sequences'] != null) {
      result['stop'] = claudeRequest['stop_sequences'];
    }
    if (claudeRequest['stream'] == true) result['stream'] = true;

    // tools: Claude → OpenAI
    if (claudeRequest['tools'] is List) {
      result['tools'] = (claudeRequest['tools'] as List)
          .whereType<Map>()
          .map((t) => {
                'type': 'function',
                'function': {
                  'name': t['name'],
                  'description': t['description'] ?? '',
                  'parameters':
                      t['input_schema'] ?? {'type': 'object', 'properties': {}},
                },
              })
          .toList();
    }

    return result;
  }

  /// 拆解单条 Claude 消息为 OpenAI 消息（可能产出多条，如 tool_result）
  static List<Map<String, dynamic>> _claudeMessageToOpenAI(
      String role, dynamic content) {
    // 纯字符串
    if (content is String) {
      return [
        {'role': role, 'content': content}
      ];
    }
    if (content is! List) return [];

    final out = <Map<String, dynamic>>[];
    final parts = <Map<String, dynamic>>[];
    final toolCalls = <Map<String, dynamic>>[];

    for (final block in content) {
      if (block is! Map) continue;
      switch (block['type']) {
        case 'text':
          parts.add({'type': 'text', 'text': block['text']?.toString() ?? ''});
          break;
        case 'image':
          final src = block['source'] as Map?;
          if (src != null && src['type'] == 'base64') {
            final mime = src['media_type'] ?? 'image/png';
            parts.add({
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,${src['data']}'},
            });
          }
          break;
        case 'tool_use':
          toolCalls.add({
            'id': block['id'] ?? 'call_${toolCalls.length}',
            'type': 'function',
            'function': {
              'name': block['name'] ?? '',
              'arguments': jsonEncode(block['input'] ?? {}),
            },
          });
          break;
        case 'tool_result':
          // tool_result 独立成一条 OpenAI role:tool 消息
          final resultContent = block['content'];
          final text = resultContent is String
              ? resultContent
              : (resultContent is List
                  ? resultContent
                      .whereType<Map>()
                      .map((b) => b['text']?.toString() ?? '')
                      .join('\n')
                  : jsonEncode(resultContent));
          out.add({
            'role': 'tool',
            'tool_call_id': block['tool_use_id'] ?? '',
            'content': text,
          });
          break;
      }
    }

    // 组装主消息
    final msg = <String, dynamic>{'role': role};
    if (toolCalls.isNotEmpty) {
      msg['tool_calls'] = toolCalls;
      msg['content'] = parts.isEmpty
          ? null
          : parts.map((p) => p['text'] ?? '').join('\n');
    } else if (parts.length == 1 && parts[0]['type'] == 'text') {
      msg['content'] = parts[0]['text'];
    } else if (parts.isNotEmpty) {
      msg['content'] = parts;
    } else {
      msg['content'] = '';
    }
    // tool_result 先于主消息插入
    if (out.isNotEmpty) return [...out, if (toolCalls.isNotEmpty || parts.isNotEmpty) msg];
    return [msg];
  }

  // ======= 工具函数 =======

  static List<Map<String, dynamic>> _openaiToolsToGemini(List tools) {
    final declarations = <Map<String, dynamic>>[];
    for (final tool in tools) {
      if (tool is Map && tool['type'] == 'function') {
        final func = tool['function'] as Map<String, dynamic>;
        declarations.add({
          'name': func['name'],
          'description': func['description'] ?? '',
          'parameters': func['parameters'] ?? {},
        });
      }
    }
    return declarations;
  }

  static List<Map<String, dynamic>> _openaiToolsToClaude(List tools) {
    final claudeTools = <Map<String, dynamic>>[];
    for (final tool in tools) {
      if (tool is Map && tool['type'] == 'function') {
        final func = tool['function'] as Map<String, dynamic>;
        claudeTools.add({
          'name': func['name'],
          'description': func['description'] ?? '',
          'input_schema': func['parameters'] ?? {'type': 'object', 'properties': {}},
        });
      }
    }
    return claudeTools;
  }

  static String _mapGeminiFinishReason(String reason) {
    switch (reason) {
      case 'STOP':
        return 'stop';
      case 'MAX_TOKENS':
        return 'length';
      case 'SAFETY':
        return 'content_filter';
      default:
        return 'stop';
    }
  }

  static String _mapClaudeStopReason(String reason) {
    switch (reason) {
      case 'end_turn':
        return 'stop';
      case 'max_tokens':
        return 'length';
      case 'stop_sequence':
        return 'stop';
      case 'tool_use':
        return 'tool_calls';
      default:
        return 'stop';
    }
  }

  static Map<String, dynamic> _openaiErrorResponse(String message) {
    return {
      'error': {
        'message': message,
        'type': 'server_error',
        'code': 'internal_error',
      }
    };
  }

  // ======= Claude 出口：OpenAI（IR）响应 → Claude /v1/messages 格式 =======

  /// OpenAI Chat Completions 响应 → Claude Messages 响应
  static Map<String, dynamic> openaiToClaudeResponse(
      Map<String, dynamic> openaiResponse, String model) {
    final choices = openaiResponse['choices'] as List<dynamic>? ?? [];
    final contentBlocks = <Map<String, dynamic>>[];
    String stopReason = 'end_turn';

    if (choices.isNotEmpty) {
      final choice = choices[0] as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>? ?? {};

      final text = message['content'];
      if (text is String && text.isNotEmpty) {
        contentBlocks.add({'type': 'text', 'text': text});
      }

      final toolCalls = message['tool_calls'] as List<dynamic>? ?? [];
      for (final tc in toolCalls) {
        if (tc is Map) {
          final func = tc['function'] as Map<String, dynamic>? ?? {};
          dynamic input;
          try {
            input = jsonDecode(func['arguments']?.toString() ?? '{}');
          } catch (_) {
            input = {};
          }
          contentBlocks.add({
            'type': 'tool_use',
            'id': tc['id'] ?? 'toolu_${contentBlocks.length}',
            'name': func['name'] ?? '',
            'input': input,
          });
        }
      }

      stopReason = _mapOpenAIFinishToClaude(
          choice['finish_reason']?.toString() ?? 'stop');
    }

    if (contentBlocks.isEmpty) {
      contentBlocks.add({'type': 'text', 'text': ''});
    }

    final usage = openaiResponse['usage'] as Map<String, dynamic>? ?? {};
    return {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'message',
      'role': 'assistant',
      'model': model,
      'content': contentBlocks,
      'stop_reason': stopReason,
      'stop_sequence': null,
      'usage': {
        'input_tokens': usage['prompt_tokens'] ?? 0,
        'output_tokens': usage['completion_tokens'] ?? 0,
      },
    };
  }

  static String _mapOpenAIFinishToClaude(String reason) {
    switch (reason) {
      case 'stop':
        return 'end_turn';
      case 'length':
        return 'max_tokens';
      case 'tool_calls':
        return 'tool_use';
      case 'content_filter':
        return 'end_turn';
      default:
        return 'end_turn';
    }
  }

  /// 构造 Claude 错误响应
  static Map<String, dynamic> claudeErrorResponse(String message) {
    return {
      'type': 'error',
      'error': {'type': 'api_error', 'message': message},
    };
  }
}

/// OpenAI SSE 流 → Claude Messages SSE 流（有状态）
///
/// 用于 Claude 入口的流式响应：把内部 OpenAI 格式的增量事件
/// 重新编码为 Claude 的 message_start / content_block_delta / message_stop 事件序列。
class ClaudeSSEEncoder {
  final String model;
  bool _started = false;
  bool _blockOpen = false;
  String _stopReason = 'end_turn';

  ClaudeSSEEncoder(this.model);

  String _event(String type, Map<String, dynamic> data) {
    return 'event: $type\ndata: ${jsonEncode(data)}\n\n';
  }

  /// 处理一条 OpenAI SSE 的 data 负载（已去掉 "data: " 前缀）
  String handleOpenAIData(String jsonStr) {
    if (jsonStr == '[DONE]') return finish();
    final buffer = StringBuffer();
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) return '';
      final choice = choices[0] as Map<String, dynamic>;
      final delta = choice['delta'] as Map<String, dynamic>? ?? {};
      final finish = choice['finish_reason']?.toString();

      if (!_started) {
        _started = true;
        buffer.write(_event('message_start', {
          'type': 'message_start',
          'message': {
            'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
            'type': 'message',
            'role': 'assistant',
            'model': model,
            'content': [],
            'stop_reason': null,
            'usage': {'input_tokens': 0, 'output_tokens': 0},
          },
        }));
      }

      final text = delta['content'];
      if (text is String && text.isNotEmpty) {
        if (!_blockOpen) {
          _blockOpen = true;
          buffer.write(_event('content_block_start', {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {'type': 'text', 'text': ''},
          }));
        }
        buffer.write(_event('content_block_delta', {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': text},
        }));
      }

      if (finish != null) {
        _stopReason = ProtocolConverter._mapOpenAIFinishToClaude(finish);
      }
    } catch (_) {
      // 忽略无法解析的分片
    }
    return buffer.toString();
  }

  /// 输出收尾事件（幂等）
  String finish() {
    if (!_started) return '';
    final buffer = StringBuffer();
    if (_blockOpen) {
      _blockOpen = false;
      buffer.write(_event(
          'content_block_stop', {'type': 'content_block_stop', 'index': 0}));
    }
    buffer.write(_event('message_delta', {
      'type': 'message_delta',
      'delta': {'stop_reason': _stopReason, 'stop_sequence': null},
      'usage': {'output_tokens': 0},
    }));
    buffer.write(_event('message_stop', {'type': 'message_stop'}));
    _started = false;
    return buffer.toString();
  }
}
