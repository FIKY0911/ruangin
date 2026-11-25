import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/view_state.dart';

/// Renders loading / empty / error+retry / data(+stale banner) consistently.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.builder,
    required this.emptyTitle,
    this.emptyMessage,
    this.emptyImage,
    this.showFreshness = true,
  });

  final ViewState<T> state;
  final Future<void> Function() onRetry;
  final Widget Function(BuildContext context, T data) builder;
  final String emptyTitle;
  final String? emptyMessage;
  final String? emptyImage;

  /// Hide the "Diperbarui HH.MM" strip (stale data is always shown).
  final bool showFreshness;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ViewLoading() => const Center(
        key: Key('state-loading'),
        child: CircularProgressIndicator(),
      ),
      ViewError(:final message) => _Scrollable(
        onRefresh: onRetry,
        child: _Message(
          key: const Key('state-error'),
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat',
          message: message,
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ),
      ),
      ViewEmpty(:final fetchedAt) => _Scrollable(
        onRefresh: onRetry,
        child: _Message(
          key: const Key('state-empty'),
          icon: Icons.inbox_outlined,
          image: emptyImage,
          title: emptyTitle,
          message: [
            ?emptyMessage,
            'Diperbarui ${formatTime(fetchedAt)}',
          ].join('\n'),
        ),
      ),
      ViewData(:final data, :final fetchedAt, :final staleReason) => Column(
        children: [
          if (showFreshness || staleReason != null)
            FreshnessBanner(
              fetchedAt: fetchedAt,
              staleReason: staleReason,
              onRetry: onRetry,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRetry,
              child: builder(context, data),
            ),
          ),
        ],
      ),
    };
  }
}

class FreshnessBanner extends StatelessWidget {
  const FreshnessBanner({
    super.key,
    required this.fetchedAt,
    required this.onRetry,
    this.staleReason,
  });

  final DateTime fetchedAt;
  final String? staleReason;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stale = staleReason != null;
    if (!stale) {
      return Container(
        key: const Key('fresh-banner'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Text(
          'Diperbarui ${formatTime(fetchedAt)}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    }
    return Material(
      key: const Key('stale-banner'),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.history, size: 18, color: scheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Data lama · diperbarui ${formatDateTime(fetchedAt)}\n$staleReason',
                style: TextStyle(
                  color: scheme.onTertiaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child, required this.onRefresh});

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.image,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null)
            Image.asset(image!, height: 160, fit: BoxFit.contain)
          else
            Icon(icon, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
