import 'package:flutter/material.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Bàn ở trên, bảng điều khiển cuộn được ở dưới — màn mô phỏng và màn Kế
/// hoạch dọn bàn dùng chung (spec 2026-10-07 mục 6: cùng cái bàn, cùng
/// kích thước).
///
/// Bàn nằm ngoài vùng cuộn: kéo dọc trên bàn là kéo bi, không cuộn trang.
class TablePanelLayout extends StatelessWidget {
  const TablePanelLayout({
    required this.table,
    required this.tableBuilder,
    required this.panel,
    super.key,
  });

  final TableSpec table;

  /// Dựng bàn trên đúng khung đã chia; [TableLayout] khớp kích thước khung.
  final Widget Function(TableLayout layout) tableBuilder;
  final Widget panel;

  /// Lề quanh bàn — kích thước bàn tính trên phần còn lại sau lề này.
  static const tablePadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  /// Bàn cao tối đa ngần này phần chiều cao thân màn.
  static const maxTableShare = 0.55;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bodyConstraints) {
        // Trên Chrome desktop, cửa sổ ngang hơn dọc: bàn cao theo chiều
        // rộng mà không trần thì tràn RenderFlex và bảng điều khiển biến
        // mất. Ghim chiều cao bàn theo cái nhỏ hơn giữa "vừa bề ngang" và
        // "tối đa 55% chiều cao thân màn" — còn lại luôn dành cho bảng.
        //
        // Trần tính trên phần còn lại sau Padding của bàn: tính theo cả bề
        // ngang thì SizedBox bị ép hẹp mà giữ chiều cao, bàn méo tỉ lệ.
        final aspectRatio = TableLayout.aspectRatio(table);
        final availableWidth = (bodyConstraints.maxWidth - tablePadding.horizontal)
            .clamp(0.0, double.infinity);
        final maxTableHeight =
            (bodyConstraints.maxHeight * maxTableShare - tablePadding.vertical)
                .clamp(0.0, double.infinity);
        final widthLimitedHeight = availableWidth / aspectRatio;
        final tableHeight =
            widthLimitedHeight < maxTableHeight ? widthLimitedHeight : maxTableHeight;

        return Column(
          children: [
            Padding(
              padding: tablePadding,
              child: Center(
                child: SizedBox(
                  width: tableHeight * aspectRatio,
                  height: tableHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        tableBuilder(TableLayout(size: constraints.biggest, table: table)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }
}
