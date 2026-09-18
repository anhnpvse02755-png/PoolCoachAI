import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Sáu bài kiến thức khởi tạo.
///
/// Cùng nguồn và cùng quy tắc thuật ngữ với `seedDrills`: nội dung lấy
/// từ prototype, từ vựng viết lại theo bảng đã chốt.
const seedKnowledge = <KnowledgeArticle>[
  KnowledgeArticle(
    id: 'k1',
    cat: SkillCategory.aiming,
    title: 'Nguyên lý bi ảo (Ghost Ball)',
    body: 'Bi ảo là vị trí tưởng tượng của bi cái ngay trước khi nó chạm '
        'bi mục tiêu. Muốn bi mục tiêu đi đúng hướng tới lỗ, tâm bi cái '
        'phải đi tới đúng tâm của bi ảo đó. Cách luyện: nhìn đường thẳng '
        'từ lỗ qua tâm bi mục tiêu, kéo dài thêm một đường kính bi ra '
        'phía sau — đó chính là tâm bi ảo cần ngắm tới.',
    relatedDrillIds: ['d1', 'd2'],
  ),
  KnowledgeArticle(
    id: 'k2',
    cat: SkillCategory.aiming,
    title: 'Cách cầm cơ và tư thế chuẩn',
    body: 'Tay cầm cơ nên thả lỏng, chỉ siết nhẹ khi tiếp xúc bi. Cánh '
        'tay trên vuông góc với cẳng tay ở điểm ngắm cuối cùng. Mắt nên '
        'đặt thẳng trên đường cơ để nhìn được cả bi cái và bi mục tiêu '
        'cùng lúc. Giữ đầu cố định trong suốt cú đánh — phần lớn lỗi '
        'ngắm đến từ việc đầu di chuyển trước khi cơ chạm bi.',
    relatedDrillIds: ['d1'],
  ),
  KnowledgeArticle(
    id: 'k3',
    cat: SkillCategory.position,
    title: 'Nguyên tắc điều bi cơ bản (Position Play)',
    body: 'Trước mỗi cú đánh, hãy nghĩ tới bi tiếp theo trước khi đánh bi '
        'hiện tại. Ba yếu tố kiểm soát vị trí bi cái: điểm tiếp xúc trên '
        'bi cái (trên/giữa/dưới), lực đánh, và góc cắt. Ưu tiên dùng lực '
        'nhỏ nhất có thể để giảm sai số — điều bi bằng "tốc độ" dễ kiểm '
        'soát hơn điều bi bằng "góc".',
    relatedDrillIds: ['d3', 'd4', 'd5'],
  ),
  KnowledgeArticle(
    id: 'k4',
    cat: SkillCategory.breakShot,
    title: 'Phá hiệu quả trong Pool',
    body: 'Một cú phá tốt cần cả lực và độ chính xác. Đặt bi cái hơi lệch '
        'tâm để tránh xoáy ngược không kiểm soát. Đánh vào bi đầu rack '
        'với lực tối đa mà vẫn giữ được cơ thẳng — phá mạnh nhưng lệch '
        'hướng thường kém hiệu quả hơn phá vừa phải và chính xác.',
    relatedDrillIds: ['d6'],
  ),
  KnowledgeArticle(
    id: 'k5',
    cat: SkillCategory.kick,
    title: 'Quy tắc góc phản xạ khi A băng',
    body: 'Khi bi lăn không xoáy chạm băng, góc tới gần bằng góc phản xạ '
        '(giống ánh sáng phản chiếu gương). Xoáy sẽ làm thay đổi góc này '
        '— đánh cu lê làm góc phản xạ hẹp hơn, đánh trô bi làm góc rộng '
        'hơn. Luyện tập không xoáy trước để nắm vững góc cơ bản. Quy tắc '
        'này dùng chung cho cả A băng và Cân bi.',
    relatedDrillIds: ['d8', 'd9'],
  ),
  KnowledgeArticle(
    id: 'k6',
    cat: SkillCategory.safety,
    title: 'Tư duy phòng thủ (Safety)',
    body: 'Một nước an toàn tốt nên để bi cái cách xa mọi bi mục tiêu, '
        'sát băng nếu có thể, và chắn tầm nhìn đối thủ. Luôn có "kế '
        'hoạch B" — nếu an toàn không thành công hoàn hảo, vẫn nên gây '
        'khó khăn tối đa cho đối thủ.',
    relatedDrillIds: ['d7'],
  ),
];
