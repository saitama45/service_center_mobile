import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_format_util.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/bms_empty_state.dart';
import '../../providers/app_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const int _kPageSize = 50;
final _dateLabel = DateFormat('MMM d, yyyy');

// ── Filter model ──────────────────────────────────────────────────────────────

class AuditLogFilter {
  const AuditLogFilter({
    required this.fromDate,
    required this.toDate,
    this.search = '',
    this.userId,
    this.moduleId,
    this.page = 0,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final String search;
  final String? userId;
  final String? moduleId;
  final int page;

  static AuditLogFilter today() {
    final now = DateTime.now();
    return AuditLogFilter(
      fromDate: DateTime(now.year, now.month, now.day),
      toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  AuditLogFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    Object? userId = _sentinel,
    Object? moduleId = _sentinel,
    int? page,
  }) =>
      AuditLogFilter(
        fromDate: fromDate ?? this.fromDate,
        toDate: toDate ?? this.toDate,
        search: search ?? this.search,
        userId: userId == _sentinel ? this.userId : userId as String?,
        moduleId: moduleId == _sentinel ? this.moduleId : moduleId as String?,
        page: page ?? this.page,
      );
}

const _sentinel = Object();

// ── Providers ─────────────────────────────────────────────────────────────────

final _auditFilterProvider =
    StateProvider.autoDispose<AuditLogFilter>((ref) => AuditLogFilter.today());

final _auditLogProvider =
    FutureProvider.autoDispose<List<_AuditEntry>>((ref) async {
  final filter = ref.watch(_auditFilterProvider);
  final db = ref.read(appDatabaseProvider);

  final logs = await db.auditLogDao.getLogs(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    search: filter.search.isEmpty ? null : filter.search,
    userId: filter.userId,
    moduleId: filter.moduleId,
    limit: _kPageSize,
    offset: filter.page * _kPageSize,
  );

  final users =
      await db.userDao.getAllUsers(includeInactive: true, limit: 1000);
  final modules = await db.moduleDao.getAllModules(activeOnly: false);
  final userById = {for (final u in users) u.id: u};
  final moduleById = {for (final m in modules) m.id: m};

  return logs.map((l) {
    final user = l.userId != null ? userById[l.userId] : null;
    final module = l.moduleId != null ? moduleById[l.moduleId] : null;
    return _AuditEntry(
      id: l.id,
      userFullName:
          user?.fullName ?? (l.userId != null ? 'User ${l.userId}' : 'System'),
      moduleName: module?.name,
      actionDetail: l.actionDetail,
      oldValue: l.oldValueJson,
      newValue: l.newValueJson,
      createdAt: l.createdAt,
    );
  }).toList();
});

final _auditCountProvider = FutureProvider.autoDispose<int>((ref) {
  final filter = ref.watch(_auditFilterProvider);
  final db = ref.read(appDatabaseProvider);
  return db.auditLogDao.countLogs(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    search: filter.search.isEmpty ? null : filter.search,
    userId: filter.userId,
    moduleId: filter.moduleId,
  );
});

// ── Dropdown option models ────────────────────────────────────────────────────

final _auditUserOptionsProvider =
    FutureProvider.autoDispose<List<_DropdownOption>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final users = await db.userDao.getAllUsers(includeInactive: true, limit: 1000);
  return users
      .map((u) => _DropdownOption(id: u.id, label: u.fullName))
      .toList();
});

final _auditModuleOptionsProvider =
    FutureProvider.autoDispose<List<_DropdownOption>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final modules = await db.moduleDao.getAllModules(activeOnly: true);
  return modules
      .map((m) => _DropdownOption(id: m.id, label: m.name))
      .toList();
});

