import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 3;
const unitSlug = "read-between-lines";
const unitTitle = "Read between the lines";

export const unit03: LessonSpec[] = [
  {
    order: 11, unitOrder, unitSlug, unitTitle,
    title: "Recognize a polite refusal",
    scenario: "Hear when a soft answer actually means no or probably not.",
    difficulty: 4.55,
    rounds: [
      p("A friend answers an invitation vaguely.", "They said they’d see, but it sounded like they probably wouldn’t come.", "Interpret the likely meaning behind the words.", "Bạn ấy nói để coi,|mà nghe như chắc không đi.", "they said they’d see|but it sounded like they probably wouldn’t come", "Bạn ấy bảo để xem,|nhưng nghe như chắc không đi.", "they said they’d see|but it sounded like they probably wouldn’t come"),
      p("Decline without giving a hard no.", "This week may be difficult; perhaps we should leave it for another time.", "Give a socially clear soft refusal.", "Tuần này chắc hơi khó,|hay để bữa khác nha.", "this week may be difficult|perhaps we should leave it for another time", "Tuần này chắc hơi khó,|hay để hôm khác nhé.", "this week may be difficult|perhaps we should leave it for another time"),
      p("Check whether a vague answer is firm.", "Should I keep a place for you, or is it better not to count you in?", "Ask for clarity without cornering the person.", "Vậy mình giữ chỗ cho bạn,|hay tạm thời không tính nha?", "should I keep a place for you|or is it better not to count you in", "Vậy mình giữ chỗ cho bạn,|hay tạm thời không tính nhé?", "should I keep a place for you|or is it better not to count you in"),
      p("Explain a soft refusal to someone else.", "When she says ‘maybe later,’ she usually means she doesn’t want to go.", "Describe a familiar indirect pattern.", "Chị ấy nói để khi khác|thường là không muốn đi đó.", "when she says maybe later|she usually means she doesn’t want to go", "Chị ấy nói để khi khác|thường là không muốn đi đấy.", "when she says maybe later|she usually means she doesn’t want to go"),
      p("Accept the refusal gracefully.", "No worries, we’ll invite you again another time.", "Leave the relationship comfortable.", "Không sao đâu,|bữa khác tụi mình rủ tiếp.", "no worries|we’ll invite you again another time", "Không sao đâu,|hôm khác bọn mình lại rủ.", "no worries|we’ll invite you again another time"),
    ],
  },
  {
    order: 12, unitOrder, unitSlug, unitTitle,
    title: "Suggest without pushing",
    scenario: "Guide someone toward an option while leaving them room to decide.",
    difficulty: 4.6,
    rounds: [
      p("Raise an alternative delicately.", "I wonder whether leaving a little earlier might be easier.", "Float an idea instead of issuing an instruction.", "Hay là mình đi sớm hơn chút|thì đỡ hơn không ta?", "I wonder whether leaving a little earlier|might be easier", "Hay là mình đi sớm hơn một chút|thì có đỡ hơn không nhỉ?", "I wonder whether leaving a little earlier|might be easier"),
      p("Use experience to support the hint.", "That road gets very congested after five.", "Give context that lets the listener infer your recommendation.", "Đường đó sau năm giờ|kẹt dữ lắm.", "that road after five|gets very congested", "Đường đó sau năm giờ|tắc lắm.", "that road after five|gets very congested"),
      p("Recommend a change while preserving choice.", "If it were me, I’d take the train, but see what works for you.", "Offer personal judgment without controlling the decision.", "Nếu là mình thì mình đi tàu,|còn bạn thấy sao tiện thì làm.", "if it were me, I’d take the train|but see what works for you"),
      p("Hint that a plan may be too expensive.", "That place looks nice, though the price is a little steep.", "Surface a concern without rejecting the plan outright.", "Chỗ đó nhìn cũng đẹp,|có điều giá hơi cao.", "that place looks nice|though the price is a little steep"),
      p("Let the group own the final choice.", "I’m fine either way; I just wanted everyone to consider it.", "Step back after making your point.", "Mình sao cũng được,|chỉ nói để mọi người cân nhắc thôi.", "I’m fine either way|I just wanted everyone to consider it"),
    ],
  },
  {
    order: 13, unitOrder, unitSlug, unitTitle,
    title: "Disagree without causing embarrassment",
    scenario: "Correct a mistaken claim while helping the speaker save face.",
    difficulty: 4.65,
    rounds: [
      p("Open by validating part of the claim.", "That used to be true, but I think the rule has changed.", "Correct the timing rather than attacking the speaker.", "Hồi trước đúng là vậy,|nhưng hình như quy định đổi rồi.", "that used to be true|but I think the rule has changed", "Trước đây đúng là thế,|nhưng hình như quy định đổi rồi.", "that used to be true|but I think the rule has changed"),
      p("Present evidence modestly.", "I may be remembering wrong, but I read the new notice yesterday.", "Keep the correction open to verification.", "Có thể mình nhớ nhầm,|nhưng hôm qua mình có đọc thông báo mới.", "I may be remembering wrong|but I read the new notice yesterday"),
      p("Correct someone privately.", "I didn’t want to mention it in front of everyone, but that figure seems off.", "Protect the other person’s public dignity.", "Nãy đông người nên mình không nói,|chứ con số đó hình như chưa đúng.", "I didn’t mention it in front of everyone|but that figure seems off", "Lúc nãy đông người nên mình không nói,|nhưng con số đó hình như chưa đúng.", "I didn’t mention it in front of everyone|but that figure seems off"),
      p("Invite joint verification.", "Let’s check it again together so we’re both sure.", "Turn correction into collaboration.", "Để hai đứa coi lại chung,|cho chắc nha.", "let’s check it again together|so we’re both sure", "Để hai đứa mình xem lại cùng nhau,|cho chắc nhé.", "let’s check it again together|so we’re both sure"),
      p("Close without dwelling on blame.", "It’s an easy detail to miss; the important thing is we caught it.", "Normalize the mistake and move forward.", "Chỗ đó dễ sót lắm,|quan trọng là mình phát hiện kịp.", "it’s an easy detail to miss|the important thing is we caught it"),
    ],
  },
  {
    order: 14, unitOrder, unitSlug, unitTitle,
    title: "Separate fact from hearsay",
    scenario: "Make clear what you know, heard, inferred, and still need to verify.",
    difficulty: 4.7,
    rounds: [
      p("Report unconfirmed news responsibly.", "I heard they may be moving, but I don’t know whether it’s confirmed.", "Mark the information as hearsay.", "Nghe nói họ sắp chuyển đi,|mà mình chưa biết có chắc không.", "I heard they may be moving|but I don’t know whether it’s confirmed"),
      p("State what you observed directly.", "All I know is that someone came to view their apartment yesterday.", "Separate direct evidence from the rumor.", "Mình chỉ biết là hôm qua|có người tới coi nhà họ.", "all I know is that yesterday|someone came to view their apartment", "Mình chỉ biết là hôm qua|có người đến xem nhà họ.", "all I know is that yesterday|someone came to view their apartment"),
      p("Offer an inference carefully.", "Maybe they’re only looking for a roommate; that’s possible too.", "Present another explanation as a possibility.", "Có khi họ chỉ tìm người ở ghép,|cũng chưa biết chừng.", "maybe they’re only looking for a roommate|that’s possible too"),
      p("Refuse to spread uncertain details.", "I’d rather not tell anyone else until we know for sure.", "Stop a rumor without sounding self-righteous.", "Chưa rõ thì|mình khoan kể cho ai khác.", "until we know for sure|I’d rather not tell anyone else"),
      p("Propose a direct way to verify.", "When I see her, I’ll ask gently instead of guessing.", "Choose respectful confirmation over speculation.", "Bữa nào gặp chị ấy|mình hỏi khéo thử.", "when I see her|I’ll ask gently", "Hôm nào gặp chị ấy|mình sẽ hỏi khéo xem.", "when I see her|I’ll ask gently"),
    ],
  },
  {
    order: 15, unitOrder, unitSlug, unitTitle,
    title: "Understand what was implied",
    scenario: "Interpret a conversation whose real message is never said directly.",
    difficulty: 4.75,
    rounds: [
      p("Notice a host mentioning the time.", "When the host kept saying tomorrow would start early, I knew it was time to leave.", "Explain the social signal you recognized.", "Chủ nhà cứ nói mai phải dậy sớm,|là mình biết tới lúc về rồi.", "the host kept saying tomorrow would start early|so I knew it was time to leave", "Chủ nhà cứ nói mai phải dậy sớm,|là mình biết đến lúc về rồi.", "the host kept saying tomorrow would start early|so I knew it was time to leave"),
      p("Interpret restrained praise.", "He said the idea was ‘interesting,’ but his tone showed he wasn’t convinced.", "Read tone together with literal meaning.", "Anh ấy nói ý tưởng thú vị,|mà giọng nghe không có vẻ tin lắm.", "he said the idea was interesting|but his tone showed he wasn’t convinced"),
      p("Recognize a request hidden in a comment.", "When Mom said the kitchen was messy, she meant she wanted us to clean it.", "State the intended action behind the observation.", "Mẹ nói bếp bừa bộn|là muốn tụi mình dọn đó.", "when Mom said the kitchen was messy|she meant she wanted us to clean it", "Mẹ nói bếp bừa bộn|là muốn bọn mình dọn đấy.", "when Mom said the kitchen was messy|she meant she wanted us to clean it"),
      p("Check subtext when stakes matter.", "Are you saying you need more time, or that you don’t want to do it?", "Turn ambiguous subtext into a respectful direct question.", "Ý bạn là cần thêm thời gian,|hay là không muốn làm nữa?", "are you saying you need more time|or that you don’t want to do it"),
      p("Summarize the actual message.", "Nobody said no, but it was clear the group wasn’t ready to agree.", "Describe a shared implicit conclusion.", "Không ai nói không,|nhưng rõ là mọi người chưa muốn đồng ý.", "nobody said no|but it was clear the group wasn’t ready to agree"),
    ],
  },
];
