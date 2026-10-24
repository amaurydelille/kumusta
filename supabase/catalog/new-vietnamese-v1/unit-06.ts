import { type LessonSpec, round as r, segment as s } from "./catalog.ts";
const unitOrder = 6, unitSlug = "stay-in-control", unitTitle = "Stay in control";
export const unit06: LessonSpec[] = [
  {
    order: 26,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Recover what you missed",
    scenario: "Slow down a conversation and repair understanding.",
    difficulty: 2.0,
    rounds: [
      r(
        "Say that you did not understand.",
        "Sorry, I don’t understand yet.",
        "Use the repair phrase immediately.",
        [s("Xin lỗi,", "sorry"), s("mình chưa hiểu.", "I don’t understand yet")],
      ),
      r(
        "Ask for the sentence again.",
        "Could you say that again?",
        "Make the direct repetition request.",
        [s("Bạn nói lại", "say that again"), s("được không?", "could you?")],
      ),
      r(
        "Ask for slightly slower speech.",
        "Could you speak a little more slowly?",
        "Add the small adjustment naturally.",
        [
          s("Bạn nói chậm", "speak slowly"),
          s("một chút", "a little"),
          s("được không?", "could you?"),
        ],
      ),
      r(
        "Ask the person to point it out.",
        "Could you point it out for me?",
        "Switch from listening to a visual clue.",
        [s("Bạn chỉ", "you point"), s("giùm mình", "for me"), s("được không?", "could you?")],
        [
          s("Bạn chỉ", "you point"),
          s("giúp mình", "for me"),
          s("được không ạ?", "could you, politely?"),
        ],
      ),
      r(
        "Confirm that the explanation worked.",
        "Ah, now I understand.",
        "Give the natural moment of recognition.",
        [s("À,", "ah"), s("giờ mình hiểu rồi.", "now I understand")],
      ),
    ],
  },
  {
    order: 27,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Ask what it means",
    scenario: "Use the conversation itself to learn an unfamiliar word.",
    difficulty: 2.05,
    rounds: [
      r(
        "Ask for the meaning of a word.",
        "What does this word mean?",
        "Ask the meaning question.",
        [s("Từ này", "this word"), s("nghĩa là gì?", "means what?")],
      ),
      r(
        "Ask what an object is called.",
        "What is this called?",
        "Point and ask the naming question.",
        [s("Cái này", "this thing"), s("gọi là gì?", "is called what?")],
      ),
      r(
        "Ask the person to write it down.",
        "Could you write it down for me?",
        "Make the written-help request.",
        [
          s("Bạn viết ra", "write it down"),
          s("giùm mình", "for me"),
          s("được không?", "could you?"),
        ],
        [
          s("Bạn viết ra", "write it down"),
          s("giúp mình", "for me"),
          s("được không ạ?", "could you, politely?"),
        ],
      ),
      r(
        "Confirm which object the person means.",
        "You mean this one, right?",
        "Check the reference before continuing.",
        [s("Ý bạn là", "you mean"), s("cái này", "this one"), s("phải không?", "right?")],
      ),
      r("Confirm that you recognize it now.", "Ah, I know now.", "Close the learning moment.", [
        s("À,", "ah"),
        s("mình biết rồi.", "I know now"),
      ]),
    ],
  },
  {
    order: 28,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Explain that you are lost",
    scenario: "Ask someone nearby to help you find your destination.",
    difficulty: 2.1,
    rounds: [
      r("Tell someone that you are lost.", "I’m lost.", "State the problem first.", [
        s("Mình", "I"),
        s("bị lạc rồi.", "am lost now"),
      ]),
      r(
        "Say where you need to go.",
        "I need to get to the train station.",
        "Name the destination clearly.",
        [s("Mình cần", "I need"), s("đến ga tàu.", "to get to the train station")],
      ),
      r(
        "Ask the person to check your map.",
        "Could you look at the map with me?",
        "Make the map request.",
        [
          s("Bạn xem bản đồ", "look at the map"),
          s("giùm mình", "for me"),
          s("được không?", "could you?"),
        ],
        [
          s("Bạn xem bản đồ", "look at the map"),
          s("giúp mình", "for me"),
          s("được không ạ?", "could you, politely?"),
        ],
      ),
      r(
        "Ask to borrow a phone.",
        "Could I borrow your phone?",
        "Make the practical request respectfully.",
        [
          s("Cho mình mượn", "let me borrow"),
          s("điện thoại", "a phone"),
          s("được không?", "could I?"),
        ],
        [
          s("Cho mình mượn", "let me borrow"),
          s("điện thoại", "a phone"),
          s("được không ạ?", "could I, politely?"),
        ],
      ),
      r(
        "Thank the person after finding the route.",
        "Thank you, I know the way now.",
        "Close after the help succeeds.",
        [s("Cảm ơn bạn,", "thank you"), s("mình biết đường rồi.", "I know the way now")],
      ),
    ],
  },
  {
    order: 29,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Ask for urgent help",
    scenario: "Use clear language when someone needs immediate assistance.",
    difficulty: 2.15,
    rounds: [
      r("Call clearly for help.", "Please help me!", "Say the urgent request clearly.", [
        s("Làm ơn", "please"),
        s("giúp tôi với!", "help me!"),
      ]),
      r("Say that you are unwell.", "I’m not well.", "State the problem without extra detail.", [
        s("Tôi", "I"),
        s("không khỏe.", "am not well"),
      ]),
      r("Say that you need a doctor.", "I need a doctor.", "Make the need explicit.", [
        s("Tôi cần", "I need"),
        s("bác sĩ.", "a doctor"),
      ]),
      r(
        "Ask someone to call emergency medical help.",
        "Please call emergency medical help.",
        "Say the essential action directly.",
        [s("Làm ơn", "please"), s("gọi cấp cứu.", "call emergency medical help")],
      ),
      r(
        "Ask the nearby person to make the call.",
        "Could you call for me?",
        "Direct the request to the helper.",
        [s("Bạn gọi", "you call"), s("giúp tôi", "for me"), s("được không?", "could you?")],
      ),
    ],
  },
  {
    order: 30,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "A day in Vietnamese",
    scenario: "Handle five everyday moments using your Level One language.",
    difficulty: 2.2,
    rounds: [
      r(
        "Introduce yourself to someone new.",
        "Hello, my name is Sam.",
        "Open the day with an introduction.",
        [s("Chào bạn,", "hello"), s("mình tên là", "my name is"), s("Sam.", "Sam")],
      ),
      r(
        "Order a coffee with your preference.",
        "I’ll have one less-sweet iced milk coffee, please.",
        "Give the complete order.",
        [
          s("Cho mình", "I’ll have"),
          s("một ly cà phê", "one coffee"),
          s("sữa đá ít ngọt", "iced milk, less sweet"),
          s("nha.", "please"),
        ],
        [
          s("Cho mình", "I’ll have"),
          s("một cốc cà phê", "one coffee"),
          s("sữa đá ít đường", "iced milk, less sugar"),
          s("nhé.", "please"),
        ],
      ),
      r(
        "Ask which way leads to the market.",
        "Excuse me, which way is the market?",
        "Ask the complete direction question.",
        [s("Cho mình hỏi,", "excuse me"), s("chợ đi hướng nào vậy?", "which way is the market?")],
        [s("Cho mình hỏi,", "excuse me"), s("chợ đi lối nào ạ?", "which way is the market?")],
      ),
      r("Ask the price of an item.", "How much is this?", "Use the everyday shopping question.", [
        s("Cái này", "this item"),
        s("bao nhiêu tiền vậy?", "how much is it?"),
      ], [s("Cái này", "this item"), s("bao nhiêu tiền ạ?", "how much is it, politely?")]),
      r(
        "Ask someone to slow down.",
        "Sorry, could you speak more slowly for me?",
        "Finish by taking control of the conversation.",
        [
          s("Xin lỗi,", "sorry"),
          s("bạn nói chậm lại", "speak more slowly"),
          s("giùm mình được không?", "could you, for me?"),
        ],
        [
          s("Xin lỗi,", "sorry"),
          s("bạn nói chậm lại", "speak more slowly"),
          s("giúp mình được không ạ?", "could you, for me?"),
        ],
      ),
    ],
  },
];
