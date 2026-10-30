import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/notifications/seed_fingerprint.dart';
import 'package:poolcoachai/domain/skill_category.dart';

BigInt _fnvFull(String s) {
  var h = BigInt.from(0x811c9dc5);
  for (final u in s.codeUnits) {
    h = ((h ^ BigInt.from(u)) * BigInt.from(0x01000193)) &
        BigInt.from(0xffffffff);
  }
  return h;
}

String _fp(List<Drill> d, List<KnowledgeArticle> k) =>
    seedFingerprint(drills: d, knowledge: k);

Drill _drill({
  String id = 'a',
  String name = 'A',
  int level = 1,
  double? pass = 0.8,
  num? target,
  List<String> steps = const ['s'],
  String goal = 'g',
}) =>
    Drill(
      id: id,
      cat: SkillCategory.aiming,
      name: name,
      level: level,
      unit: 'u',
      goal: goal,
      steps: steps,
      passThreshold: pass,
      target: target,
    );

// Bộ riêng của test này (không nạp test_data.dart: bước Chrome của CI phải
// chỉ biên dịch phần domain nhỏ).
final _drills = [
  _drill(id: 'a', name: 'A', pass: 0.8),
  _drill(id: 'b', name: 'B', level: 3, pass: null, target: 30.5),
  _drill(id: 'c', name: 'Cà phê', level: 2, pass: 0.333),
];
final _knowledge = [
  const KnowledgeArticle(
    id: 'k1',
    cat: SkillCategory.aiming,
    title: 't',
    body: 'b',
    relatedDrillIds: ['a', 'b'],
  ),
  const KnowledgeArticle(
    id: 'k2',
    cat: SkillCategory.aiming,
    title: 't2',
    body: 'b2',
  ),
];

void main() {
  test('dấu vân tay: theo đúng dạng chuẩn', () {
    final canonical = [
      'r|$recommendationLogicVersion',
      for (final d in _drills)
        'd|${d.id}|${d.cat.name}|${d.name}|${d.level}|'
            '${d.passThreshold == null ? '' : (d.passThreshold! * 1000).round()}|'
            '${d.target == null ? '' : (d.target! * 1000).round()}',
      for (final k in _knowledge)
        'k|${k.id}|${k.cat.name}|${k.relatedDrillIds.join(',')}',
    ].join('\n');
    final hex = _fnvFull(canonical).toRadixString(16).padLeft(8, '0');
    expect(
      _fp(_drills, _knowledge),
      'v1-${_drills.length}-${_knowledge.length}-$hex',
    );
    expect(
      _fp(_drills, _knowledge),
      matches(RegExp(r'^v1-\d+-\d+-[0-9a-f]{8}$')),
    );
  });

  test('đổi thứ tự, tên, cấp, ngưỡng, target hoặc liên kết bài đọc: dấu đổi',
      () {
    final a = _drill(id: 'a');
    final b = _drill(id: 'b', name: 'B');
    final k = [
      const KnowledgeArticle(
        id: 'k',
        cat: SkillCategory.aiming,
        title: 't',
        body: 'b',
        relatedDrillIds: ['a'],
      ),
    ];
    final base = _fp([a, b], k);
    expect(_fp([b, a], k), isNot(base));
    expect(_fp([a, _drill(id: 'b', name: 'B2')], k), isNot(base));
    expect(_fp([a, _drill(id: 'b', name: 'B', level: 2)], k), isNot(base));
    expect(_fp([a, _drill(id: 'b', name: 'B', pass: 0.9)], k), isNot(base));
    expect(
      _fp([a, _drill(id: 'b', name: 'B', pass: null, target: 30)], k),
      isNot(base),
    );
    expect(
      _fp([
        a,
        b
      ], [
        const KnowledgeArticle(
          id: 'k',
          cat: SkillCategory.aiming,
          title: 't',
          body: 'b',
          relatedDrillIds: ['a', 'b'],
        ),
      ]),
      isNot(base),
    );
  });

  test('đổi bước tập hay mục tiêu chữ: dấu giữ nguyên', () {
    final k = <KnowledgeArticle>[];
    expect(
      _fp([_drill()], k),
      _fp([_drill(steps: ['x', 'y'], goal: 'khác')], k),
    );
  });
  test('đổi phiên bản logic gợi ý: dấu đổi dù seed y nguyên', () {
    final now = seedFingerprint(drills: _drills, knowledge: _knowledge);
    expect(
      seedFingerprint(
        drills: _drills,
        knowledge: _knowledge,
        logicVersion: recommendationLogicVersion + 1,
      ),
      isNot(now),
    );
    expect(
      seedFingerprint(
        drills: _drills,
        knowledge: _knowledge,
        logicVersion: recommendationLogicVersion,
      ),
      now,
    );
  });
}
