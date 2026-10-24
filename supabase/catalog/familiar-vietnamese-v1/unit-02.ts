import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const unitOrder = 2;
const unitSlug = "talk-about-your-world";
const unitTitle = "Talk about your world";

export const unit02: LessonSpec[] = [
  {
    order: 6,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Explain who is who",
    scenario: "Show an older friend a family photo and explain the relationships.",
    difficulty: 2.45,
    rounds: [
      r(
        "Point out your older sister in the photo.",
        "This is my older sister.",
        "Identify your older sister naturally.",
        [s("Đây là", "this is"), s("chị gái của em.", "my older sister")],
      ),
      r("Say how much older she is.", "She’s three years older than me.", "Compare your ages.", [
        s("Chị ấy", "she"),
        s("hơn em ba tuổi.", "is three years older than me"),
      ]),
      r(
        "Explain where your parents currently live.",
        "My parents still live in my hometown.",
        "Say where your parents live now.",
        [s("Ba mẹ em", "my parents"), s("vẫn sống", "still live"), s("ở quê.", "in my hometown")],
        [s("Bố mẹ em", "my parents"), s("vẫn sống", "still live"), s("ở quê.", "in my hometown")],
      ),
      r(
        "Add one fact about your younger brother.",
        "My younger brother is studying at university.",
        "Describe what your younger brother is doing now.",
        [
          s("Em trai em", "my younger brother"),
          s("đang học đại học.", "is studying at university"),
        ],
      ),
      r(
        "Explain how the family stays connected.",
        "We call each other every weekend.",
        "Finish with your regular family habit.",
        [
          s("Cuối tuần nào", "every weekend"),
          s("cả nhà em cũng gọi", "my whole family calls"),
          s("cho nhau.", "one another"),
        ],
      ),
    ],
  },
  {
    order: 7,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Describe someone naturally",
    scenario: "Tell a friend about the colleague they will meet.",
    difficulty: 2.5,
    rounds: [
      r(
        "Introduce the colleague your friend will meet.",
        "The person you’re about to meet is Ms. Mai.",
        "Identify the person before the meeting.",
        [s("Người bạn sắp gặp", "the person you’re about to meet"), s("là chị Mai.", "is Ms. Mai")],
      ),
      r(
        "Describe her general personality.",
        "She’s easygoing and very straightforward.",
        "Give two useful personality traits.",
        [
          s("Chị ấy", "she"),
          s("dễ tính", "is easygoing"),
          s("mà rất thẳng.", "and very straightforward"),
        ],
      ),
      r(
        "Explain her conversational style.",
        "She talks quickly, but she listens carefully.",
        "Contrast how she talks and listens.",
        [
          s("Chị nói nhanh", "she talks quickly"),
          s("nhưng nghe kỹ lắm.", "but she listens carefully"),
        ],
      ),
      r(
        "Mention a habit that helps your friend recognize her.",
        "She often carries a large red bag.",
        "Describe one recognizable habit.",
        [s("Chị hay mang", "she often carries"), s("cái túi đỏ bự.", "a large red bag")],
        [s("Chị hay mang", "she often carries"), s("cái túi đỏ to.", "a large red bag")],
      ),
      r(
        "Reassure your friend about the meeting.",
        "Just be yourself; she’s very friendly.",
        "End with a relaxed reassurance.",
        [
          s("Bạn cứ tự nhiên,", "just be yourself"),
          s("chị thân thiện lắm.", "she’s very friendly"),
        ],
      ),
    ],
  },
  {
    order: 8,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Talk about a hobby",
    scenario: "Chat with a friend after joining a badminton group.",
    difficulty: 2.55,
    rounds: [
      r(
        "Say what new activity you recently started.",
        "I recently started playing badminton.",
        "Introduce your new hobby.",
        [s("Mình mới tập", "I recently started"), s("chơi cầu lông.", "playing badminton")],
      ),
      r(
        "Be honest about your current ability.",
        "I’m not very good yet, but it’s fun.",
        "Balance your ability with your enjoyment.",
        [
          s("Mình chơi chưa giỏi", "I’m not very good yet"),
          s("nhưng vui lắm.", "but it’s a lot of fun"),
        ],
      ),
      r(
        "Explain your weekly practice schedule.",
        "The group practices twice a week.",
        "Say how often the group practices.",
        [s("Nhóm tập", "the group practices"), s("mỗi tuần hai buổi.", "twice a week")],
      ),
      r(
        "Say what is still difficult for you.",
        "I can serve, but I still can’t hit hard.",
        "Contrast one ability with one limitation.",
        [
          s("Mình giao cầu được", "I can serve"),
          s("mà vẫn chưa đập mạnh được.", "but I still can’t hit hard"),
        ],
        [
          s("Mình giao cầu được", "I can serve"),
          s("nhưng vẫn chưa đập mạnh được.", "but I still can’t hit hard"),
        ],
      ),
      r(
        "Invite your friend to participate casually.",
        "Come play with us sometime if you’re free.",
        "Make a low-pressure invitation.",
        [
          s("Bữa nào rảnh", "sometime when you’re free"),
          s("qua chơi chung nha.", "come play with us"),
        ],
        [
          s("Hôm nào rảnh", "sometime when you’re free"),
          s("qua chơi cùng nhé.", "come play with us"),
        ],
      ),
    ],
  },
  {
    order: 9,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Say how you really feel",
    scenario: "Tell a close friend why you seem quieter than usual.",
    difficulty: 2.6,
    rounds: [
      r(
        "Answer honestly when your friend checks on you.",
        "I’m a little tired today.",
        "State your current feeling simply.",
        [s("Bữa nay", "today"), s("mình hơi mệt.", "I’m a little tired")],
        [s("Hôm nay", "today"), s("mình hơi mệt.", "I’m a little tired")],
      ),
      r(
        "Explain the immediate cause.",
        "I stayed up late last night, so I didn’t get enough sleep.",
        "Connect staying up late with poor sleep.",
        [
          s("Tối qua mình thức khuya", "I stayed up late last night"),
          s("nên ngủ không đủ.", "so I didn’t get enough sleep"),
        ],
      ),
      r(
        "Describe the emotional effect as well.",
        "I’m also a little stressed because of work.",
        "Add another feeling and its cause.",
        [
          s("Mình cũng hơi căng thẳng", "I’m also a little stressed"),
          s("vì công việc.", "because of work"),
        ],
      ),
      r(
        "Reassure your friend that it is manageable.",
        "It’s nothing serious; I just need some rest.",
        "Keep the problem in perspective.",
        [
          s("Không có gì nghiêm trọng đâu,", "it’s nothing serious"),
          s("mình chỉ cần nghỉ chút thôi.", "I just need some rest"),
        ],
      ),
      r(
        "Accept a gentle suggestion from your friend.",
        "Yeah, I’ll go home early today.",
        "Agree and state what you will do.",
        [s("Ừ,", "yeah"), s("bữa nay mình về sớm.", "I’ll go home early today")],
        [s("Ừ,", "yeah"), s("hôm nay mình về sớm.", "I’ll go home early today")],
      ),
    ],
  },
  {
    order: 10,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Get past small talk",
    scenario: "Have a fuller conversation with a friend of a friend.",
    difficulty: 2.65,
    rounds: [
      r(
        "Ask what has been keeping the new acquaintance busy.",
        "What have you been busy with lately?",
        "Ask an open follow-up about recent life.",
        [s("Dạo này", "lately"), s("bạn bận gì vậy?", "what have you been busy with?")],
      ),
      r(
        "Share your own current focus after they answer.",
        "I’ve been working and studying Vietnamese on the side.",
        "Combine work with your side activity.",
        [
          s("Mình đi làm", "I’ve been working"),
          s("rồi tranh thủ học", "and studying on the side"),
          s("tiếng Việt.", "Vietnamese"),
        ],
      ),
      r(
        "Ask about a hobby they mentioned.",
        "How long have you been playing badminton?",
        "Ask how long the hobby has continued.",
        [
          s("Bạn chơi cầu lông", "you’ve been playing badminton"),
          s("bao lâu rồi?", "for how long?"),
        ],
      ),
      r(
        "Relate their answer to your own experience.",
        "I just started, so I still make lots of mistakes.",
        "Connect your newer experience to theirs.",
        [
          s("Mình mới tập", "I just started"),
          s("nên còn sai nhiều lắm.", "so I still make lots of mistakes"),
        ],
      ),
      r(
        "Close by creating a natural reason to meet again.",
        "Next time you play, message me too.",
        "Ask to be included next time.",
        [
          s("Lần sau nhóm đánh cầu", "next time the group plays"),
          s("thì nhắn mình với nha.", "message me too"),
        ],
        [
          s("Lần sau nhóm chơi cầu lông", "next time the group plays badminton"),
          s("thì nhắn mình với nhé.", "message me too"),
        ],
      ),
    ],
  },
];
