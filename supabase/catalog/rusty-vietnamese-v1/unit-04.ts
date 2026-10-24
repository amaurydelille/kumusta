import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 4;
const unitSlug = "stories-with-personality";
const unitTitle = "Tell stories with personality";

export const unit04: LessonSpec[] = [
  {
    order: 16, unitOrder, unitSlug, unitTitle,
    title: "Make the scene vivid",
    scenario: "Use selective detail to make a childhood memory feel present.",
    difficulty: 4.8,
    rounds: [
      p("Place the memory in a familiar setting.", "Every summer, the whole family gathered at Grandma’s old house.", "Open with a recurring place and time.", "Hè nào cả nhà cũng tụ tập|ở căn nhà cũ của ngoại.", "every summer the whole family gathered|at Grandma’s old house", "Hè nào cả nhà cũng tụ tập|ở căn nhà cũ của bà ngoại.", "every summer the whole family gathered|at Grandma’s old house"),
      p("Add one sensory detail.", "Before I reached the door, I could already smell food from the kitchen.", "Make the memory physical rather than abstract.", "Chưa tới cửa|đã nghe mùi đồ ăn từ trong bếp.", "before I reached the door|I could already smell food from the kitchen", "Chưa đến cửa|đã ngửi thấy mùi thức ăn từ trong bếp.", "before I reached the door|I could already smell food from the kitchen"),
      p("Describe the lively atmosphere.", "The adults talked over one another while the children ran everywhere.", "Show several details happening at once.", "Người lớn nói chuyện chen nhau,|con nít chạy khắp nhà.", "the adults talked over one another|while the children ran everywhere", "Người lớn nói chuyện chen nhau,|trẻ con chạy khắp nhà.", "the adults talked over one another|while the children ran everywhere"),
      p("Focus on a small personal ritual.", "Grandma always saved the crispiest piece for me.", "Choose one detail that reveals affection.", "Ngoại lúc nào cũng để dành|miếng giòn nhất cho mình.", "Grandma always saved|the crispiest piece for me", "Bà lúc nào cũng để dành|miếng giòn nhất cho mình.", "Grandma always saved|the crispiest piece for me"),
      p("Reflect without overexplaining.", "I didn’t realize then how much I would miss that noise.", "End with the meaning the memory has now.", "Hồi đó mình đâu biết|sau này sẽ nhớ cái ồn ào đó tới vậy.", "I didn’t realize then|how much I would miss that noise", "Hồi đó mình đâu biết|sau này sẽ nhớ cảnh ồn ào đó đến thế.", "I didn’t realize then|how much I would miss that noise"),
    ],
  },
  {
    order: 17, unitOrder, unitSlug, unitTitle,
    title: "Bring voices into a story",
    scenario: "Use quoted speech to retell a tense but funny misunderstanding.",
    difficulty: 4.85,
    rounds: [
      p("Introduce the moment the exchange began.", "The driver looked at me and asked, ‘You don’t know the way?’", "Bring the first speaker directly into the scene.", "Chú tài xế nhìn mình rồi hỏi,|‘Con không biết đường hả?’", "the driver looked at me and asked|you don’t know the way", "Chú tài xế nhìn mình rồi hỏi,|‘Cháu không biết đường à?’", "the driver looked at me and asked|you don’t know the way"),
      p("Quote your defensive response.", "I said, ‘I do, but this road looks completely different now.’", "Show your exact reaction rather than summarizing it.", "Mình mới nói,|‘Con biết, mà đường giờ khác quá.’", "I said|I do, but this road looks completely different now", "Mình mới nói,|‘Cháu biết, nhưng đường bây giờ khác quá.’", "I said|I do, but this road looks completely different now"),
      p("Show the driver’s dry reply.", "He laughed and said, ‘The road is the same; you’re the one who forgot.’", "Use quotation to reveal personality.", "Chú cười, nói,|‘Đường vẫn vậy, con quên thôi.’", "he laughed and said|the road is the same, you’re the one who forgot", "Chú cười, bảo,|‘Đường vẫn thế, cháu quên thôi.’", "he laughed and said|the road is the same, you’re the one who forgot"),
      p("Describe your internal reaction.", "I wanted to argue, but I knew he was right.", "Contrast what you felt with what you did.", "Mình định cãi,|mà biết chú nói đúng.", "I wanted to argue|but I knew he was right"),
      p("Deliver the final callback.", "When we arrived, he said, ‘See? Next time, remember it.’", "Close by returning to the original joke.", "Tới nơi chú còn nói,|‘Thấy chưa, lần sau nhớ nha.’", "when we arrived, he even said|see, next time remember it", "Đến nơi chú còn bảo,|‘Thấy chưa, lần sau nhớ nhé.’", "when we arrived, he even said|see, next time remember it"),
    ],
  },
  {
    order: 18, unitOrder, unitSlug, unitTitle,
    title: "Control pacing and emphasis",
    scenario: "Build suspense by slowing down important moments and skipping filler.",
    difficulty: 4.9,
    rounds: [
      p("Compress an uneventful stretch.", "We drove for hours, and nothing unusual happened.", "Move quickly across background events.", "Tụi mình chạy xe mấy tiếng,|dọc đường không có gì lạ.", "we drove for hours|and nothing unusual happened", "Bọn mình đi xe mấy tiếng,|dọc đường không có gì lạ.", "we drove for hours|and nothing unusual happened"),
      p("Signal the turning point.", "Then, just as it got dark, the engine suddenly stopped.", "Slow down at the event that changes the story.", "Rồi đúng lúc trời vừa tối,|xe tự nhiên tắt máy.", "then, just as it got dark|the engine suddenly stopped"),
      p("Hold the outcome for a moment.", "We got out, looked around, and heard absolutely nothing.", "Create suspense through a sequence of small actions.", "Cả đám bước xuống, nhìn quanh,|không nghe một tiếng động nào.", "we all got out and looked around|and heard absolutely nothing"),
      p("Emphasize the surprising discovery.", "And right behind us was a house with all its lights on.", "Deliver the unexpected detail clearly.", "Vậy mà ngay phía sau|có căn nhà sáng đèn.", "and right behind us|was a house with all its lights on", "Thế mà ngay phía sau|có một căn nhà sáng đèn.", "and right behind us|was a house with all its lights on"),
      p("Resolve the tension efficiently.", "The owner helped restart the car, and twenty minutes later we were moving again.", "Speed up once the central tension is resolved.", "Chủ nhà giúp nổ máy lại,|hai mươi phút sau tụi mình đi tiếp.", "the owner helped restart the car|and twenty minutes later we were moving again", "Chủ nhà giúp khởi động lại xe,|hai mươi phút sau bọn mình đi tiếp.", "the owner helped restart the car|and twenty minutes later we were moving again"),
    ],
  },
  {
    order: 19, unitOrder, unitSlug, unitTitle,
    title: "Tell a funny story well",
    scenario: "Set up, deliver, and recover from a joke that depends on context.",
    difficulty: 4.95,
    rounds: [
      p("Establish your misplaced confidence.", "I told everyone I knew exactly how to assemble the shelf.", "Set up the confidence the joke will overturn.", "Mình tuyên bố với cả nhà|là biết ráp cái kệ này.", "I told everyone|I knew exactly how to assemble the shelf", "Mình tuyên bố với cả nhà|là biết lắp cái kệ này.", "I told everyone|I knew exactly how to assemble the shelf"),
      p("Skip to the revealing result.", "An hour later, there were still four screws left on the floor.", "Move directly to the evidence of failure.", "Một tiếng sau, dưới sàn|vẫn còn dư bốn con ốc.", "an hour later, on the floor|there were still four screws left"),
      p("Quote the perfectly timed comment.", "My brother looked over and said, ‘Those must be decorative.’", "Deliver the punch line through another speaker.", "Anh mình nhìn qua, nói,|‘Chắc ốc để trang trí đó.’", "my brother looked over and said|those must be decorative", "Anh mình nhìn sang, bảo,|‘Chắc ốc để trang trí đấy.’", "my brother looked over and said|those must be decorative"),
      p("Describe the physical payoff.", "The moment I touched the shelf, the whole thing leaned sideways.", "Let the action complete the joke.", "Mình vừa đụng vô cái kệ|là nó nghiêng qua một bên.", "the moment I touched the shelf|the whole thing leaned sideways", "Mình vừa chạm vào cái kệ|là nó nghiêng sang một bên.", "the moment I touched the shelf|the whole thing leaned sideways"),
      p("Laugh at yourself in the ending.", "Since then, nobody lets me assemble anything.", "Close with a lasting consequence that extends the humor.", "Từ bữa đó|không ai cho mình ráp gì nữa.", "since then|nobody lets me assemble anything", "Từ hôm đó|không ai cho mình lắp gì nữa.", "since then|nobody lets me assemble anything"),
    ],
  },
  {
    order: 20, unitOrder, unitSlug, unitTitle,
    title: "Keep a story through interruptions",
    scenario: "Answer questions and return naturally to the thread of a long anecdote.",
    difficulty: 5.0,
    rounds: [
      p("Pause to answer a timing question.", "This was before I moved, so it must have been about six years ago.", "Answer the interruption while anchoring the timeline.", "Chuyện này trước lúc mình chuyển nhà,|chắc cũng sáu năm rồi.", "this was before I moved|so it must have been about six years ago"),
      p("Return to the exact point you left.", "Anyway, as I was saying, we were waiting outside the station.", "Use a natural phrase to resume the narrative.", "Mà mình kể tới đâu rồi?|À, lúc đó tụi mình đang đợi ngoài ga.", "anyway, where was I|right, we were waiting outside the station", "Mà mình kể đến đâu rồi nhỉ?|À, lúc đó bọn mình đang đợi ngoài ga.", "anyway, where was I|right, we were waiting outside the station"),
      p("Clarify a person without losing momentum.", "No, this was the other Hùng—the one who used to live upstairs.", "Resolve identity confusion briefly.", "Không, Hùng này là người khác,|hồi trước ở tầng trên đó.", "no, this was the other Hung|the one who used to live upstairs", "Không, Hùng này là người khác,|trước đây ở tầng trên ấy.", "no, this was the other Hung|the one who used to live upstairs"),
      p("Acknowledge a listener’s prediction.", "Yes, exactly—that’s when we realized we had the wrong tickets.", "Let the interruption help deliver the next event.", "Đúng rồi, chính lúc đó|tụi mình mới biết cầm nhầm vé.", "yes, exactly, that’s when|we realized we had the wrong tickets", "Đúng rồi, chính lúc đó|bọn mình mới biết cầm nhầm vé.", "yes, exactly, that’s when|we realized we had the wrong tickets"),
      p("Finish after several interruptions.", "So the point is, we missed the train but ended up having a better trip.", "Close by stating why the story mattered.", "Nói chung là lỡ chuyến tàu,|mà cuối cùng chuyến đi lại vui hơn.", "the point is, we missed the train|but ended up having a better trip"),
    ],
  },
];
