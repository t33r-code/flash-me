import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/screens/sets/set_detail_screen.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';

enum _SortOrder { updated, name, cardCount }

// ---------------------------------------------------------------------------
// SetsScreen — outer shell with My Sets / Market tabs.
// ---------------------------------------------------------------------------
class SetsScreen extends ConsumerStatefulWidget {
  const SetsScreen({super.key});

  @override
  ConsumerState<SetsScreen> createState() => _SetsScreenState();
}

class _SetsScreenState extends ConsumerState<SetsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _SortOrder _sortOrder = _SortOrder.updated;

  @override
  void initState() {
    super.initState();
    // Listen for tab changes so we can show/hide the sort button and FAB.
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _onMySets => _tabController.index == 0;

  String get _sortLabel => switch (_sortOrder) {
        _SortOrder.updated => 'Last updated',
        _SortOrder.name => 'Name',
        _SortOrder.cardCount => 'Card count',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sets'),
        actions: [
          // Sort menu is only relevant on the My Sets tab.
          if (_onMySets)
            PopupMenuButton<_SortOrder>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort by',
              initialValue: _sortOrder,
              onSelected: (v) => setState(() => _sortOrder = v),
              itemBuilder: (_) => [
                _sortItem(_SortOrder.updated, 'Last updated', Icons.access_time),
                _sortItem(_SortOrder.name, 'Name', Icons.sort_by_alpha),
                _sortItem(_SortOrder.cardCount, 'Card count', Icons.numbers),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Sets'),
            Tab(text: 'Market'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MySetsTab(sortOrder: _sortOrder, sortLabel: _sortLabel),
          const _MarketTab(),
        ],
      ),
      // FAB is only shown on the My Sets tab.
      floatingActionButton: _onMySets
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetFormScreen()),
              ),
              tooltip: 'Create set',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  PopupMenuItem<_SortOrder> _sortItem(
          _SortOrder value, String label, IconData icon) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(label),
            if (_sortOrder == value) ...[
              const Spacer(),
              Icon(Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// My Sets tab — user's own sets with search, tag filter, and sort.
// ---------------------------------------------------------------------------
class _MySetsTab extends ConsumerStatefulWidget {
  final _SortOrder sortOrder;
  final String sortLabel;

  const _MySetsTab({required this.sortOrder, required this.sortLabel});

  @override
  ConsumerState<_MySetsTab> createState() => _MySetsTabState();
}

class _MySetsTabState extends ConsumerState<_MySetsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _allTags(List<CardSet> sets) {
    final tags = <String>{};
    for (final s in sets) {
      tags.addAll(s.tags);
    }
    return tags.toList()..sort();
  }

  List<CardSet> _filterAndSort(List<CardSet> sets) {
    var result = sets;
    if (_selectedTag != null) {
      result = result.where((s) => s.tags.contains(_selectedTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) => s.name.toLowerCase().contains(q)).toList();
    }
    switch (widget.sortOrder) {
      case _SortOrder.updated:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _SortOrder.name:
        result.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortOrder.cardCount:
        result.sort((a, b) => b.cardCount.compareTo(a.cardCount));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final setsAsync = ref.watch(userSetsProvider);
    final allSets = setsAsync.asData?.value ?? [];
    final allTags = _allTags(allSets);
    final displaySets = _filterAndSort(allSets);

    return Column(
      children: [
        // Search bar.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search sets…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),

        // Tag filter chips.
        if (allTags.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedTag == null,
                  onSelected: (_) => setState(() => _selectedTag = null),
                ),
                const SizedBox(width: 8),
                ...allTags.map((tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: _selectedTag == tag,
                        onSelected: (_) => setState(() =>
                            _selectedTag = _selectedTag == tag ? null : tag),
                      ),
                    )),
              ],
            ),
          ),

        // Active sort label — subtle indicator below the chips.
        if (allSets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Icon(Icons.sort,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  widget.sortLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

        Expanded(
          child: setsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Failed to load sets.')),
            data: (_) {
              if (allSets.isEmpty) return const _MySetsEmptyState();
              if (displaySets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No sets match your search.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: displaySets.length,
                itemBuilder: (ctx, i) => _SetTile(cardSet: displaySets[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state for My Sets tab.
// ---------------------------------------------------------------------------
class _MySetsEmptyState extends StatelessWidget {
  const _MySetsEmptyState();

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 80, color: onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No sets yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first set.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A single row in the My Sets list.
// ---------------------------------------------------------------------------
class _SetTile extends StatelessWidget {
  final CardSet cardSet;
  const _SetTile({required this.cardSet});

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (dt.year == now.year) return '${months[dt.month - 1]} ${dt.day}';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = cardSet.color != null ? _hexColor(cardSet.color!) : null;
    final count = cardSet.cardCount;
    final hasLanguage =
        cardSet.targetLanguage != null && cardSet.nativeLanguage != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SetDetailScreen(cardSet: cardSet),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coloured accent bar on the left edge.
              if (color != null)
                Container(width: 6, color: color)
              else
                const SizedBox(width: 6),

              // Left: name, description, tags.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardSet.name,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cardSet.description != null &&
                          cardSet.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cardSet.description!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (cardSet.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 0,
                          children: cardSet.tags
                              .take(3)
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    labelStyle: textTheme.labelSmall,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Right: market badge, language, card count, date.
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (cardSet.isPublic)
                          Tooltip(
                            message: 'Offered in Market',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront,
                                    size: 12, color: scheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  'In Market',
                                  style: textTheme.labelSmall
                                      ?.copyWith(color: scheme.primary),
                                ),
                              ],
                            ),
                          ),
                        if (hasLanguage)
                          Text(
                            '${cardSet.targetLanguage!.toUpperCase()} → ${cardSet.nativeLanguage!.toUpperCase()}',
                            style: textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        Text(
                          '$count card${count == 1 ? '' : 's'}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    Text(
                      _relativeDate(cardSet.updatedAt),
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, size: 20),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Market tab — browse all public sets from any creator.
// ---------------------------------------------------------------------------
class _MarketTab extends ConsumerStatefulWidget {
  const _MarketTab();

  @override
  ConsumerState<_MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends ConsumerState<_MarketTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _allTags(List<CardSet> sets) {
    final tags = <String>{};
    for (final s in sets) {
      tags.addAll(s.tags);
    }
    return tags.toList()..sort();
  }

  List<CardSet> _filter(List<CardSet> sets) {
    var result = sets;
    if (_selectedTag != null) {
      result = result.where((s) => s.tags.contains(_selectedTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) => s.name.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final setsAsync = ref.watch(publicSetsProvider);
    final allSets = setsAsync.asData?.value ?? [];
    final allTags = _allTags(allSets);
    final displaySets = _filter(allSets);

    return Column(
      children: [
        // Search bar.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search market…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),

        // Tag filter chips.
        if (allTags.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedTag == null,
                  onSelected: (_) => setState(() => _selectedTag = null),
                ),
                const SizedBox(width: 8),
                ...allTags.map((tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: _selectedTag == tag,
                        onSelected: (_) => setState(() =>
                            _selectedTag = _selectedTag == tag ? null : tag),
                      ),
                    )),
              ],
            ),
          ),

        Expanded(
          child: setsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Failed to load market.')),
            data: (_) {
              if (allSets.isEmpty) return const _MarketEmptyState();
              if (displaySets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No sets match your search.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: displaySets.length,
                itemBuilder: (ctx, i) =>
                    _MarketSetTile(cardSet: displaySets[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state for the Market tab.
// ---------------------------------------------------------------------------
class _MarketEmptyState extends StatelessWidget {
  const _MarketEmptyState();

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 80, color: onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Market is empty',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'No sets have been published yet.\nPublish your own from a set\'s detail screen.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A single row in the Market list — shows creator name and acquisition count.
// ---------------------------------------------------------------------------
class _MarketSetTile extends ConsumerWidget {
  final CardSet cardSet;
  const _MarketSetTile({required this.cardSet});

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = cardSet.color != null ? _hexColor(cardSet.color!) : null;
    final count = cardSet.cardCount;
    final hasLanguage =
        cardSet.targetLanguage != null && cardSet.nativeLanguage != null;

    // Fetch creator name; falls back to a plain uid while loading.
    final creatorAsync = ref.watch(creatorDisplayNameProvider(cardSet.userId));
    final creatorName = creatorAsync.asData?.value ?? '…';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coloured accent bar.
            if (color != null)
              Container(width: 6, color: color)
            else
              const SizedBox(width: 6),

            // Left: name, description, creator, tags.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardSet.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cardSet.description != null &&
                        cardSet.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cardSet.description!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Creator name row.
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          creatorName,
                          style: textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (cardSet.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: cardSet.tags
                            .take(3)
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  labelStyle: textTheme.labelSmall,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Right: language, card count, acquisition count.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasLanguage)
                        Text(
                          '${cardSet.targetLanguage!.toUpperCase()} → ${cardSet.nativeLanguage!.toUpperCase()}',
                          style: textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      Text(
                        '$count card${count == 1 ? '' : 's'}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  // Acquisition count with download icon.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_outlined,
                          size: 12, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '${cardSet.acquisitionCount}',
                        style: textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
