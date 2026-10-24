import { type LessonSpec, round as r, segment as s } from "./catalog.ts";
const unitOrder = 2, unitSlug = "order-what-you-want", unitTitle = "Order what you want";

export const unit02: LessonSpec[] = [
  {
    order: 6,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Make a simple order",
    scenario: "Order familiar drinks and dishes at a casual cafe.",
    difficulty: 1.2,
    rounds: [
      r(
        "Order an iced milk coffee.",
        "I’ll have one iced milk coffee, please.",
        "Say the whole drink order.",
        [
          s("Cho mình", "I’ll have"),
          s("một ly", "one glass"),
          s("cà phê sữa đá", "iced milk coffee"),
          s("nha.", "please"),
        ],
        [
          s("Cho mình", "I’ll have"),
          s("một cốc", "one cup"),
          s("cà phê sữa đá", "iced milk coffee"),
          s("nhé.", "please"),
        ],
      ),
      r("Order a bottle of water.", "I’ll have one bottle of water.", "Order the water clearly.", [
        s("Cho mình", "I’ll have"),
        s("một chai nước.", "one bottle of water"),
      ]),
      r(
        "Order the dish you are pointing at.",
        "I’ll have this dish, please.",
        "Use the short pointing request.",
        [s("Cho mình", "I’ll have"), s("món này nha.", "this dish, please")],
        [s("Cho mình", "I’ll have"), s("món này ạ.", "this dish, please")],
      ),
      r("Order one bowl of pho.", "I’ll have one bowl of pho.", "Keep the food name together.", [
        s("Cho mình", "I’ll have"),
        s("một tô phở.", "one bowl of pho"),
      ], [s("Cho mình", "I’ll have"), s("một bát phở ạ.", "one bowl of pho, please")]),
      r(
        "Tell the server that your order is complete.",
        "Yes, that’s all.",
        "Close the order politely.",
        [s("Dạ,", "yes, politely"), s("vậy thôi.", "that’s all")],
        [s("Vâng,", "yes, politely"), s("thế thôi ạ.", "that’s all, politely")],
      ),
    ],
  },
  {
    order: 7,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Check what is available",
    scenario: "Ask about the menu and handle a sold-out item.",
    difficulty: 1.25,
    rounds: [
      r(
        "Ask whether the cafe has banh mi.",
        "Do you have banh mi here?",
        "Ask the availability question.",
        [s("Ở đây", "here"), s("có bánh mì không?", "do you have banh mi?")],
      ),
      r(
        "Ask whether any is still available.",
        "Is there any left?",
        "Use the short follow-up question.",
        [s("Còn", "still available"), s("không ạ?", "or not, politely")],
      ),
      r(
        "Tell a customer that banh mi is still available.",
        "Yes, there is still banh mi.",
        "Repeat the positive answer.",
        [s("Dạ,", "yes, politely"), s("còn bánh mì.", "there is still banh mi")],
        [s("Vâng,", "yes, politely"), s("còn bánh mì ạ.", "there is still banh mi")],
      ),
      r(
        "Tell a customer that the item has sold out.",
        "Sorry, it’s sold out.",
        "Give the short clear answer.",
        [s("Xin lỗi,", "sorry"), s("hết rồi.", "it’s sold out")],
      ),
      r(
        "Ask to see the menu instead.",
        "Could I see the menu?",
        "Recover by asking for the menu.",
        [s("Cho mình coi", "let me see"), s("thực đơn", "the menu"), s("được không?", "could I?")],
        [
          s("Cho mình xem", "let me see"),
          s("thực đơn", "the menu"),
          s("được không ạ?", "could I, politely?"),
        ],
      ),
    ],
  },
  {
    order: 8,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Use useful quantities",
    scenario: "Order the right number of drinks, dishes, and utensils.",
    difficulty: 1.3,
    rounds: [
      r(
        "Order two iced teas.",
        "I’ll have two glasses of iced tea.",
        "Say the quantity before the drink.",
        [s("Cho mình", "I’ll have"), s("hai ly trà đá.", "two glasses of iced tea")],
        [s("Cho mình", "I’ll have"), s("hai cốc trà đá.", "two glasses of iced tea")],
      ),
      r("Order one portion of rice.", "I’ll have one portion of rice.", "Use the portion chunk.", [
        s("Cho mình", "I’ll have"),
        s("một phần cơm.", "one portion of rice"),
      ]),
      r(
        "Ask for another pair of chopsticks.",
        "Could I have another pair of chopsticks?",
        "Make the extra-item request.",
        [
          s("Cho mình xin thêm", "could I have another"),
          s("một đôi đũa nha.", "pair of chopsticks, please"),
        ],
        [
          s("Cho mình xin thêm", "could I have another"),
          s("một đôi đũa nhé.", "pair of chopsticks, please"),
        ],
      ),
      r(
        "Clarify that you need only one portion.",
        "Just one portion.",
        "Keep the correction short.",
        [s("Chỉ", "only"), s("một phần thôi.", "one portion")],
      ),
      r(
        "Order two portions to take away.",
        "Two portions to take away, please.",
        "Combine quantity and service choice.",
        [s("Hai phần", "two portions"), s("mang đi nha.", "to take away, please")],
        [s("Hai phần", "two portions"), s("mang về ạ.", "to take away, please")],
      ),
    ],
  },
  {
    order: 9,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Change the order",
    scenario: "Adjust sweetness, ice, milk, and where you will eat.",
    difficulty: 1.35,
    rounds: [
      r(
        "Ask for a less-sweet coffee.",
        "I’ll have a less-sweet coffee, please.",
        "Add the preference naturally.",
        [s("Cho mình cà phê", "I’ll have coffee"), s("ít ngọt nha.", "less sweet, please")],
        [s("Cho mình cà phê", "I’ll have coffee"), s("ít đường nhé.", "with less sugar, please")],
      ),
      r(
        "Ask for this drink without ice.",
        "I’ll have this drink without ice.",
        "Say the no-ice request.",
        [s("Cho mình ly này", "I’ll have this drink"), s("không đá nha.", "without ice, please")],
        [s("Cho mình cốc này", "I’ll have this drink"), s("không đá nhé.", "without ice, please")],
      ),
      r(
        "Ask for a little more milk.",
        "Please add a little more milk.",
        "Make the small addition clear.",
        [s("Cho mình thêm", "please add"), s("một chút sữa.", "a little milk")],
      ),
      r("Tell the server you will eat here.", "I’ll eat here.", "Give the short service answer.", [
        s("Mình", "I"),
        s("ăn ở đây.", "will eat here"),
      ]),
      r(
        "Ask for this portion to take away.",
        "Please make this portion to take away.",
        "Finish with the takeaway request.",
        [s("Phần này", "this portion"), s("cho mình mang đi nha.", "make it to take away")],
        [s("Phần này", "this portion"), s("cho mình mang về ạ.", "make it to take away")],
      ),
    ],
  },
  {
    order: 10,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Complete a cafe order",
    scenario: "Carry one cafe order from the menu to a polite close.",
    difficulty: 1.4,
    rounds: [
      r(
        "Ask whether iced milk coffee is available.",
        "Do you have iced milk coffee?",
        "Open by checking availability.",
        [s("Ở đây có", "do you have here"), s("cà phê sữa đá không?", "iced milk coffee?")],
      ),
      r("Order two drinks.", "I’ll have two iced milk coffees.", "State the quantity and drink.", [
        s("Cho mình", "I’ll have"),
        s("hai ly", "two glasses"),
        s("cà phê sữa đá.", "iced milk coffee"),
      ], [
        s("Cho mình", "I’ll have"),
        s("hai cốc", "two cups"),
        s("cà phê sữa đá ạ.", "iced milk coffee, please"),
      ]),
      r(
        "Make one drink less sweet.",
        "Please make one less sweet.",
        "Add the preference to one drink.",
        [s("Một ly", "one glass"), s("ít ngọt nha.", "less sweet, please")],
        [s("Một cốc", "one cup"), s("ít đường nhé.", "with less sugar, please")],
      ),
      r("Choose takeaway service.", "I’ll take them away.", "Give the service choice.", [
        s("Cho mình", "for me"),
        s("mang đi nha.", "to take away, please"),
      ], [s("Cho mình", "for me"), s("mang về ạ.", "to take away, please")]),
      r("Close the order with thanks.", "That’s all, thank you.", "End the transaction warmly.", [
        s("Vậy thôi,", "that’s all"),
        s("cảm ơn bạn.", "thank you"),
      ], [s("Thế thôi ạ,", "that’s all, politely"), s("cảm ơn bạn.", "thank you")]),
    ],
  },
];
