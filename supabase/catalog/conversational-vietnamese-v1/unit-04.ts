import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 4;
const unitSlug = "tell-stories-clearly";
const unitTitle = "Tell stories people can follow";

export const unit04: LessonSpec[] = [
  {
    order: 16, unitOrder, unitSlug, unitTitle,
    title: "Set up the situation",
    scenario: "Introduce a travel story with enough context to follow it.",
    difficulty: 3.8,
    rounds: [
      p("Say when and where the story happened.", "This happened last summer, when I was in Da Nang.", "Open with a clear time and place.", [["Chuyện này xảy ra hè năm ngoái,", "this happened last summer"], ["lúc mình đang ở Đà Nẵng.", "when I was in Da Nang"]]),
      p("Explain who was with you.", "I was traveling with two friends from work.", "Introduce the other people in the story.", [["Lúc đó mình đi chơi", "I was traveling"], ["với hai người bạn cùng chỗ làm.", "with two friends from work"]], [["Lúc đó mình đi chơi", "I was traveling"], ["với hai người bạn cùng công ty.", "with two friends from work"]]),
      p("Describe the original plan.", "We were supposed to leave early to watch the sunrise.", "Explain what everyone expected to happen.", [["Tụi mình tính đi sớm", "we were supposed to leave early"], ["để ngắm mặt trời mọc.", "to watch the sunrise"]], [["Bọn mình định đi sớm", "we were supposed to leave early"], ["để ngắm mặt trời mọc.", "to watch the sunrise"]]),
      p("Introduce the first warning sign.", "The night before, it suddenly started raining heavily.", "Signal that the plan was about to change.", [["Ai ngờ tối hôm trước", "but the night before"], ["trời tự nhiên mưa lớn.", "it suddenly started raining heavily"]]),
      p("Create interest in what comes next.", "We thought the trip was ruined, but something unexpected happened.", "End the setup with a hook.", [["Tụi mình tưởng chuyến đi hỏng rồi,", "we thought the trip was ruined"], ["mà sau đó có chuyện bất ngờ.", "but something unexpected happened"]], [["Bọn mình tưởng chuyến đi hỏng rồi,", "we thought the trip was ruined"], ["nhưng sau đó có chuyện bất ngờ.", "but something unexpected happened"]]),
    ],
  },
  {
    order: 17, unitOrder, unitSlug, unitTitle,
    title: "Tell events in order",
    scenario: "Describe how a simple errand turned into a long afternoon.",
    difficulty: 3.85,
    rounds: [
      p("Start with the original errand.", "At first, I only went out to pick up a package.", "State the simple original intention.", [["Ban đầu", "at first"], ["mình chỉ ra ngoài lấy gói hàng thôi.", "I only went out to pick up a package"]]),
      p("Explain the first complication.", "When I got there, they said the package hadn’t arrived.", "Move the story to the first problem.", [["Tới nơi thì", "when I got there"], ["họ nói hàng chưa tới.", "they said the package hadn’t arrived"]], [["Đến nơi thì", "when I got there"], ["họ nói hàng chưa đến.", "they said the package hadn’t arrived"]]),
      p("Describe what you did while waiting.", "So I went nearby to eat while I waited.", "Connect the delay to your next action.", [["Thế là mình ghé gần đó ăn", "so I went nearby to eat"], ["trong lúc chờ.", "while I waited"]]),
      p("Add the next unexpected event.", "Just after I ordered, they called to say it was ready.", "Show that the timing was inconvenient.", [["Vừa gọi món xong", "just after I ordered"], ["thì họ gọi báo có hàng.", "they called to say it was ready"]]),
      p("Finish with the overall result.", "In the end, one quick errand took nearly three hours.", "Close with a concise summary.", [["Cuối cùng", "in the end"], ["việc có chút xíu mà mất gần ba tiếng.", "one quick errand took nearly three hours"]], [["Cuối cùng", "in the end"], ["việc đơn giản thế mà mất gần ba tiếng.", "one quick errand took nearly three hours"]]),
    ],
  },
  {
    order: 18, unitOrder, unitSlug, unitTitle,
    title: "Explain cause and consequence",
    scenario: "Explain how one small mistake caused a series of problems.",
    difficulty: 3.9,
    rounds: [
      p("Name the original mistake.", "I left home in a hurry, so I forgot my charger.", "Connect the rushed departure to the mistake.", [["Mình đi vội quá", "I left home in a hurry"], ["nên quên mang sạc.", "so I forgot my charger"]]),
      p("Explain the immediate consequence.", "Because my battery was low, I turned off mobile data.", "Show the next effect in the chain.", [["Tại điện thoại gần hết pin", "because my battery was low"], ["nên mình tắt mạng.", "I turned off mobile data"]]),
      p("Describe what you missed as a result.", "That meant I didn’t see the message about the new address.", "Link the action to missing important information.", [["Thành ra", "that meant"], ["mình không thấy tin nhắn đổi địa chỉ.", "I didn’t see the message about the new address"]]),
      p("Explain the practical result.", "I went to the wrong place and arrived half an hour late.", "State the final concrete consequence.", [["Mình đi nhầm chỗ", "I went to the wrong place"], ["rồi tới trễ nửa tiếng.", "and arrived half an hour late"]], [["Mình đi nhầm chỗ", "I went to the wrong place"], ["rồi đến muộn nửa tiếng.", "and arrived half an hour late"]]),
      p("Reflect on what would have prevented it.", "If I’d checked everything before leaving, none of that would have happened.", "End with a natural counterfactual reflection.", [["Giá mà kiểm tra trước khi đi", "if I’d checked everything before leaving"], ["thì đâu có chuyện gì.", "none of that would have happened"]]),
    ],
  },
  {
    order: 19, unitOrder, unitSlug, unitTitle,
    title: "Describe an awkward moment",
    scenario: "Retell a funny misunderstanding at a family gathering.",
    difficulty: 3.95,
    rounds: [
      p("Introduce the misunderstanding.", "At dinner, I thought everyone was talking about me.", "Set up an awkward interpretation.", [["Lúc ăn cơm,", "at dinner"], ["mình tưởng mọi người đang nói về mình.", "I thought everyone was talking about me"]]),
      p("Explain why you believed that.", "They kept looking my way and laughing.", "Give the evidence that led you astray.", [["Ai cũng cứ nhìn qua", "they kept looking my way"], ["rồi cười.", "and laughing"]]),
      p("Quote your own nervous response.", "I finally asked, ‘Did I say something wrong?’", "Bring quoted speech into the story.", [["Cuối cùng mình hỏi,", "I finally asked"], ["‘Con nói gì sai hả?’", "did I say something wrong"]], [["Cuối cùng mình hỏi,", "I finally asked"], ["‘Cháu nói gì sai ạ?’", "did I say something wrong"]]),
      p("Reveal what was really happening.", "It turned out there was a cat sitting right behind me.", "Deliver the explanation behind the misunderstanding.", [["Hóa ra", "it turned out"], ["có con mèo ngồi ngay sau lưng mình.", "there was a cat sitting right behind me"]]),
      p("Describe everyone’s reaction.", "Once I realized it, I laughed harder than anyone.", "End with your own amused reaction.", [["Hiểu ra rồi", "once I realized it"], ["mình còn cười dữ hơn mọi người.", "I laughed harder than anyone"]], [["Hiểu ra rồi", "once I realized it"], ["mình còn cười nhiều hơn mọi người.", "I laughed harder than anyone"]]),
    ],
  },
  {
    order: 20, unitOrder, unitSlug, unitTitle,
    title: "Tell the complete story",
    scenario: "Tell how strangers helped you recover a lost wallet.",
    difficulty: 4.0,
    rounds: [
      p("Open with the moment you noticed the loss.", "I only realized my wallet was missing when I went to pay.", "Begin at the moment the problem became clear.", [["Tới lúc tính tiền", "when I went to pay"], ["mình mới phát hiện mất ví.", "I only realized my wallet was missing"]], [["Đến lúc thanh toán", "when I went to pay"], ["mình mới phát hiện mất ví.", "I only realized my wallet was missing"]]),
      p("Explain where you searched first.", "I went back along the same route, but I couldn’t find it.", "Describe the first attempt to solve the problem.", [["Mình quay lại đường cũ tìm", "I went back along the same route"], ["mà không thấy.", "but I couldn’t find it"]]),
      p("Introduce the person who helped.", "Then a shop owner asked what I was looking for.", "Bring a helpful stranger into the story.", [["Sau đó có cô chủ tiệm", "then a shop owner"], ["hỏi mình đang tìm gì.", "asked what I was looking for"]]),
      p("Explain how the wallet was recovered.", "She posted in the neighborhood group, and someone replied right away.", "Describe the action that solved the problem.", [["Cô đăng lên nhóm khu phố,", "she posted in the neighborhood group"], ["có người trả lời liền.", "and someone replied right away"]], [["Cô đăng lên nhóm khu phố,", "she posted in the neighborhood group"], ["có người trả lời ngay.", "and someone replied right away"]]),
      p("Close with your lasting impression.", "I got everything back, and I was touched that everyone helped.", "End with the result and how it made you feel.", [["Mình lấy lại được hết,", "I got everything back"], ["mà cảm động vì ai cũng nhiệt tình.", "and I was touched that everyone helped"]]),
    ],
  },
];
