import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const unitOrder = 1;
const unitSlug = "put-actions-in-time";
const unitTitle = "Put actions in time";

export const unit01: LessonSpec[] = [
  {
    order: 1,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Say what is new",
    scenario: "Catch up with a friend about life and learning.",
    difficulty: 2.25,
    rounds: [
      r(
        "A friend asks what you have been doing lately.",
        "Lately I’ve been studying more Vietnamese.",
        "Share what you have been doing lately.",
        [
          s("Dạo này", "lately"),
          s("mình đang học thêm", "I’ve been studying more"),
          s("tiếng Việt.", "Vietnamese"),
        ],
      ),
      r(
        "Explain when learning fits around your job.",
        "I work during the day, so I only study at night.",
        "Contrast your daytime and evening activities.",
        [
          s("Ban ngày mình đi làm,", "I work during the day"),
          s("tối mới học.", "so I only study at night"),
        ],
      ),
      r(
        "Describe how the learning feels now.",
        "It was a little difficult at first, but it’s better now.",
        "Contrast the beginning with how it feels now.",
        [
          s("Mới đầu hơi khó,", "it was a little difficult at first"),
          s("giờ đỡ hơn rồi.", "but it’s better now"),
        ],
      ),
      r(
        "Tell your friend about your listening habit.",
        "I listen for about ten minutes every day.",
        "Say how often and how long you listen.",
        [
          s("Mỗi ngày", "every day"),
          s("mình nghe chừng mười phút.", "I listen for about ten minutes"),
        ],
        [
          s("Mỗi ngày", "every day"),
          s("mình nghe khoảng mười phút.", "I listen for about ten minutes"),
        ],
      ),
      r(
        "Sum up your progress without exaggerating.",
        "Slowly but surely, I feel like I’m improving.",
        "End with a modest comment about progress.",
        [
          s("Chậm mà chắc,", "slowly but surely"),
          s("mình thấy", "I feel"),
          s("có tiến bộ.", "I’m improving"),
        ],
      ),
    ],
  },
  {
    order: 2,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Walk through your day",
    scenario: "Describe an ordinary weekday from morning to night.",
    difficulty: 2.3,
    rounds: [
      r(
        "Start with your normal wake-up time.",
        "I usually wake up at seven in the morning.",
        "Give your usual wake-up time.",
        [
          s("Buổi sáng", "in the morning"),
          s("mình hay dậy", "I usually wake up"),
          s("lúc bảy giờ.", "at seven"),
        ],
      ),
      r(
        "Explain what happens after breakfast.",
        "After breakfast, I head to work.",
        "Link breakfast to the next action.",
        [s("Ăn sáng xong", "after breakfast"), s("là mình đi làm.", "I head to work")],
      ),
      r(
        "Describe what you do on a free lunch break.",
        "If I have time at lunch, I walk for a bit.",
        "Add a simple condition to your routine.",
        [
          s("Buổi trưa mà rảnh", "if I have time at lunch"),
          s("thì mình đi bộ", "I walk"),
          s("một chút.", "for a bit"),
        ],
      ),
      r(
        "Say what normally happens after work.",
        "When I get home, I usually cook.",
        "Describe your usual after-work activity.",
        [
          s("Chiều về", "when I get home in the afternoon"),
          s("mình thường nấu cơm.", "I usually cook"),
        ],
      ),
      r(
        "Contrast the weekend with weekdays.",
        "On weekends, I sleep in a little.",
        "Finish with your weekend exception.",
        [
          s("Còn cuối tuần", "as for the weekend"),
          s("thì mình ngủ nướng", "I sleep in"),
          s("một chút.", "a little"),
        ],
      ),
    ],
  },
  {
    order: 3,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Tell what happened yesterday",
    scenario: "Explain why yesterday felt long and tiring.",
    difficulty: 2.35,
    rounds: [
      r(
        "A friend asks why you look tired.",
        "Yesterday I was busy from morning until night.",
        "Set the time and describe the whole day.",
        [
          s("Hôm qua", "yesterday"),
          s("mình bận", "I was busy"),
          s("từ sáng tới tối.", "from morning until night"),
        ],
      ),
      r(
        "Explain why you left home early.",
        "I had a meeting in the morning, so I left early.",
        "Connect the meeting with leaving early.",
        [
          s("Sáng có cuộc họp", "I had a meeting in the morning"),
          s("nên mình đi sớm.", "so I left early"),
        ],
      ),
      r(
        "Describe the rushed lunch break.",
        "At lunch I ate quickly and then kept working.",
        "Sequence lunch and the next action.",
        [
          s("Trưa mình ăn vội", "at lunch I ate quickly"),
          s("rồi làm tiếp.", "and then kept working"),
        ],
      ),
      r(
        "Explain the delay after work.",
        "It was raining after work, so I waited for a while.",
        "Say what caused you to wait.",
        [
          s("Tan làm thì trời mưa,", "it was raining after work"),
          s("mình đợi một lúc.", "so I waited for a while"),
        ],
      ),
      r(
        "Say how you felt when you finally arrived.",
        "As soon as I got home, I just wanted to rest.",
        "Finish the story with your reaction.",
        [
          s("Về tới nhà", "as soon as I got home"),
          s("là mình chỉ muốn nghỉ.", "I just wanted to rest"),
        ],
      ),
    ],
  },
  {
    order: 4,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Share a recent experience",
    scenario: "Tell a friend about a Vietnamese film you watched.",
    difficulty: 2.4,
    rounds: [
      r(
        "Say what you did last weekend.",
        "Last weekend I went to see a film with Linh.",
        "Introduce the recent experience.",
        [
          s("Cuối tuần rồi", "last weekend"),
          s("mình đi coi phim", "I went to see a film"),
          s("với Linh.", "with Linh"),
        ],
        [
          s("Cuối tuần rồi", "last weekend"),
          s("mình đi xem phim", "I went to see a film"),
          s("với Linh.", "with Linh"),
        ],
      ),
      r(
        "Give your overall reaction to the film.",
        "The film was a little long, but it was pretty gripping.",
        "Balance a criticism with a positive reaction.",
        [
          s("Phim hơi dài", "the film was a little long"),
          s("mà coi cũng cuốn.", "but it was pretty gripping"),
        ],
        [
          s("Phim hơi dài", "the film was a little long"),
          s("nhưng xem cũng cuốn.", "but it was pretty gripping"),
        ],
      ),
      r(
        "Mention the part you enjoyed most.",
        "I liked the ending the most.",
        "Identify your favorite part.",
        [s("Mình thích nhất", "I liked the most"), s("là đoạn cuối.", "the ending")],
      ),
      r(
        "Admit one listening difficulty.",
        "There were a few parts I couldn’t hear very clearly.",
        "Describe the difficulty without saying you understood nothing.",
        [
          s("Có mấy chỗ", "there were a few parts"),
          s("mình nghe không rõ lắm.", "I couldn’t hear very clearly"),
        ],
      ),
      r(
        "Say whether you would repeat the experience.",
        "When there’s another new film, I’ll go again.",
        "End with a future intention.",
        [
          s("Bữa nào có phim mới", "when there’s another new film"),
          s("mình đi nữa.", "I’ll go again"),
        ],
        [
          s("Khi nào có phim mới", "when there’s another new film"),
          s("mình lại đi.", "I’ll go again"),
        ],
      ),
    ],
  },
  {
    order: 5,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Then, now, and next",
    scenario: "Update a friend about a busy week and your next steps.",
    difficulty: 2.45,
    rounds: [
      r(
        "Explain how life has felt lately.",
        "Work has been a little busy lately.",
        "Open with a current update.",
        [
          s("Dạo này", "lately"),
          s("công việc của mình", "my work"),
          s("hơi bận.", "has been a little busy"),
        ],
      ),
      r(
        "Explain what prevented you from studying yesterday.",
        "I got home late yesterday, so I didn’t study.",
        "Connect yesterday’s delay with the result.",
        [
          s("Hôm qua mình về trễ", "I got home late yesterday"),
          s("nên chưa học.", "so I didn’t study"),
        ],
        [
          s("Hôm qua mình về muộn", "I got home late yesterday"),
          s("nên chưa học.", "so I didn’t study"),
        ],
      ),
      r(
        "Contrast today with yesterday.",
        "I have a little more time today.",
        "Say that today is easier.",
        [s("Bữa nay", "today"), s("mình rảnh hơn", "I have more time"), s("một chút.", "a little")],
        [s("Hôm nay", "today"), s("mình rảnh hơn", "I have more time"), s("một chút.", "a little")],
      ),
      r(
        "Say what you intend to do tonight.",
        "Tonight I’m planning to review the old lesson.",
        "State tonight’s intention.",
        [
          s("Tối nay", "tonight"),
          s("mình định ôn lại", "I’m planning to review"),
          s("bài cũ.", "the old lesson"),
        ],
      ),
      r(
        "Add a flexible plan for tomorrow.",
        "If I’m not busy tomorrow, I’ll keep studying.",
        "Finish with a conditional future plan.",
        [
          s("Mai mà không bận", "if I’m not busy tomorrow"),
          s("thì mình học tiếp.", "I’ll keep studying"),
        ],
      ),
    ],
  },
];
