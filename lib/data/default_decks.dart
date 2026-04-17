// Dữ liệu bộ thẻ hệ thống — seed khi user mới tạo tài khoản.
// Mỗi bộ gồm: thông tin deck + danh sách flashcard.
// Field isSystem: true → user không thể thêm/xoá thẻ hoặc xoá deck.

class DefaultDeckData {
  final String name;
  final String description;
  final String color;
  final List<DefaultCardData> cards;

  const DefaultDeckData({
    required this.name,
    required this.description,
    required this.color,
    required this.cards,
  });
}

class DefaultCardData {
  final String front;
  final String back;
  final String? pronunciation;
  final String? example;

  const DefaultCardData({
    required this.front,
    required this.back,
    this.pronunciation,
    this.example,
  });
}

/// ─── Danh sách bộ thẻ mặc định ─────────────────────────────────────────────
const List<DefaultDeckData> kDefaultDecks = [
  // ── 1. Giao tiếp hàng ngày ───────────────────────────────────────────────
  DefaultDeckData(
    name: 'Giao tiếp hàng ngày',
    description: 'Từ vựng & câu giao tiếp thông dụng trong cuộc sống',
    color: '#534AB7',
    cards: [
      DefaultCardData(
        front: 'Hello',
        back: 'Xin chào',
        pronunciation: '/həˈloʊ/',
        example: 'Hello, how are you today?',
      ),
      DefaultCardData(
        front: 'Thank you',
        back: 'Cảm ơn',
        pronunciation: '/θæŋk juː/',
        example: 'Thank you for your help!',
      ),
      DefaultCardData(
        front: 'Excuse me',
        back: 'Xin lỗi (để gây chú ý)',
        pronunciation: '/ɪkˈskjuːz miː/',
        example: 'Excuse me, where is the nearest bank?',
      ),
      DefaultCardData(
        front: 'How much',
        back: 'Bao nhiêu tiền',
        pronunciation: '/haʊ mʌtʃ/',
        example: 'How much does this cost?',
      ),
      DefaultCardData(
        front: 'I understand',
        back: 'Tôi hiểu rồi',
        pronunciation: '/aɪ ˌʌndərˈstænd/',
        example: 'I understand what you mean.',
      ),
      DefaultCardData(
        front: 'Never mind',
        back: 'Không sao / Không có gì',
        pronunciation: '/ˈnevər maɪnd/',
        example: 'Never mind, it\'s not important.',
      ),
      DefaultCardData(
        front: 'Take care',
        back: 'Bảo trọng nhé',
        pronunciation: '/teɪk ker/',
        example: 'Goodbye! Take care!',
      ),
      DefaultCardData(
        front: 'What do you mean?',
        back: 'Ý bạn là gì?',
        pronunciation: '/wɒt duː juː miːn/',
        example: 'Sorry, what do you mean by that?',
      ),
      DefaultCardData(
        front: 'I\'m sorry',
        back: 'Tôi xin lỗi',
        pronunciation: '/aɪm ˈsɒri/',
        example: 'I\'m sorry for being late.',
      ),
      DefaultCardData(
        front: 'Could you help me?',
        back: 'Bạn có thể giúp tôi được không?',
        pronunciation: '/kʊd juː help miː/',
        example: 'Could you help me find the exit?',
      ),
      DefaultCardData(
        front: 'Nice to meet you',
        back: 'Rất vui được gặp bạn',
        pronunciation: '/naɪs tuː miːt juː/',
        example: 'Hi, I\'m Nam. Nice to meet you!',
      ),
      DefaultCardData(
        front: 'See you later',
        back: 'Hẹn gặp lại',
        pronunciation: '/siː juː ˈleɪtər/',
        example: 'I have to go now. See you later!',
      ),
      DefaultCardData(
        front: 'What time is it?',
        back: 'Bây giờ là mấy giờ?',
        pronunciation: '/wɒt taɪm ɪz ɪt/',
        example: 'Excuse me, what time is it?',
      ),
      DefaultCardData(
        front: 'I don\'t understand',
        back: 'Tôi không hiểu',
        pronunciation: '/aɪ doʊnt ˌʌndərˈstænd/',
        example: 'I don\'t understand. Could you repeat?',
      ),
      DefaultCardData(
        front: 'No problem',
        back: 'Không vấn đề gì',
        pronunciation: '/noʊ ˈprɑːbləm/',
        example: 'No problem, I can wait.',
      ),
    ],
  ),

  // ── 2. Du lịch ───────────────────────────────────────────────────────────
  DefaultDeckData(
    name: 'Du lịch',
    description: 'Từ vựng cần thiết khi đi du lịch nước ngoài',
    color: '#1D9E75',
    cards: [
      DefaultCardData(
        front: 'Airport',
        back: 'Sân bay',
        pronunciation: '/ˈerˌpɔːrt/',
        example: 'We need to be at the airport by 6 AM.',
      ),
      DefaultCardData(
        front: 'Passport',
        back: 'Hộ chiếu',
        pronunciation: '/ˈpæspɔːrt/',
        example: 'Don\'t forget to bring your passport.',
      ),
      DefaultCardData(
        front: 'Boarding pass',
        back: 'Thẻ lên máy bay',
        pronunciation: '/ˈbɔːrdɪŋ pæs/',
        example: 'Please show your boarding pass at the gate.',
      ),
      DefaultCardData(
        front: 'Hotel',
        back: 'Khách sạn',
        pronunciation: '/hoʊˈtel/',
        example: 'I booked a hotel near the beach.',
      ),
      DefaultCardData(
        front: 'Reservation',
        back: 'Đặt chỗ / Đặt phòng',
        pronunciation: '/ˌrezərˈveɪʃən/',
        example: 'I have a reservation under the name Nguyen.',
      ),
      DefaultCardData(
        front: 'Check in',
        back: 'Làm thủ tục nhận phòng',
        pronunciation: '/tʃek ɪn/',
        example: 'What time can I check in?',
      ),
      DefaultCardData(
        front: 'Check out',
        back: 'Trả phòng',
        pronunciation: '/tʃek aʊt/',
        example: 'Check out is at 12 noon.',
      ),
      DefaultCardData(
        front: 'Luggage',
        back: 'Hành lý',
        pronunciation: '/ˈlʌɡɪdʒ/',
        example: 'How many pieces of luggage do you have?',
      ),
      DefaultCardData(
        front: 'Ticket',
        back: 'Vé',
        pronunciation: '/ˈtɪkɪt/',
        example: 'I\'d like to buy a round-trip ticket.',
      ),
      DefaultCardData(
        front: 'Exchange rate',
        back: 'Tỷ giá hối đoái',
        pronunciation: '/ɪksˈtʃeɪndʒ reɪt/',
        example: 'What is the exchange rate for USD to VND?',
      ),
      DefaultCardData(
        front: 'Where is...?',
        back: '... ở đâu?',
        pronunciation: '/wer ɪz/',
        example: 'Where is the nearest subway station?',
      ),
      DefaultCardData(
        front: 'Map',
        back: 'Bản đồ',
        pronunciation: '/mæp/',
        example: 'Can I have a map of the city?',
      ),
      DefaultCardData(
        front: 'Tourist',
        back: 'Khách du lịch',
        pronunciation: '/ˈtʊrɪst/',
        example: 'This area is popular with tourists.',
      ),
      DefaultCardData(
        front: 'Souvenir',
        back: 'Quà lưu niệm',
        pronunciation: '/ˌsuːvəˈnɪr/',
        example: 'I bought some souvenirs for my family.',
      ),
      DefaultCardData(
        front: 'Delayed',
        back: 'Bị trễ / Bị hoãn',
        pronunciation: '/dɪˈleɪd/',
        example: 'The flight is delayed by two hours.',
      ),
    ],
  ),

  // ── 3. IELTS Cơ bản (A1–A2) ──────────────────────────────────────────────
  DefaultDeckData(
    name: 'IELTS Cơ bản (A1–A2)',
    description: 'Từ vựng IELTS nền tảng dành cho người mới bắt đầu',
    color: '#185FA5',
    cards: [
      DefaultCardData(
        front: 'Describe',
        back: 'Mô tả',
        pronunciation: '/dɪˈskraɪb/',
        example: 'Describe your hometown in a few sentences.',
      ),
      DefaultCardData(
        front: 'Family',
        back: 'Gia đình',
        pronunciation: '/ˈfæməli/',
        example: 'My family has four members.',
      ),
      DefaultCardData(
        front: 'Daily routine',
        back: 'Thói quen hàng ngày',
        pronunciation: '/ˈdeɪli ruːˈtiːn/',
        example: 'Tell me about your daily routine.',
      ),
      DefaultCardData(
        front: 'Favourite',
        back: 'Yêu thích nhất',
        pronunciation: '/ˈfeɪvərɪt/',
        example: 'What is your favourite subject at school?',
      ),
      DefaultCardData(
        front: 'Neighbourhood',
        back: 'Khu phố / Vùng lân cận',
        pronunciation: '/ˈneɪbərhʊd/',
        example: 'I live in a quiet neighbourhood.',
      ),
      DefaultCardData(
        front: 'Hobby',
        back: 'Sở thích',
        pronunciation: '/ˈhɒbi/',
        example: 'Reading is my favourite hobby.',
      ),
      DefaultCardData(
        front: 'Weather',
        back: 'Thời tiết',
        pronunciation: '/ˈweðər/',
        example: 'The weather in Vietnam is hot and humid.',
      ),
      DefaultCardData(
        front: 'School',
        back: 'Trường học',
        pronunciation: '/skuːl/',
        example: 'I go to school by bicycle every day.',
      ),
      DefaultCardData(
        front: 'Job',
        back: 'Công việc / Nghề nghiệp',
        pronunciation: '/dʒɒb/',
        example: 'What job do you want in the future?',
      ),
      DefaultCardData(
        front: 'Free time',
        back: 'Thời gian rảnh',
        pronunciation: '/friː taɪm/',
        example: 'What do you do in your free time?',
      ),
      DefaultCardData(
        front: 'Healthy',
        back: 'Khỏe mạnh / Lành mạnh',
        pronunciation: '/ˈhelθi/',
        example: 'Eating vegetables keeps you healthy.',
      ),
      DefaultCardData(
        front: 'Transport',
        back: 'Phương tiện giao thông',
        pronunciation: '/ˈtrænspɔːrt/',
        example: 'Public transport in my city is cheap.',
      ),
      DefaultCardData(
        front: 'Important',
        back: 'Quan trọng',
        pronunciation: '/ɪmˈpɔːrtənt/',
        example: 'It is important to study English every day.',
      ),
      DefaultCardData(
        front: 'Different',
        back: 'Khác nhau',
        pronunciation: '/ˈdɪfrənt/',
        example: 'Cities and villages are very different.',
      ),
      DefaultCardData(
        front: 'Popular',
        back: 'Phổ biến',
        pronunciation: '/ˈpɒpjələr/',
        example: 'Football is a popular sport worldwide.',
      ),
      DefaultCardData(
        front: 'Modern',
        back: 'Hiện đại',
        pronunciation: '/ˈmɒdərn/',
        example: 'Ho Chi Minh City is a modern city.',
      ),
      DefaultCardData(
        front: 'Traditional',
        back: 'Truyền thống',
        pronunciation: '/trəˈdɪʃənəl/',
        example: 'Ao dai is a traditional Vietnamese dress.',
      ),
      DefaultCardData(
        front: 'Compare',
        back: 'So sánh',
        pronunciation: '/kəmˈper/',
        example: 'Compare living in the city and the countryside.',
      ),
    ],
  ),

  // ── 4. IELTS Nâng cao (B1–B2) ────────────────────────────────────────────
  DefaultDeckData(
    name: 'IELTS Nâng cao (B1–B2)',
    description: 'Từ vựng IELTS học thuật dành cho band 5.0–7.0',
    color: '#BA7517',
    cards: [
      DefaultCardData(
        front: 'Significant',
        back: 'Đáng kể / Quan trọng',
        pronunciation: '/sɪɡˈnɪfɪkənt/',
        example: 'There has been a significant increase in pollution.',
      ),
      DefaultCardData(
        front: 'Consequence',
        back: 'Hậu quả',
        pronunciation: '/ˈkɒnsɪkwəns/',
        example: 'Deforestation has serious consequences for wildlife.',
      ),
      DefaultCardData(
        front: 'Advantage',
        back: 'Lợi thế / Ưu điểm',
        pronunciation: '/ədˈvɑːntɪdʒ/',
        example: 'One advantage of technology is faster communication.',
      ),
      DefaultCardData(
        front: 'Disadvantage',
        back: 'Bất lợi / Nhược điểm',
        pronunciation: '/ˌdɪsədˈvɑːntɪdʒ/',
        example: 'A disadvantage of city life is heavy traffic.',
      ),
      DefaultCardData(
        front: 'Environment',
        back: 'Môi trường',
        pronunciation: '/ɪnˈvaɪrənmənt/',
        example: 'We must protect the environment for future generations.',
      ),
      DefaultCardData(
        front: 'Contribute',
        back: 'Đóng góp',
        pronunciation: '/kənˈtrɪbjuːt/',
        example: 'Education contributes to economic development.',
      ),
      DefaultCardData(
        front: 'Whereas',
        back: 'Trong khi đó / Ngược lại',
        pronunciation: '/werˈæz/',
        example: 'City life is busy, whereas rural life is peaceful.',
      ),
      DefaultCardData(
        front: 'Rapidly',
        back: 'Một cách nhanh chóng',
        pronunciation: '/ˈræpɪdli/',
        example: 'Technology is changing rapidly.',
      ),
      DefaultCardData(
        front: 'Furthermore',
        back: 'Hơn nữa / Ngoài ra',
        pronunciation: '/ˌfɜːrðərˈmɔːr/',
        example: 'Furthermore, online learning saves travel time.',
      ),
      DefaultCardData(
        front: 'Nevertheless',
        back: 'Tuy nhiên / Mặc dù vậy',
        pronunciation: '/ˌnevərðəˈles/',
        example: 'It is expensive. Nevertheless, it is worth buying.',
      ),
      DefaultCardData(
        front: 'Unemployment',
        back: 'Thất nghiệp',
        pronunciation: '/ˌʌnɪmˈplɔɪmənt/',
        example: 'Automation may increase unemployment in some sectors.',
      ),
      DefaultCardData(
        front: 'Globalisation',
        back: 'Toàn cầu hóa',
        pronunciation: '/ˌɡloʊbələˈzeɪʃən/',
        example: 'Globalisation has brought both opportunities and challenges.',
      ),
      DefaultCardData(
        front: 'Sustainable',
        back: 'Bền vững',
        pronunciation: '/səˈsteɪnəbl/',
        example: 'We need sustainable energy sources.',
      ),
      DefaultCardData(
        front: 'Poverty',
        back: 'Nghèo đói',
        pronunciation: '/ˈpɒvərti/',
        example: 'Education is one way to reduce poverty.',
      ),
      DefaultCardData(
        front: 'Inequality',
        back: 'Bất bình đẳng',
        pronunciation: '/ˌɪnɪˈkwɒləti/',
        example: 'Income inequality remains a global problem.',
      ),
      DefaultCardData(
        front: 'Argue',
        back: 'Lập luận / Tranh luận',
        pronunciation: '/ˈɑːrɡjuː/',
        example: 'Some people argue that zoos are harmful to animals.',
      ),
      DefaultCardData(
        front: 'Evidence',
        back: 'Bằng chứng',
        pronunciation: '/ˈevɪdəns/',
        example: 'There is strong evidence that exercise improves mood.',
      ),
      DefaultCardData(
        front: 'Inevitable',
        back: 'Không thể tránh khỏi',
        pronunciation: '/ɪnˈevɪtəbl/',
        example: 'Change is inevitable in modern society.',
      ),
      DefaultCardData(
        front: 'Implement',
        back: 'Thực hiện / Triển khai',
        pronunciation: '/ˈɪmplɪment/',
        example: 'The government plans to implement new policies.',
      ),
      DefaultCardData(
        front: 'Emphasise',
        back: 'Nhấn mạnh',
        pronunciation: '/ˈemfəsaɪz/',
        example: 'The report emphasises the need for clean energy.',
      ),
    ],
  ),
];
