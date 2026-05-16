import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../providers/app_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _authToken;

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  final List<Map<String, dynamic>> _logs = [];

  // Filters
  final _searchCtrl = TextEditingController();
  String? _selectedSubUnit;
  String? _selectedStoreId;
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadToken().then((_) => _fetchLogs());
  }

  Future<void> _loadToken() async {
    const storage = FlutterSecureStorage();
    _authToken = await storage.read(key: 'session_token');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs({int page = 1}) async {
    if (page == 1) setState(() { _isLoading = true; _logs.clear(); });

    final dateFrom = DateFormat('yyyy-MM-dd').format(_dateFrom);
    final dateTo = DateFormat('yyyy-MM-dd').format(_dateTo);
    debugPrint('ATT fetch page=$page dateFrom=$dateFrom dateTo=$dateTo');

    final repo = ref.read(dtrRepositoryProvider);
    final data = await repo.getAttendanceLogs(
      page: page,
      search: _searchCtrl.text.trim(),
      subUnit: _selectedSubUnit,
      storeId: _selectedStoreId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    if (!mounted) return;
    setState(() {
      if (page == 1) _data = data;
      final newLogs = (data?['logs']?['data'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      _logs.addAll(newLogs);

      // Sort all accumulated logs by log_time descending
      _logs.sort((a, b) {
        final aTime = _parseTime(a);
        final bTime = _parseTime(b);
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      _currentPage = page;
      _lastPage = (data?['logs']?['last_page'] as num?)?.toInt() ?? 1;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  DateTime? _parseTime(Map<String, dynamic> log) {
    try {
      final raw = log['log_time'] ?? log['captured_at'] ?? log['created_at'];
      if (raw == null) return null;
      return DateTime.parse(raw as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;
    setState(() => _isLoadingMore = true);
    await _fetchLogs(page: _currentPage + 1);
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedSubUnit = null;
      _selectedStoreId = null;
      _dateFrom = DateTime.now();
      _dateTo = DateTime.now();
    });
    _fetchLogs();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo.isBefore(_dateFrom)) _dateTo = _dateFrom;
      } else {
        _dateTo = picked;
        if (_dateFrom.isAfter(_dateTo)) _dateFrom = _dateTo;
      }
    });
    _fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    final stores = (_data?['stores'] as List? ?? []);

    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(title: 'Attendance Logs'),
      body: Column(
        children: [
          _buildFilters(stores),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLogsTab(),
                      _buildWorkHoursTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List stores) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStoreDropdown(stores)),
              const SizedBox(width: 8),
              Expanded(child: _buildDateField('Date From', _dateFrom, () => _pickDate(isFrom: true))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDateField('Date To', _dateTo, () => _pickDate(isFrom: false))),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDropdown(List stores) {
    return DropdownButtonFormField<String>(
      value: _selectedStoreId,
      isExpanded: true,
      decoration: _inputDecoration('Store'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Stores')),
        ...stores.map((s) => DropdownMenuItem(
              value: s['id'].toString(),
              child: Text(s['name'] ?? '', overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (v) {
        setState(() => _selectedStoreId = v);
        _fetchLogs();
      },
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: _inputDecoration(label),
          controller: TextEditingController(
            text: DateFormat('MM/dd/yyyy').format(date),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        isDense: true,
      );

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.primaryBlack,
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.primaryBlack,
      tabs: const [
        Tab(text: 'Logs'),
        Tab(text: 'Work Hours'),
      ],
    );
  }

  // ── Logs tab ──────────────────────────────────────────────────────────────

  Widget _buildLogsTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? const Center(child: Text('No logs found.'))
                  : RefreshIndicator(
                      onRefresh: () => _fetchLogs(page: 1),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppDimensions.md),
                        itemCount: _logs.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          if (i == _logs.length) return _buildPaginationFooter();
                          return _buildLogCard(_logs[i]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    final total = ((_data?['logs']?['total']) as num?)?.toInt() ?? 0;
    final hasMore = _currentPage < _lastPage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            'Showing ${_logs.length} of $total logs',
            style: AppTextStyles.caption.copyWith(color: Colors.grey),
          ),
          if (hasMore) ...[
            const SizedBox(height: 8),
            _isLoadingMore
                ? const CircularProgressIndicator()
                : OutlinedButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Load More'),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.md, AppDimensions.md, 0),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _fetchLogs();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onSubmitted: (_) => _fetchLogs(),
        onChanged: (v) {
          if (v.isEmpty) _fetchLogs();
          setState(() {});
        },
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final user = log['user'] as Map<String, dynamic>?;
    final store = (log['schedule_store'] ?? log['store']) as Map<String, dynamic>?;
    final String type = log['type'] ?? '';
    final bool isIn = type == 'time_in';

    DateTime? logTime;
    try {
      logTime = DateTime.parse(
        log['log_time'] ?? log['captured_at'] ?? log['created_at'],
      ).toLocal();
    } catch (_) {}

    // Build full photo URL from the server path
    final String? rawPath = log['photo_path'] as String?;
    final String? photoUrl = rawPath != null && rawPath.isNotEmpty
        ? (rawPath.startsWith('http')
            ? rawPath
            : 'https://support.tablegroup.com.ph/serve-storage/$rawPath')
        : null;
    final double? lat = log['latitude'] != null ? _toDouble(log['latitude']) : null;
    final double? lng = log['longitude'] != null ? _toDouble(log['longitude']) : null;
    final String? deviceInfo = log['device_info'] as String?;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selfie
            _buildSelfie(photoUrl),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User
                  if (user != null) ...[
                    Text(
                      user['name'] ?? user['full_name'] ?? '',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user['email'] ?? '',
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Store
                  if (store != null) ...[
                    Text(
                      store['name'] ?? store['store_name'] ?? '',
                      style: AppTextStyles.bodySmall,
                    ),
                    if ((store['code'] ?? store['store_code']) != null)
                      Text(
                        'CODE: ${store['code'] ?? store['store_code']}',
                        style: AppTextStyles.caption.copyWith(color: Colors.grey),
                      ),
                    const SizedBox(height: 6),
                  ],
                  // Time + Type badge
                  Row(
                    children: [
                      if (logTime != null) ...[
                        Text(
                          DateFormat('h:mm:ss a').format(logTime),
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('M/d/yyyy').format(logTime),
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildTypeBadge(isIn),
                    ],
                  ),
                  // Device
                  if (deviceInfo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      deviceInfo,
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // View on Map
                  if (lat != null && lng != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _openMap(lat, lng),
                      child: Text(
                        'View on Map',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfie(String? photoUrl) {
    Widget image = _photoPlaceholder();

    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        // Base64 encoded image
        try {
          final base64Str = photoUrl.split(',').last;
          final bytes = base64Decode(base64Str);
          image = Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {
          image = _photoPlaceholder();
        }
      } else {
        // Network URL — pass auth token in case the endpoint is protected
        image = CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          httpHeaders: _authToken != null
              ? {'Authorization': 'Bearer $_authToken'}
              : const {},
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, url, error) {
            debugPrint('ATT image error [$url]: $error');
            return _photoPlaceholder();
          },
        );
      }
    }

    return GestureDetector(
      onTap: photoUrl != null && photoUrl.isNotEmpty
          ? () => _showPhotoPreview(photoUrl)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: 56, height: 56, child: image),
      ),
    );
  }

  void _showPhotoPreview(String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  httpHeaders: _authToken != null
                      ? {'Authorization': 'Bearer $_authToken'}
                      : const {},
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.person, color: Colors.grey, size: 32),
      );

  Widget _buildTypeBadge(bool isIn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isIn
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isIn ? Colors.green : Colors.red,
          width: 0.8,
        ),
      ),
      child: Text(
        isIn ? 'In' : 'Out',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isIn ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Work Hours tab ────────────────────────────────────────────────────────

  Widget _buildWorkHoursTab() {
    final summaries = (_data?['workHoursSummary'] as List? ?? []);

    if (summaries.isEmpty) {
      return const Center(child: Text('No work hours data available.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        itemCount: summaries.length,
        itemBuilder: (_, i) => _buildWorkHoursCard(summaries[i]),
      ),
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _buildWorkHoursCard(Map<String, dynamic> s) {
    final scheduledMins = _toInt(s['scheduled_minutes']);
    final actualMins = _toInt(s['actual_minutes']);
    final scheduledDays = _toInt(s['scheduled_days']);
    final daysPresent = _toInt(s['days_present']);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s['name'] ?? 'Employee', style: AppTextStyles.h3),
            const Divider(height: 16),
            _buildSummaryRow(
              'Days Present',
              '$daysPresent / $scheduledDays days',
              Icons.calendar_today,
            ),
            _buildSummaryRow(
              'Actual Hours',
              _minsToHours(actualMins),
              Icons.access_time,
            ),
            _buildSummaryRow(
              'Scheduled Hours',
              _minsToHours(scheduledMins),
              Icons.schedule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _minsToHours(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
