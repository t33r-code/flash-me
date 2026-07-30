import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/l10n/app_localizations.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/widgets/help_menu_button.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/set_acquisition_provider.dart';
import 'package:flash_me/screens/sets/clone_confirmation_screen.dart';
import 'package:flash_me/screens/sets/set_detail_screen.dart';
import 'package:flash_me/utils/layout_breakpoints.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';
import 'package:flash_me/widgets/context_menu.dart';
import 'package:flash_me/widgets/hover_highlight.dart';
import 'package:flash_me/widgets/set_actions.dart';

enum _SortOrder { updated, name, cardCount }

// Parses a CSS hex colour string (e.g. '#a1b2c3') into a Flutter Color.
Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('ff$h', radix: 16));
}

// Converts a DateTime to a short locale-aware relative date string.
String _formatRelativeDate(DateTime dt, AppLocalizations l10n) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return l10n.labelToday;
  if (diff == 1) return l10n.labelYesterday;
  final months = [
    l10n.labelMonthJan,
    l10n.labelMonthFeb,
    l10n.labelMonthMar,
    l10n.labelMonthApr,
    l10n.labelMonthMay,
    l10n.labelMonthJun,
    l10n.labelMonthJul,
    l10n.labelMonthAug,
    l10n.labelMonthSep,
    l10n.labelMonthOct,
    l10n.labelMonthNov,
    l10n.labelMonthDec,
  ];
  if (dt.year == now.year) return '${months[dt.month - 1]} ${dt.day}';
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSets),
        actions: [
          // Sort menu is only relevant on the My Sets tab.
          if (_onMySets)
            PopupMenuButton<_SortOrder>(
              icon: const Icon(Icons.sort),
              tooltip: l10n.tooltipSortBy,
              initialValue: _sortOrder,
              onSelected: (v) => setState(() => _sortOrder = v),
              itemBuilder: (_) => [
                _sortItem(
                  context,
                  _SortOrder.updated,
                  l10n.labelSortLastUpdated,
                  Icons.access_time,
                ),
                _sortItem(
                  context,
                  _SortOrder.name,
                  l10n.labelSortName,
                  Icons.sort_by_alpha,
                ),
                _sortItem(
                  context,
                  _SortOrder.cardCount,
                  l10n.labelSortCardCount,
                  Icons.numbers,
                ),
              ],
            ),
          const HelpMenuButton(HelpContext.sets),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.tabMySets),
            Tab(text: l10n.tabMarket),
          ],
        ),
      ),
      // The create-set FAB lives inside the My Sets list column
      // (_MySetsTab) so it stays clear of the detail pane's FAB on wide.
      body: TabBarView(
        controller: _tabController,
        children: [
          _MySetsTab(sortOrder: _sortOrder),
          const _MarketTab(),
        ],
      ),
    );
  }

  PopupMenuItem<_SortOrder> _sortItem(
    BuildContext context,
    _SortOrder value,
    String label,
    IconData icon,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(label),
        if (_sortOrder == value) ...[
          const Spacer(),
          Icon(
            Icons.check,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
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

  const _MySetsTab({required this.sortOrder});

  @override
  ConsumerState<_MySetsTab> createState() => _MySetsTabState();
}

class _MySetsTabState extends ConsumerState<_MySetsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag;
  // Set shown in the wide detail pane (#236); null = nothing selected.
  String? _selectedSetId;

  // Tapping a set: open its detail in the pane (wide) or push it (narrow).
  void _onSetTap(CardSet set, bool wide) {
    if (wide) {
      setState(() => _selectedSetId = set.id);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SetDetailScreen(cardSet: set)));
    }
  }

  // Right-click menu for a set tile (#237). Mirrors the set-detail toolbar's
  // management actions exactly, via the shared widgets/set_actions.dart so
  // both call sites do the same delete/export/publish flow.
  List<ContextMenuAction> _setContextActions(CardSet set) {
    final l10n = context.l10n;
    return [
      ContextMenuAction(
        icon: Icons.play_circle_outline,
        label: l10n.tooltipStudyThisSet,
        onSelected: () => openStudySetup(context, ref, set),
      ),
      ContextMenuAction(
        icon: set.isPublic
            ? Icons.unpublished_outlined
            : Icons.storefront_outlined,
        label: set.isPublic
            ? l10n.tooltipRemoveFromMarket
            : l10n.tooltipOfferInMarket,
        onSelected: () => toggleMarketPublish(context, ref, set),
      ),
      ContextMenuAction(
        icon: Icons.download_outlined,
        label: l10n.tooltipExportSet,
        onSelected: () => exportSetWithProgress(context, ref, set),
      ),
      ContextMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.tooltipEditSet,
        onSelected: () => openEditSet(context, set),
      ),
      ContextMenuAction(
        icon: Icons.delete_outline,
        label: l10n.tooltipDeleteSet,
        destructive: true,
        onSelected: () => deleteSetWithConfirm(context, ref, set),
      ),
    ];
  }

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
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortOrder.cardCount:
        result.sort((a, b) => b.cardCount.compareTo(a.cardCount));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setsAsync = ref.watch(userSetsProvider);
    final allSets = setsAsync.asData?.value ?? [];
    final allTags = _allTags(allSets);
    final displaySets = _filterAndSort(allSets);

    // Compute sort label from enum in build so context is available.
    final sortLabel = switch (widget.sortOrder) {
      _SortOrder.updated => l10n.labelSortLastUpdated,
      _SortOrder.name => l10n.labelSortName,
      _SortOrder.cardCount => l10n.labelSortCardCount,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        // Decide master-detail from the *window* width, matching MainScreen's
        // nav-rail breakpoint, so the two flip together — no middle state where
        // the rail is present but the set list has collapsed to single-column.
        final wide = isWideWidth(MediaQuery.sizeOf(context).width);
        final list = _buildListColumn(
          context,
          wide,
          setsAsync,
          allSets,
          displaySets,
          allTags,
          sortLabel,
        );

        if (!wide) return list;

        // Wide: master-detail — set list on the left, detail pane on the right.
        // The list gives width up to the pane's floor before it stops shrinking,
        // so even a just-wide layout keeps the pane usable (avoids overflow).
        final listWidth = (constraints.maxWidth - kMinDetailPaneWidth).clamp(
          kMinSetListWidth,
          kSetListWidth,
        );
        return Row(
          children: [
            SizedBox(width: listWidth, child: list),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _buildDetailPane(context, allSets)),
          ],
        );
      },
    );
  }

  // The set list (search + tiles) with a create-set FAB pinned to its corner.
  // Full-width on narrow; the left column on wide.
  Widget _buildListColumn(
    BuildContext context,
    bool wide,
    AsyncValue<List<CardSet>> setsAsync,
    List<CardSet> allSets,
    List<CardSet> displaySets,
    List<String> allTags,
    String sortLabel,
  ) {
    final l10n = context.l10n;
    return Stack(
      children: [
        Column(
          children: [
            _SetsSearchAndFilter(
              controller: _searchController,
              searchQuery: _searchQuery,
              hintText: l10n.hintSearchSets,
              allTags: allTags,
              selectedTag: _selectedTag,
              onSearch: (v) => setState(() => _searchQuery = v.trim()),
              onClearSearch: () => setState(() {
                _searchController.clear();
                _searchQuery = '';
              }),
              onTagSelected: (tag) => setState(() => _selectedTag = tag),
              // Sort indicator only shown when there are sets to sort.
              sortLabel: allSets.isNotEmpty ? sortLabel : null,
            ),
            Expanded(
              child: setsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text(l10n.errorFailedLoadSets)),
                data: (_) {
                  if (allSets.isEmpty) return const _MySetsEmptyState();
                  if (displaySets.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.messageNoSetsMatchSearch,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    // Bottom padding so the FAB doesn't cover the last tile.
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                    itemCount: displaySets.length,
                    itemBuilder: (ctx, i) {
                      final set = displaySets[i];
                      return _SetTile(
                        cardSet: set,
                        selected: wide && set.id == _selectedSetId,
                        onTap: () => _onSetTap(set, wide),
                        contextActions: () => _setContextActions(set),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        // Create-set FAB lives with the list (both layouts) so on wide it stays
        // clear of the detail pane's own FAB.
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'createSet',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SetFormScreen())),
            tooltip: l10n.tooltipCreateSet,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // The wide detail pane: the selected set's detail, or a placeholder.
  Widget _buildDetailPane(BuildContext context, List<CardSet> allSets) {
    final id = _selectedSetId;
    if (id != null) {
      final match = allSets.where((s) => s.id == id);
      if (match.isNotEmpty) {
        return SetDetailScreen(
          key: ValueKey(id),
          cardSet: match.first,
          onExit: () => setState(() => _selectedSetId = null),
        );
      }
    }
    return const _SetDetailPlaceholder();
  }
}

// Shown in the wide detail pane when no set is selected.
class _SetDetailPlaceholder extends StatelessWidget {
  const _SetDetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.messageSelectASet,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
            Icon(
              Icons.library_books_outlined,
              size: 80,
              color: onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.titleNoSetsYet,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.messageNoSetsHint,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
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
  final VoidCallback onTap;
  // Highlighted when this set is the one shown in the wide detail pane (#236).
  final bool selected;
  // Right-click menu (#237) — a builder (not a plain list) since the actions
  // close over `set` and are only ever needed if the user actually right-clicks.
  final List<ContextMenuAction> Function() contextActions;
  const _SetTile({
    required this.cardSet,
    required this.onTap,
    required this.contextActions,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = cardSet.color != null ? _hexColor(cardSet.color!) : null;
    final count = cardSet.cardCount;
    final hasLanguage =
        cardSet.targetLanguage != null && cardSet.nativeLanguage != null;

    return HoverHighlight(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        clipBehavior: Clip.antiAlias,
        color: selected ? scheme.secondaryContainer : null,
        child: InkWell(
          onTap: onTap,
          onSecondaryTapDown: (details) => showContextMenu(
            context,
            details.globalPosition,
            contextActions(),
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
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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
                                .map(
                                  (tag) => Chip(
                                    label: Text(tag),
                                    labelStyle: textTheme.labelSmall,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
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
                              message: l10n.tooltipOfferedInMarket,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.storefront,
                                    size: 12,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    l10n.labelInMarket,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (hasLanguage)
                            Text(
                              AppHelpers.formatLanguagePair(
                                cardSet.targetLanguage!,
                                cardSet.nativeLanguage!,
                              ),
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            l10n.labelCardCount(count),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatRelativeDate(cardSet.updatedAt, l10n),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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
    final l10n = context.l10n;
    final setsAsync = ref.watch(publicSetsProvider);
    final allSets = setsAsync.asData?.value ?? [];
    final allTags = _allTags(allSets);
    final displaySets = _filter(allSets);

    return Column(
      children: [
        _SetsSearchAndFilter(
          controller: _searchController,
          searchQuery: _searchQuery,
          hintText: l10n.hintSearchMarket,
          allTags: allTags,
          selectedTag: _selectedTag,
          onSearch: (v) => setState(() => _searchQuery = v.trim()),
          onClearSearch: () => setState(() {
            _searchController.clear();
            _searchQuery = '';
          }),
          onTagSelected: (tag) => setState(() => _selectedTag = tag),
        ),

        Expanded(
          child: setsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(l10n.errorFailedLoadMarket)),
            data: (_) {
              if (allSets.isEmpty) return const _MarketEmptyState();
              if (displaySets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.messageNoSetsMatchSearch,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
            Text(
              context.l10n.titleMarketEmpty,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.messageMarketEmpty,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = cardSet.color != null ? _hexColor(cardSet.color!) : null;
    final count = cardSet.cardCount;
    final hasLanguage =
        cardSet.targetLanguage != null && cardSet.nativeLanguage != null;

    // Denormalized onto the set at publish time (#297) — never a client read
    // of another user's private users/{uid} doc. Falls back to '…' for sets
    // published before this field existed (see the backfill migration script).
    final creatorName = cardSet.authorDisplayName ?? '…';

    // Look up whether the current user has already acquired this set.
    final acquisitions =
        ref.watch(userAcquisitionsProvider).asData?.value ?? {};
    final acquisition = acquisitions[cardSet.id];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CloneConfirmationScreen(
              marketSet: cardSet,
              creatorDisplayName: creatorName,
            ),
          ),
        ),
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
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Creator name row.
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            creatorName,
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  labelStyle: textTheme.labelSmall,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
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
                            AppHelpers.formatLanguagePair(
                              cardSet.targetLanguage!,
                              cardSet.nativeLanguage!,
                            ),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          l10n.labelCardCount(count),
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Acquisition count with download icon.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_outlined,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${cardSet.acquisitionCount}',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        // "Cloned on …" / "Subscribed on …" badge.
                        if (acquisition != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 12,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                acquisition.acquisitionType == 'subscription'
                                    ? l10n.labelAcquiredSubscribed(
                                        _formatRelativeDate(
                                          acquisition.acquiredAt,
                                          l10n,
                                        ),
                                      )
                                    : l10n.labelAcquiredCloned(
                                        _formatRelativeDate(
                                          acquisition.acquiredAt,
                                          l10n,
                                        ),
                                      ),
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ), // IntrinsicHeight
      ), // InkWell
    );
  }
}

// ---------------------------------------------------------------------------
// Shared search bar + tag filter chips used by both the My Sets and Market
// tabs.  [sortLabel], when non-null, adds a subtle active-sort indicator row
// below the chips (My Sets tab only; pass null to suppress it).
// ---------------------------------------------------------------------------
class _SetsSearchAndFilter extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final String hintText;
  final List<String> allTags;
  final String? selectedTag;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onTagSelected;
  final String? sortLabel;

  const _SetsSearchAndFilter({
    required this.controller,
    required this.searchQuery,
    required this.hintText,
    required this.allTags,
    required this.selectedTag,
    required this.onSearch,
    required this.onClearSearch,
    required this.onTagSelected,
    this.sortLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search field.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
            onChanged: onSearch,
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
                  label: Text(l10n.labelAll),
                  selected: selectedTag == null,
                  onSelected: (_) => onTagSelected(null),
                ),
                const SizedBox(width: 8),
                ...allTags.map(
                  (tag) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tag),
                      selected: selectedTag == tag,
                      // Toggle off if the same tag is tapped again.
                      onSelected: (_) =>
                          onTagSelected(selectedTag == tag ? null : tag),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Active sort label — My Sets tab only.
        if (sortLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Icon(Icons.sort, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  sortLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
