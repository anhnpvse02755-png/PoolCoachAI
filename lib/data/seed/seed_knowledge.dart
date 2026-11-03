import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Bài kiến thức khởi tạo.
///
/// Dữ liệu được upsert mỗi lần khởi động để các bài mới và nội dung đã
/// hiệu chỉnh cũng đến được những thiết bị đã cài ứng dụng.
const seedKnowledge = <KnowledgeArticle>[
  KnowledgeArticle(
    id: 'k1',
    cat: SkillCategory.aiming,
    title: 'Nguyên lý bi ảo (Ghost Ball)',
    body:
        'Bi ảo là vị trí tưởng tượng của bi cái ngay trước khi nó chạm '
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
    body:
        'Tay cầm cơ nên thả lỏng, chỉ siết nhẹ khi tiếp xúc bi. Cánh '
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
    body:
        'Trước mỗi cú đánh, hãy nghĩ tới bi tiếp theo trước khi đánh bi '
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
    body:
        'Một cú phá tốt cần cả lực và độ chính xác. Đặt bi cái hơi lệch '
        'tâm để tránh xoáy ngược không kiểm soát. Đánh vào bi đầu rack '
        'với lực tối đa mà vẫn giữ được cơ thẳng — phá mạnh nhưng lệch '
        'hướng thường kém hiệu quả hơn phá vừa phải và chính xác.',
    relatedDrillIds: ['d6'],
  ),
  KnowledgeArticle(
    id: 'k5',
    cat: SkillCategory.kick,
    title: 'Quy tắc góc phản xạ khi A băng',
    body:
        'Khi bi lăn không xoáy chạm băng, góc tới gần bằng góc phản xạ '
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
    body:
        'Một nước an toàn tốt nên để bi cái cách xa mọi bi mục tiêu, '
        'sát băng nếu có thể, và chắn tầm nhìn đối thủ. Luôn có "kế '
        'hoạch B" — nếu an toàn không thành công hoàn hảo, vẫn nên gây '
        'khó khăn tối đa cho đối thủ.',
    relatedDrillIds: ['d7'],
  ),
  KnowledgeArticle(
    id: 'k7',
    cat: SkillCategory.aiming,
    title: 'Squirt, swerve và throw',
    body:
        'Khi đánh lệch tâm, hãy phân biệt ba hiệu ứng. Squirt là bi cái '
        'lệch khỏi hướng cơ ngay sau tiếp xúc; swerve là đường bi cái cong '
        'dần khi lăn; throw là bi mục tiêu lệch khỏi đường nối tâm do ma sát '
        'lúc va chạm. Throw cũng xuất hiện ở cú cắt không áp phê. Một ví dụ '
        'được Dr. Dave nêu là cú stun cắt 35 độ có thể làm hướng bi mục tiêu '
        'lệch khoảng 5,8 độ; đây là ví dụ riêng, không phải mức bù chung. '
        'Throw thường rõ hơn khi đánh chậm. Squirt và swerve thay đổi theo '
        'cây cơ, độ dài cầu tay và độ nâng cơ. Khi luyện, giữ lực ổn định, '
        'ghi lại hướng lệch rồi mới điều chỉnh điểm ngắm. '
        'Tham khảo: Dr. Dave Alciatore, Billiards Digest và '
        'drdavepoolinfo.com.',
  ),
  KnowledgeArticle(
    id: 'k8',
    cat: SkillCategory.aiming,
    title: 'Cắt bi sát băng bằng áp phê thuận',
    body:
        'Với bi mục tiêu sát băng, một lựa chọn là dùng áp phê thuận để '
        'bi cái chạm băng trước rồi mới chạm bi mục tiêu. Throw do áp phê '
        'có thể giúp đưa bi mục tiêu về phía lỗ, nhưng cần bù squirt khi '
        'chọn điểm ngắm. Mức áp phê và điểm bù phụ thuộc cây cơ, lực và '
        'khoảng cách; không có con số dùng chung. Hãy luyện ở lực cố định '
        'và tính trước đường đi của bi cái. Nếu ưu tiên kiểm soát bi cái, '
        'có thể chọn stun hoặc xoáy nhẹ như cách cơ bản ở mục ngắm bi sát '
        'băng. Tham khảo: Dr. Dave Alciatore, Billiards Digest.',
  ),
  KnowledgeArticle(
    id: 'k9',
    cat: SkillCategory.aiming,
    title: 'Áp phê ngược gearing để giảm throw',
    body:
        'Gearing là lượng áp phê ngược vừa đủ để giảm throw do cú cắt, '
        'giúp bi mục tiêu đi gần theo đường nối tâm hai bi. Lượng cần dùng '
        'thay đổi theo góc cắt; không có một mức cố định cho mọi cú. Dùng '
        'ít hơn mức phù hợp vẫn còn throw do cú cắt, còn dùng quá mức có '
        'thể làm throw đổi chiều. Gearing có thể hữu ích khi bi bám nhau '
        '(cling), nhưng không phải lựa chọn tốt nhất trong mọi tình huống. '
        'Luyện từng góc cắt với lực ổn định và điều chỉnh áp phê từng bước; '
        'bù squirt theo cây cơ đang dùng. Tham khảo: Dr. Dave Alciatore, '
        'Billiards Digest.',
  ),
  KnowledgeArticle(
    id: 'k10',
    cat: SkillCategory.aiming,
    title: 'Bù throw bằng cách cắt dày hơn',
    body:
        'Khi dự kiến throw sẽ làm bi mục tiêu lệch khỏi lỗ, có thể ngắm '
        'dày hơn một chút để throw đưa bi về phía tâm lỗ. Chỉ dùng khi '
        'throw ảnh hưởng đáng kể; không biến thành thói quen cắt dày ở mọi '
        'cú. Throw thay đổi theo tốc độ, thường rõ hơn khi đánh chậm, nên '
        'hãy giữ lực cố định trong lúc luyện và ghi lại mức bù cho từng '
        'góc cắt. Một phương án khác là áp phê ngược gearing. '
        'Tham khảo: Dr. Dave Alciatore, Billiards Digest.',
  ),
  KnowledgeArticle(
    id: 'k11',
    cat: SkillCategory.aiming,
    title: 'Bù squirt bằng BHE hoặc FHE',
    body:
        'Squirt làm bi cái lệch khỏi hướng cơ khi đánh lệch tâm. Với '
        'BHE (back-hand English), ngắm đường cơ bản rồi xoay cơ quanh điểm '
        'cầu tay bằng tay sau để đầu cơ đến điểm áp phê cần thiết. Với '
        'FHE (front-hand English), dùng tay trước để điều chỉnh theo mức '
        'bù đã luyện. Lượng bù phụ thuộc cây cơ, độ dài cầu tay và điểm '
        'chạm, kể cả với cơ low-deflection. Hãy luyện cùng một bàn, lực '
        'và mức áp phê; nếu bù quá nhiều, bi cái sẽ lệch sang phía ngược '
        'lại. Tham khảo: Dr. Dave Alciatore, Billiards Digest.',
  ),
];