class _DropdownOption {
  const _DropdownOption({required this.id, required this.label});
  final String id;
  final String label;
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _AuditEntry {
  const _AuditEntry({
    required this.id,
    required this.userFullName,
    this.moduleName,
    this.actionDetail,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  final String id;
  final String userFullName;
  final String? moduleName;
  final String? actionDetail;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_auditLogProvider);
    final filter = ref.watch(_auditFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(),
      appBar: BmsAppBar(
        title: AppStrings.auditLog,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(_auditFilterProvider.notifier).state =
                  AuditLogFilter.today();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const _AuditFilterBar(),
          Expanded(
            child: logsAsync.when(
              data: (logs) => logs.isEmpty && filter.page == 0
                  ? const BmsEmptyState(
                      message: AppStrings.noAuditLogs,
                      icon: Icons.history_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) => _AuditLogTile(entry: logs[i]),
                    ),
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryBlue)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          const _AuditPaginationBar(),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _AuditFilterBar extends ConsumerStatefulWidget {
  const _AuditFilterBar();

  @override
  ConsumerState<_AuditFilterBar> createState() => _AuditFilterBarState();
}

class _AuditFilterBarState extends ConsumerState<_AuditFilterBar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final filter = ref.read(_auditFilterProvider);
    final initial = isFrom ? filter.fromDate : filter.toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: AppColors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (isFrom) {
      final from = DateTime(picked.year, picked.month, picked.day);
      // Ensure from <= to
      final to = from.isAfter(filter.toDate) ? DateTime(picked.year, picked.month, picked.day, 23, 59, 59) : filter.toDate;
      ref.read(_auditFilterProvider.notifier).state =
          filter.copyWith(fromDate: from, toDate: to, page: 0);
    } else {
      final to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      ref.read(_auditFilterProvider.notifier).state =
          filter.copyWith(toDate: to, page: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_auditFilterProvider);
    final usersAsync = ref.watch(_auditUserOptionsProvider);
    final modulesAsync = ref.watch(_auditModuleOptionsProvider);
    final users = usersAsync.valueOrNull ?? [];
    final modules = modulesAsync.valueOrNull ?? [];

    final isFiltered = filter.search.isNotEmpty ||
        filter.userId != null ||
        filter.moduleId != null;

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.sm, AppDimensions.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search ───────────────────────────────────────────────────────
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search actions…',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.primaryBlue),
              suffixIcon: filter.search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(_auditFilterProvider.notifier).state =
                            filter.copyWith(search: '', page: 0);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
            onChanged: (v) {
              ref.read(_auditFilterProvider.notifier).state =
                  filter.copyWith(search: v, page: 0);
            },
          ),
          const SizedBox(height: AppDimensions.sm),

          // ── Date range + Clear ────────────────────────────────────────────
          Row(
            children: [
              _DateChip(
                label: 'From',
                date: filter.fromDate,
                onTap: () => _pickDate(context, true),
              ),
              const SizedBox(width: 8),
              _DateChip(
                label: 'To',
                date: filter.toDate,
                onTap: () => _pickDate(context, false),
              ),
              const Spacer(),
              if (isFiltered)
                TextButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    ref.read(_auditFilterProvider.notifier).state =
                        AuditLogFilter.today();
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),

          // ── User + Module dropdowns ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<String?>(
                  value: filter.userId,
                  hint: 'All Users',
                  icon: Icons.person_outline,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Users')),
                    ...users.map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.label,
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    ref.read(_auditFilterProvider.notifier).state =
                        filter.copyWith(userId: v, page: 0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<String?>(
                  value: filter.moduleId,
                  hint: 'All Modules',
                  icon: Icons.view_module_outlined,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Modules')),
                    ...modules.map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.label,
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    ref.read(_auditFilterProvider.notifier).state =
                        filter.copyWith(moduleId: v, page: 0);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
        ],
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip(
      {required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryBlue),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          color: AppColors.primaryBlue.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today,
                size: 14, color: AppColors.primaryBlue),
            const SizedBox(width: 4),
            Text(
              '$label: ${_dateLabel.format(date)}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: AppColors.primaryBlue),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        filled: true,
        fillColor: AppColors.white,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

// ── Pagination bar ────────────────────────────────────────────────────────────

class _AuditPaginationBar extends ConsumerWidget {
  const _AuditPaginationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(_auditCountProvider);
    final filter = ref.watch(_auditFilterProvider);

    return countAsync.when(
      data: (total) {
        final totalPages = (total / _kPageSize).ceil().clamp(1, 999999);
        final currentPage = filter.page + 1;
        final hasPrev = filter.page > 0;
        final hasNext = currentPage < totalPages;

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.borderGray)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $total',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.darkGray),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: hasPrev
                        ? () => ref
                            .read(_auditFilterProvider.notifier)
                            .state = filter.copyWith(page: filter.page - 1)
                        : null,
                    color: hasPrev
                        ? AppColors.primaryBlue
                        : AppColors.borderGray,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text('$currentPage / $totalPages',
                      style: AppTextStyles.label),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: hasNext
                        ? () => ref
                            .read(_auditFilterProvider.notifier)
                            .state = filter.copyWith(page: filter.page + 1)
                        : null,
                    color: hasNext
                        ? AppColors.primaryBlue
                        : AppColors.borderGray,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});
  final _AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        // Squircle icon chip — consistent with lists elsewhere in the app.
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.latteLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: const Icon(Icons.history,
              color: AppColors.caramel, size: 18),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          entry.actionDetail ?? 'Action #${entry.id}',
          style: AppTextStyles.h3,
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.person_outline,
                size: 12, color: AppColors.mediumGray),
            const SizedBox(width: 4),
            Text(entry.userFullName, style: AppTextStyles.caption),
            const SizedBox(width: 8),
            const Icon(Icons.access_time,
                size: 12, color: AppColors.mediumGray),
            const SizedBox(width: 4),
            Text(DateFormatUtil.formatDateTime(entry.createdAt),
                style: AppTextStyles.caption),
          ],
        ),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.moduleName != null)
                  _DetailRow('Module', entry.moduleName!),
                if (entry.oldValue != null && entry.oldValue!.isNotEmpty)
                  _DetailRow('Before', entry.oldValue!),
                if (entry.newValue != null && entry.newValue!.isNotEmpty)
                  _DetailRow('After', entry.newValue!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text('$label:', style: AppTextStyles.label),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
