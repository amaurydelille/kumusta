import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 2;
const unitSlug = "real-family-conversations";
const unitTitle = "Navigate real family conversations";

export const unit02: LessonSpec[] = [
  {
    order: 6, unitOrder, unitSlug, unitTitle,
    title: "Catch up with relatives",
    scenario: "Handle several personal questions while reconnecting with family.",
    difficulty: 4.3,
    rounds: [
      p("Respond when an aunt says you look thinner.", "I’ve been busy lately, but I’m still eating normally.", "Reassure her without debating the observation.", "Dạo này con hơi bận,|nhưng vẫn ăn uống bình thường cô ơi.", "I’ve been busy lately|but I’m still eating normally, Auntie", "Dạo này cháu hơi bận,|nhưng vẫn ăn uống bình thường cô ạ.", "I’ve been busy lately|but I’m still eating normally, Auntie"),
      p("Answer a broad work question.", "Work is going well; it’s just a little intense this month.", "Give enough detail to sound open.", "Công việc vẫn ổn,|chỉ là tháng này hơi căng chút.", "work is going well|it’s just a little intense this month"),
      p("Respond about someone who could not attend.", "My sister wanted to come, but she had to work today.", "Explain an absent relative’s situation.", "Chị con cũng muốn qua,|mà hôm nay phải đi làm.", "my sister wanted to come|but she had to work today", "Chị cháu cũng muốn sang,|nhưng hôm nay phải đi làm ạ.", "my sister wanted to come|but she had to work today"),
      p("Turn attention toward the relative.", "And how have you been? Is your knee any better?", "Ask about a specific concern you remember.", "Còn cô dạo này sao rồi?|Đầu gối đỡ chưa cô?", "and how have you been|is your knee any better", "Còn cô dạo này thế nào ạ?|Đầu gối đỡ chưa cô?", "and how have you been|is your knee any better"),
      p("Promise more contact without sounding ceremonial.", "I’ll try to visit more often instead of waiting for a special occasion.", "End with a credible family commitment.", "Để con ráng ghé thường hơn,|không đợi có dịp mới qua.", "I’ll try to visit more often|instead of waiting for a special occasion", "Để cháu cố sang thường xuyên hơn,|không đợi có dịp mới qua ạ.", "I’ll try to visit more often|instead of waiting for a special occasion"),
    ],
  },
  {
    order: 7, unitOrder, unitSlug, unitTitle,
    title: "Hear concern behind criticism",
    scenario: "Interpret and answer family criticism as an expression of care.",
    difficulty: 4.35,
    rounds: [
      p("Your mother says you never rest.", "I know you’re worried about me; I’ll take it easier this weekend.", "Answer the concern beneath the criticism.", "Con biết mẹ lo cho con,|cuối tuần này con sẽ nghỉ ngơi.", "I know you’re worried about me|I’ll take it easier this weekend"),
      p("An uncle criticizes your eating habits.", "You’re right that I eat out too much; I’m trying to cook more.", "Accept the valid part without surrendering the whole point.", "Cậu nói đúng là con ăn ngoài hơi nhiều,|con đang tập nấu ở nhà thêm.", "you’re right that I eat out too much|I’m trying to cook more at home", "Cậu nói đúng là cháu ăn ngoài hơi nhiều,|cháu đang cố nấu ở nhà nhiều hơn ạ.", "you’re right that I eat out too much|I’m trying to cook more at home"),
      p("A relative says you work too far away.", "The commute is long, but the job gives me good opportunities.", "Acknowledge the drawback and explain your choice.", "Đi làm xa thiệt,|nhưng công việc này có nhiều cơ hội.", "the commute is long|but the job gives me good opportunities", "Đi làm xa thật,|nhưng công việc này có nhiều cơ hội ạ.", "the commute is long|but the job gives me good opportunities"),
      p("Your father repeats the same advice.", "I remember what Dad said; I haven’t ignored it.", "Show respect without promising immediate compliance.", "Con nhớ lời ba nói mà,|chứ không phải con bỏ ngoài tai đâu.", "I remember what Dad said|I haven’t ignored it", "Con nhớ lời bố nói mà,|chứ không phải con bỏ ngoài tai đâu ạ.", "I remember what Dad said|I haven’t ignored it"),
      p("Close the discussion reassuringly.", "I’m taking care of myself, so everyone can worry a little less.", "Reassure the family while retaining autonomy.", "Con vẫn tự lo được,|nên cả nhà bớt lo nha.", "I’m taking care of myself|so everyone can worry a little less", "Cháu vẫn tự lo được,|nên cả nhà bớt lo ạ.", "I’m taking care of myself|so everyone can worry a little less"),
    ],
  },
  {
    order: 8, unitOrder, unitSlug, unitTitle,
    title: "Respond to family teasing",
    scenario: "Join affectionate teasing without becoming defensive or disrespectful.",
    difficulty: 4.4,
    rounds: [
      p("An aunt teases you for arriving late.", "I knew I’d get teased the moment I walked in.", "Accept the joke and play along.", "Con biết ngay vừa bước vô|là bị chọc mà.", "I knew the moment I walked in|I’d get teased", "Cháu biết ngay vừa bước vào|là bị trêu mà.", "I knew the moment I walked in|I’d get teased"),
      p("A cousin jokes about your cooking.", "At least nobody got sick last time.", "Reply with self-deprecating humor.", "Ít ra lần trước|đâu có ai ăn xong bị sao.", "at least last time|nobody got sick after eating", "Ít ra lần trước|có ai ăn xong bị làm sao đâu.", "at least last time|nobody got sick after eating"),
      p("Tease a sibling back lightly.", "You’re talking as if you cook every day.", "Return the joke without making it personal.", "Nói nghe như|ngày nào chị cũng nấu vậy.", "you’re talking as if|you cook every day", "Nói nghe như|ngày nào chị cũng nấu thế.", "you’re talking as if|you cook every day"),
      p("Signal when a joke has gone far enough.", "Okay, you’ve had your fun; spare me now.", "Set a playful limit.", "Rồi, chọc đủ rồi nha,|tha cho em đi.", "okay, you’ve had your fun|spare me now", "Rồi, trêu đủ rồi nhé,|tha cho em đi.", "okay, you’ve had your fun|spare me now"),
      p("Keep the mood warm afterward.", "I’m only quiet because I’m hungry, not because I’m upset.", "Prevent a playful boundary from feeling hostile.", "Em im là tại đói thôi,|chứ không có giận đâu.", "I’m only quiet because I’m hungry|not because I’m upset"),
    ],
  },
  {
    order: 9, unitOrder, unitSlug, unitTitle,
    title: "Recognize indirect requests",
    scenario: "Understand what relatives want when they hint instead of asking.",
    difficulty: 4.45,
    rounds: [
      p("Your mother mentions a heavy box.", "Do you want me to move that box inside for you?", "Turn the hint into a helpful offer.", "Mẹ muốn con khiêng thùng đó|vô trong hả?", "do you want me to move that box|inside for you", "Mẹ muốn con bê thùng đó|vào trong ạ?", "do you want me to move that box|inside for you"),
      p("An aunt says her phone is acting strangely.", "Let me take a look; it may just need an update.", "Offer the likely help without waiting to be asked.", "Để con coi thử cho,|chắc điện thoại cần cập nhật thôi.", "let me take a look|it may just need an update", "Để cháu xem thử cho ạ,|chắc điện thoại cần cập nhật thôi.", "let me take a look|it may just need an update"),
      p("A relative repeatedly mentions an event.", "Are you asking whether I can drive everyone there?", "Check your reading of a larger hint.", "Ý cô là muốn con|chở mọi người đi phải không?", "do you mean you want me|to drive everyone there", "Ý cô là muốn cháu|chở mọi người đi phải không ạ?", "do you mean you want me|to drive everyone there"),
      p("You cannot fulfill the implied request.", "I can take everyone there, but I can’t pick them up afterward.", "Offer the part you can realistically do.", "Con chở mọi người đi được,|nhưng lát về thì không đón được.", "I can take everyone there|but I can’t pick them up afterward", "Cháu chở mọi người đi được,|nhưng lúc về thì không đón được ạ.", "I can take everyone there|but I can’t pick them up afterward"),
      p("Make future requests easier to understand.", "Next time, just tell me directly so I can arrange my schedule.", "Invite directness without criticizing the speaker.", "Lần sau cô cứ nói thẳng với con,|để con còn sắp xếp nha.", "next time, just tell me directly|so I can arrange my schedule", "Lần sau cô cứ nói thẳng với cháu,|để cháu còn sắp xếp ạ.", "next time, just tell me directly|so I can arrange my schedule"),
    ],
  },
  {
    order: 10, unitOrder, unitSlug, unitTitle,
    title: "Join a busy family gathering",
    scenario: "Follow overlapping needs and participate naturally at a family meal.",
    difficulty: 4.5,
    rounds: [
      p("Offer useful help on arrival.", "What still needs doing? I can help in the kitchen.", "Ask for a concrete task instead of waiting.", "Còn gì chưa làm không?|Để con phụ trong bếp.", "what still needs doing|I can help in the kitchen", "Còn gì chưa làm không ạ?|Để cháu phụ trong bếp.", "what still needs doing|I can help in the kitchen"),
      p("Relay a message across the room.", "Mom said to bring the soup out once everyone sits down.", "Pass along an instruction with its timing.", "Mẹ nói khi nào mọi người ngồi đủ|thì bưng canh ra.", "Mom said once everyone sits down|bring the soup out"),
      p("Answer one question while tracking another conversation.", "Yes, work is fine. Wait, who did you say is moving?", "Return naturally to something you overheard.", "Dạ, công việc vẫn ổn.|Ủa, nãy cô nói ai sắp chuyển nhà?", "yes, work is fine|wait, who did you say is moving", "Dạ, công việc vẫn ổn ạ.|Ơ, lúc nãy cô nói ai sắp chuyển nhà?", "yes, work is fine|wait, who did you say is moving"),
      p("Include a quiet relative.", "Grandpa, what do you think? You haven’t said anything yet.", "Invite an elder into the discussion respectfully.", "Ông thấy sao ạ?|Nãy giờ con chưa nghe ông nói.", "Grandpa, what do you think|you haven’t said anything yet", "Ông thấy thế nào ạ?|Nãy giờ cháu chưa nghe ông nói.", "Grandpa, what do you think|you haven’t said anything yet"),
      p("Help the gathering wind down.", "You all keep talking; I’ll clear the table first.", "Take initiative without ending the conversation.", "Mọi người cứ nói chuyện tiếp đi,|để con dọn bàn trước.", "you all keep talking|I’ll clear the table first", "Mọi người cứ nói chuyện tiếp đi ạ,|để cháu dọn bàn trước.", "you all keep talking|I’ll clear the table first"),
    ],
  },
];
