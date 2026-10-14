import 'package:poolcoachai/domain/rank.dart';

/// Kích thước bàn khi làm bài (spec mục 7.3 bước 1).
enum TableSize { sevenFoot, eightFoot, nineFootPlus }

/// Ba bản Đề II của BU.
enum ExamIIVersion { bachelors, masters, doctorate }

const examIMax = 100;
const buTotalMax = 200;

/// Điểm Đề I xếp bản Đề II (BU_Exam_Instructions.pdf trang 1 mục 5).
///
/// Bản Doctorate phải đánh trên bàn 9 feet trở lên; bàn nhỏ hơn mà Đề I đạt
/// mức Doctorate thì làm bản Masters.
ExamIIVersion placeExamII(int examIScore, TableSize table) {
  RangeError.checkValueInInterval(examIScore, 0, examIMax, 'examIScore');
  if (examIScore <= 49) return ExamIIVersion.bachelors;
  if (examIScore <= 69) return ExamIIVersion.masters;
  return table == TableSize.nineFootPlus
      ? ExamIIVersion.doctorate
      : ExamIIVersion.masters;
}

/// Một dòng của bảng quy đổi BU sang hạng (spec mục 5.4).
///
/// [buLevels] và [fargo] là chữ của BU_Rating_Comparisons.pdf, giữ nguyên
/// tiếng Anh vì đó là tên mức của BU.
final class BuRankBand {
  const BuRankBand({
    required this.rank,
    required this.min,
    required this.max,
    required this.buLevels,
    required this.fargo,
  });

  final Rank rank;
  final int min;
  final int max;
  final String buLevels;
  final String fargo;
}

/// Bảng chủ sản phẩm chốt ngày 14/10/2026: chỉ gộp các mức có sẵn của BU.
const buRankBands = <BuRankBand>[
  BuRankBand(rank: Rank.k, min: 0, max: 19, buLevels: 'novice', fargo: '< 200'),
  BuRankBand(rank: Rank.i, min: 20, max: 39, buLevels: 'lower + mid beginner', fargo: '200–299'),
  BuRankBand(rank: Rank.h, min: 40, max: 69, buLevels: 'upper beginner + lower intermediate', fargo: '300–399'),
  BuRankBand(rank: Rank.g, min: 70, max: 94, buLevels: 'mid intermediate', fargo: '400–449'),
  BuRankBand(rank: Rank.f, min: 95, max: 109, buLevels: 'upper intermediate', fargo: '450–499'),
  BuRankBand(rank: Rank.e, min: 110, max: 124, buLevels: 'lower advanced', fargo: '500–549'),
  BuRankBand(rank: Rank.d, min: 125, max: 139, buLevels: 'mid advanced', fargo: '550–599'),
  BuRankBand(rank: Rank.c, min: 140, max: 154, buLevels: 'upper advanced', fargo: '600–649'),
  BuRankBand(rank: Rank.b, min: 155, max: 174, buLevels: 'lower + upper shortstop', fargo: '650–729'),
  BuRankBand(rank: Rank.a, min: 175, max: 200, buLevels: 'semipro/pro + world class pro', fargo: '≥ 730'),
];

BuRankBand bandForBuScore(int total) {
  RangeError.checkValueInInterval(total, 0, buTotalMax, 'total');
  return buRankBands.firstWhere((b) => total >= b.min && total <= b.max);
}

Rank rankForBuScore(int total) => bandForBuScore(total).rank;
