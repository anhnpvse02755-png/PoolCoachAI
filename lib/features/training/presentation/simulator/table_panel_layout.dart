import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_layout.dart';
import 'package:poolcoachai/core/widgets/pc_fab_inset.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Cách chia thân màn: bàn cạnh bảng hay bàn trên bảng, cỡ bàn, bề rộng
/// bảng. Khi xếp chồng, bảng rộng bằng thân màn.
typedef TablePanelArrangement = ({
  bool sideBySide,
  Size table,
  double panelWidth,
});

/// Bàn bi và bảng điều khiển cuộn được — màn mô phỏng, màn Kế hoạch dọn bàn
/// và màn tình huống của Coach dùng chung (spec 2026-10-07 mục 6: cùng cái
/// bàn, cùng kích thước).
///
/// Hai cách xếp, theo quyết định D5 của kế hoạch responsive:
/// - **Cạnh nhau** khi thân màn rộng từ [AppLayout.mediumWidth] và rộng gấp
///   ít nhất [sideBySideMinAspect] lần chiều cao — điện thoại ngang, cửa sổ
///   máy tính: bàn bên trái, bảng bên phải cao hết thân màn.
/// - **Chồng nhau** trong mọi trường hợp khác — điện thoại dọc, máy tính
///   bảng dọc, cửa sổ gần vuông: bàn trên, bảng dưới, như trước giờ.
///
/// Bàn luôn nằm ngoài vùng cuộn: kéo trên bàn là kéo bi, không cuộn trang.
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

  /// Lề quanh bàn khi xếp chồng — cỡ bàn tính trên phần còn lại sau lề này.
  static const tablePadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  /// Khi xếp chồng, bàn cao tối đa ngần này phần chiều cao thân màn.
  static const maxTableShare = 0.55;

  /// Thân màn rộng gấp ít nhất ngần này lần chiều cao thì bàn đứng cạnh
  /// bảng. Cửa sổ máy tính từ 900 px trở lên đều đạt (Coach spec mục 4.3);
  /// máy tính bảng dọc thì không, và bàn của nó to nhất khi xếp chồng.
  static const sideBySideMinAspect = 1.3;

  /// Khi đứng cạnh, bảng chiếm ngần này phần bề ngang thân màn, kẹp trong
  /// [sidePanelMinWidth]–[sidePanelMaxWidth].
  static const sidePanelShare = 0.4;
  static const sidePanelMinWidth = 320.0;
  static const sidePanelMaxWidth = 440.0;

  /// Lề quanh bàn khi đứng cạnh bảng.
  static const sideTablePadding = EdgeInsets.all(16);

  /// Chia thân màn [body] cho bàn có tỉ lệ ngang/dọc [aspectRatio] và bảng.
  ///
  /// Thân màn cao vô hạn cho tỉ lệ 0, nên vẫn xếp chồng đúng như trước.
  static TablePanelArrangement arrange(Size body, double aspectRatio) {
    final sideBySide =
        body.width >= AppLayout.mediumWidth &&
        body.width / body.height >= sideBySideMinAspect;
    if (sideBySide) {
      final panelWidth = (body.width * sidePanelShare).clamp(
        sidePanelMinWidth,
        sidePanelMaxWidth,
      );
      final height = math.max(
        0.0,
        math.min(
          (body.width - panelWidth - sideTablePadding.horizontal) / aspectRatio,
          body.height - sideTablePadding.vertical,
        ),
      );
      return (
        sideBySide: true,
        table: Size(height * aspectRatio, height),
        panelWidth: panelWidth,
      );
    }
    // Trên Chrome desktop cửa sổ ngang hơn dọc: bàn cao theo bề ngang mà
    // không có trần thì tràn và bảng điều khiển biến mất. Bàn cao bằng cái
    // nhỏ hơn giữa "vừa bề ngang" và "tối đa 55% thân màn", tính trên phần
    // còn lại sau lề của bàn — tính theo cả bề ngang thì bàn méo tỉ lệ.
    final width = math.max(0.0, body.width - tablePadding.horizontal);
    final maxHeight = math.max(
      0.0,
      body.height * maxTableShare - tablePadding.vertical,
    );
    final height = math.min(width / aspectRatio, maxHeight);
    return (
      sideBySide: false,
      table: Size(height * aspectRatio, height),
      panelWidth: body.width,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bodyConstraints) {
        final arrangement = arrange(
          bodyConstraints.biggest,
          TableLayout.aspectRatio(table),
        );
        final tableBox = SizedBox.fromSize(
          size: arrangement.table,
          child: LayoutBuilder(
            builder: (context, constraints) => tableBuilder(
              TableLayout(size: constraints.biggest, table: table),
            ),
          ),
        );

        if (arrangement.sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: sideTablePadding,
                  child: Align(alignment: Alignment.topCenter, child: tableBox),
                ),
              ),
              SizedBox(
                width: arrangement.panelWidth,
                child: SingleChildScrollView(
                  padding: pcScrollPadding(
                    context,
                    const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  ),
                  child: panel,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: tablePadding,
              child: Center(child: tableBox),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: pcScrollPadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }
}
