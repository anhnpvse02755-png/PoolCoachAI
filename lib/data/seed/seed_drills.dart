import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Mười bài tập khởi tạo.
///
/// Nội dung lấy từ prototype `Claude_desktop/poolcoachai-reference.html`,
/// **thuật ngữ thì không**. Prototype viết trước đợt chủ sản phẩm sửa
/// từ vựng, nên chép nguyên văn sẽ kéo lại toàn bộ từ sai. Test trong
/// `test/data/seed_test.dart` làm hỏng build nếu một từ cũ quay lại.
const seedDrills = <Drill>[
  Drill(
    id: 'd1',
    cat: SkillCategory.aiming,
    name: 'Đường thẳng cơ bản',
    level: 1,
    unit: 'lần trúng / 10',
    passThreshold: 0.8,
    goal: 'Đánh thẳng bi cái vào bi mục tiêu tới lỗ mà không lệch hướng.',
    steps: [
      'Đặt bi mục tiêu cách lỗ khoảng 20cm, thẳng hàng với bi cái.',
      'Đặt bi cái cách bi mục tiêu 40–60cm trên cùng một đường thẳng.',
      'Ngắm giữa tâm bi, đánh nhẹ và giữ cơ thẳng khi tiếp xúc.',
      'Thực hiện 10 lần, ghi lại số lần bi vào lỗ.',
    ],
  ),
  Drill(
    id: 'd2',
    cat: SkillCategory.aiming,
    name: 'Bi ảo — 15 góc cắt',
    level: 3,
    unit: 'lần trúng / 15',
    passThreshold: 0.6,
    goal: 'Luyện cảm giác góc cắt từ 10° đến 70° bằng phương pháp bi ảo.',
    steps: [
      'Đặt bi mục tiêu ở 15 vị trí khác nhau quanh một lỗ, mỗi vị trí một '
          'góc cắt khác nhau.',
      'Hình dung "bi ảo" — vị trí bi cái cần chạm tới ngay trước khi tiếp '
          'xúc bi mục tiêu.',
      'Ngắm tâm bi cái vào tâm bi ảo, đánh nhẹ.',
      'Ghi lại số góc cắt thực hiện thành công.',
    ],
  ),
  Drill(
    id: 'd3',
    cat: SkillCategory.position,
    name: 'Đánh đứng bi',
    level: 2,
    unit: 'lần đạt / 10',
    passThreshold: 0.7,
    goal: 'Bi cái đứng lại đúng vị trí tiếp xúc sau khi đánh bi mục tiêu '
        'vào lỗ.',
    steps: [
      'Đặt bi mục tiêu cách lỗ 30cm, bi cái cách bi mục tiêu 50cm.',
      'Đánh vào tâm bi cái (không xoáy lên/xuống), lực vừa phải.',
      'Bi cái phải đứng lại gần như ngay tại điểm va chạm.',
      'Lặp lại 10 lần, tính số lần bi cái đứng trong bán kính 5cm.',
    ],
  ),
  Drill(
    id: 'd4',
    cat: SkillCategory.position,
    name: 'Đánh trô bi',
    level: 3,
    unit: 'khoảng cách trô (cm)',
    target: 25,
    goal: 'Luyện đánh trô để bi cái lùi lại sau khi tiếp xúc bi mục tiêu.',
    steps: [
      'Đặt bi mục tiêu cách bi cái 50cm, thẳng hàng tới lỗ.',
      'Đánh vào 1/3 dưới bi cái, giữ cơ thấp và theo cơ hết đà.',
      'Đo khoảng cách bi cái lùi lại sau khi chạm bi mục tiêu.',
      'Thực hiện 8 lần, ghi khoảng cách trô trung bình.',
    ],
  ),
  Drill(
    id: 'd5',
    cat: SkillCategory.position,
    name: 'Đánh cu lê',
    level: 2,
    unit: 'khoảng cách cu lê (cm)',
    target: 25,
    goal: 'Luyện đánh cu lê để bi cái tiến lên theo hướng bi mục tiêu sau '
        'va chạm.',
    steps: [
      'Đặt bi mục tiêu cách bi cái 50cm, thẳng hàng tới lỗ.',
      'Đánh vào 1/3 trên bi cái với lực vừa phải.',
      'Quan sát bi cái lăn tiếp theo hướng bi mục tiêu sau va chạm.',
      'Thực hiện 8 lần, ghi khoảng cách bi cái tiến thêm.',
    ],
  ),
  Drill(
    id: 'd6',
    cat: SkillCategory.breakShot,
    name: 'Phá 9 bi chuẩn',
    level: 3,
    unit: 'số bi vào / lần phá',
    target: 1,
    goal: 'Phá mạnh, đều và kiểm soát bi cái ở giữa bàn sau khi phá.',
    steps: [
      'Xếp rack 9 bi chuẩn, bi cái đặt ở vị trí phá quen thuộc.',
      'Đánh vào bi đầu rack với lực tối đa nhưng vẫn kiểm soát được cơ.',
      'Quan sát bi cái đứng lại — mục tiêu là gần giữa bàn.',
      'Thực hiện 5 lần phá, ghi số bi rơi lỗ mỗi lần.',
    ],
  ),
  Drill(
    id: 'd7',
    cat: SkillCategory.safety,
    name: 'Đẩy sát băng — an toàn cơ bản',
    level: 2,
    unit: 'lần thành công / 10',
    passThreshold: 0.7,
    goal: 'Đưa bi cái ép sát băng để gây khó cho đối thủ.',
    steps: [
      'Đặt bi mục tiêu gần băng, bi cái ở giữa bàn.',
      'Đánh nhẹ để bi mục tiêu chạm băng và bi cái đi theo, đứng sát băng '
          'đối diện.',
      'Kiểm tra khoảng cách bi cái tới băng sau cú đánh.',
      'Lặp lại 10 lần, tính số lần bi cái đứng trong 15cm từ băng.',
    ],
  ),
  // Prototype gắn bài này vào `kick`, nhưng mục tiêu của nó là cho **bi
  // mục tiêu** phản băng rồi vào lỗ — đó là bank shot, tức Cân bi, chứ
  // không phải A băng. Chủ sản phẩm chốt lối B ngày 18/09/2026: mở nhóm
  // thứ sáu thay vì nhét chung, vì gộp lại sẽ khiến `weakestSkill()`
  // quy lỗi Cân bi thành yếu A băng rồi giao sai bài tập.
  Drill(
    id: 'd8',
    cat: SkillCategory.bank,
    name: 'Cân bi một băng vào lỗ',
    level: 4,
    unit: 'lần trúng / 10',
    passThreshold: 0.5,
    goal: 'Luyện đánh bi mục tiêu phản qua một băng rồi vào lỗ.',
    steps: [
      'Đặt bi mục tiêu ở vị trí cần phản băng để vào lỗ góc.',
      'Tính điểm phản xạ trên băng bằng quy tắc góc tới = góc phản xạ.',
      'Ngắm bi cái vào điểm đó với lực vừa phải.',
      'Thực hiện 10 lần, ghi số lần bi vào lỗ.',
    ],
  ),
  Drill(
    id: 'd9',
    cat: SkillCategory.kick,
    name: 'A băng thoát chắn',
    level: 4,
    unit: 'lần chạm hợp lệ / 10',
    passThreshold: 0.5,
    goal: 'Luyện đưa bi cái phản băng để chạm bi mục tiêu khi bị chắn.',
    steps: [
      'Đặt một bi chắn giữa bi cái và bi mục tiêu.',
      'Tính đường bi cái phản qua 1–2 băng để vòng tới bi mục tiêu.',
      'Đánh với lực đều, không xoáy mạnh.',
      'Ghi số lần bi cái chạm được bi mục tiêu hợp lệ.',
    ],
  ),
  Drill(
    id: 'd10',
    cat: SkillCategory.position,
    name: 'Đánh đứng bi liên hoàn — tốc độ',
    level: 3,
    unit: 'số lần đúng trong 60s',
    target: 4,
    goal: 'Luyện tốc độ và độ chính xác của cú đánh đứng bi dưới áp lực '
        'thời gian.',
    steps: [
      'Xếp 5 bi mục tiêu quanh bàn, mỗi bi gần một lỗ khác nhau.',
      'Trong 60 giây, đánh lần lượt từng bi bằng cú đánh đứng bi, cho bi '
          'cái đứng đúng vị trí.',
      'Đặt lại bi cái nhanh khi cần, tiếp tục cho tới hết giờ.',
      'Ghi số bi hoàn thành đúng kỹ thuật trong thời gian.',
    ],
  ),
];
