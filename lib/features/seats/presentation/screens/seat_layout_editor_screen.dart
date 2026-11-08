import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../data/models/seat_layout_model.dart';
import '../providers/seat_provider.dart';

class SeatLayoutEditorScreen extends ConsumerStatefulWidget {
  const SeatLayoutEditorScreen({super.key});

  @override
  ConsumerState<SeatLayoutEditorScreen> createState() =>
      _SeatLayoutEditorScreenState();
}

class _SeatLayoutEditorScreenState
    extends ConsumerState<SeatLayoutEditorScreen> {
  int _rows = 6;
  int _cols = 5;
  String _selectedCategory = 'Normal';
  final List<List<SeatLayoutCell>> _grid = [];
  SeatLayoutCell? _selectedSeat;
  bool _isEditing = false;
  bool _layoutLoaded = false;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _applyLayout(SeatLayoutModel? savedLayout) {
    if (savedLayout != null && !_layoutLoaded) {
      _layoutLoaded = true;
      _rows = savedLayout.rows;
      _cols = savedLayout.cols;
      _grid.clear();
      int cellIndex = 0;
      for (int r = 0; r < _rows; r++) {
        final row = <SeatLayoutCell>[];
        for (int c = 0; c < _cols; c++) {
          if (cellIndex < savedLayout.cells.length) {
            row.add(savedLayout.cells[cellIndex]);
          } else {
            row.add(SeatLayoutCell(
              id: '${r}_$c',
              label: '${String.fromCharCode(65 + r)}${c + 1}',
              category: _selectedCategory,
              status: 'available',
            ));
          }
          cellIndex++;
        }
        _grid.add(row);
      }
    }
  }

  void _initGrid() {
    _grid.clear();
    for (int r = 0; r < _rows; r++) {
      final row = <SeatLayoutCell>[];
      for (int c = 0; c < _cols; c++) {
        row.add(SeatLayoutCell(
          id: '${r}_$c',
          label: '${String.fromCharCode(65 + r)}${c + 1}',
          category: _selectedCategory,
          status: 'available',
        ));
      }
      _grid.add(row);
    }
  }

  void _onSeatTap(int row, int col) {
    setState(() {
      if (_isEditing) {
        // Toggle seat status
        final seat = _grid[row][col];
        if (seat.status == 'available') {
          _grid[row][col] = seat.copyWith(status: 'maintenance');
        } else if (seat.status == 'maintenance') {
          _grid[row][col] = seat.copyWith(status: 'removed');
        } else {
          _grid[row][col] = seat.copyWith(status: 'available');
        }
      } else {
        _selectedSeat = _grid[row][col];
      }
    });
  }

  Future<void> _saveLayout() async {
    final allCells = _grid.expand((row) => row).toList();
    final layout = SeatLayoutModel(
      layoutId: 'current',
      libraryId: '',
      rows: _rows,
      cols: _cols,
      cells: allCells,
      updatedAt: DateTime.now(),
    );

    await ref.read(seatLayoutRepositoryProvider).saveLayout(layout);
  }

  @override
  Widget build(BuildContext context) {
    final available = _grid
        .expand((r) => r)
        .where((s) => s.status == 'available')
        .length;
    final maintenance = _grid
        .expand((r) => r)
        .where((s) => s.status == 'maintenance')
        .length;
    final removed = _grid
        .expand((r) => r)
        .where((s) => s.status == 'removed')
        .length;

    // Watch the layout stream from Firestore
    final layoutAsync = ref.watch(seatLayoutProvider);
    layoutAsync.whenData(_applyLayout);

    if (!_layoutLoaded && layoutAsync.isLoading) {
      return Scaffold(
        body: Container(
          color: context.scaffoldBg,
          child: const Center(
            child:
                CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => context.pop()),
                    const SizedBox(width: 8),
                    Text('Seat Layout Editor',
                        style: AppTypography.headlineSmall),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_isEditing
                          ? Icons.check_rounded
                          : Icons.edit_rounded),
                      onPressed: () =>
                          setState(() => _isEditing = !_isEditing),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            _isEditing ? AppColors.accent : context.cardBg,
                      ),
                    ),
                  ],
                ),
              ),
              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _SizeControl(
                      label: 'Rows',
                      value: _rows,
                      onIncrease: () {
                        if (_rows < 10) {
                          setState(() {
                            _rows++;
                            _initGrid();
                          });
                        }
                      },
                      onDecrease: () {
                        if (_rows > 1) {
                          setState(() {
                            _rows--;
                            _initGrid();
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    _SizeControl(
                      label: 'Cols',
                      value: _cols,
                      onIncrease: () {
                        if (_cols < 8) {
                          setState(() {
                            _cols++;
                            _initGrid();
                          });
                        }
                      },
                      onDecrease: () {
                        if (_cols > 1) {
                          setState(() {
                            _cols--;
                            _initGrid();
                          });
                        }
                      },
                    ),
                    const Spacer(),
                    // Category selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        isDense: true,
                        dropdownColor: context.cardBg,
                        items: ['Normal', 'AC', 'Premium', 'Cabin']
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: AppTypography.labelSmall)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategory = v!),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    _LegendDot(
                        color: AppColors.accent,
                        label: 'Available ($available)'),
                    _LegendDot(
                        color: AppColors.warning,
                        label: 'Maintenance ($maintenance)'),
                    _LegendDot(
                        color: AppColors.error,
                        label: 'Removed ($removed)'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Grid
              Expanded(
                child: InteractiveViewer(
                  maxScale: 2.5,
                  minScale: 0.5,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_rows, (r) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_cols, (c) {
                              final seat = _grid[r][c];
                              final isSelected =
                                  _selectedSeat?.id == seat.id;
                              Color color;
                              switch (seat.status) {
                                case 'available':
                                  color = AppColors.accent;
                                  break;
                                case 'occupied':
                                  color = AppColors.error;
                                  break;
                                case 'maintenance':
                                  color = AppColors.warning;
                                  break;
                                case 'removed':
                                  color = context.textTertiaryColor;
                                  break;
                                default:
                                  color = AppColors.accent;
                              }

                              return GestureDetector(
                                onTap: () => _onSeatTap(r, c),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: 56,
                                  height: 56,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : color.withValues(alpha: 0.4),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        seat.status == 'removed'
                                            ? Icons
                                                .remove_circle_outline_rounded
                                            : Icons.chair_rounded,
                                        size: 18,
                                        color: color,
                                      ),
                                      Text(
                                        seat.label,
                                        style: TextStyle(
                                            color: color,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Save button
              Padding(
                padding: const EdgeInsets.all(20),
                child: NeonButton(
                  text: 'Save Layout ($available seats)',
                  onPressed: () async {
                    await _saveLayout();
                    if (context.mounted) {
                      context.showSuccess(
                          'Layout saved with $available seats');
                      context.pop();
                    }
                  },
                  width: double.infinity,
                  icon: Icons.save_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SizeControl extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _SizeControl({
    required this.label,
    required this.value,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: AppTypography.labelMedium),
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 18),
          onPressed: onDecrease,
          style: IconButton.styleFrom(
            backgroundColor: context.cardBg,
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$value', style: AppTypography.labelLarge),
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 18),
          onPressed: onIncrease,
          style: IconButton.styleFrom(
            backgroundColor: context.cardBg,
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSmall),
      ],
    );
  }
}
