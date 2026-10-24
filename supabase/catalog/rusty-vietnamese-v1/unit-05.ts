import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 5;
const unitSlug = "emotionally-complex-talk";
const unitTitle = "Handle emotionally complex conversations";

export const unit05: LessonSpec[] = [
  {
    order: 21, unitOrder, unitSlug, unitTitle,
    title: "Comfort someone meaningfully",
    scenario: "Support a friend through disappointment without rushing to fix it.",
    difficulty: 4.55,
    rounds: [
      p("Invite the friend to speak freely.", "If you want to talk about it, I’m here to listen.", "Offer presence without pressuring them.", "Bạn muốn kể thì cứ kể,|mình ngồi nghe nè.", "if you want to talk, go ahead|I’m here to listen", "Bạn muốn kể thì cứ kể,|mình ngồi nghe đây.", "if you want to talk, go ahead|I’m here to listen"),
      p("Validate why the situation hurts.", "You put so much effort into it, so of course you’re disappointed.", "Connect their emotion to what they invested.", "Bạn bỏ công nhiều vậy,|buồn là phải rồi.", "you put so much effort into it|so of course you’re disappointed", "Bạn bỏ công nhiều như thế,|buồn là phải rồi.", "you put so much effort into it|so of course you’re disappointed"),
      p("Avoid a premature positive spin.", "I won’t tell you to cheer up; this really is hard.", "Acknowledge pain without minimizing it.", "Mình không nói bạn đừng buồn đâu,|chuyện này khó chịu thiệt mà.", "I won’t tell you not to be sad|this really is hard", "Mình không bảo bạn đừng buồn đâu,|chuyện này khó chịu thật mà.", "I won’t tell you not to be sad|this really is hard"),
      p("Ask what kind of support is wanted.", "Do you want advice, or do you just need me to listen?", "Let the friend choose the support they need.", "Bạn muốn mình góp ý,|hay chỉ cần mình nghe thôi?", "do you want advice|or do you just need me to listen"),
      p("Offer practical presence afterward.", "You don’t have to decide anything tonight; stay here as long as you need.", "Reduce pressure and make your support concrete.", "Tối nay chưa cần quyết định gì hết,|cứ ở đây bao lâu cũng được.", "you don’t have to decide anything tonight|stay here as long as you need"),
    ],
  },
  {
    order: 22, unitOrder, unitSlug, unitTitle,
    title: "Give honest personal advice",
    scenario: "Offer difficult advice while respecting a friend’s decision.",
    difficulty: 4.6,
    rounds: [
      p("Ask permission before advising.", "Do you want my honest opinion, or do you just want to vent?", "Check whether advice is welcome.", "Bạn muốn nghe mình nói thật,|hay giờ chỉ muốn xả thôi?", "do you want my honest opinion|or do you just want to vent"),
      p("Frame the advice as personal judgment.", "If I were you, I wouldn’t answer while I was still angry.", "Avoid presenting your advice as absolute truth.", "Nếu là mình,|mình chưa trả lời lúc còn giận đâu.", "if I were you|I wouldn’t answer while I was still angry"),
      p("Name the risk behind your advice.", "You may say something you don’t mean and regret it later.", "Explain the likely consequence clearly.", "Có khi bạn nói quá lời,|rồi sau đó lại hối hận.", "you may say something you don’t mean|and regret it later"),
      p("Respect the friend’s final authority.", "Still, you understand the situation better than I do.", "Make clear that the decision remains theirs.", "Nhưng dù sao|bạn hiểu chuyện này hơn mình.", "still|you understand the situation better than I do"),
      p("Commit to support beyond the decision.", "Whatever you choose, call me if you need help.", "Separate friendship from agreement.", "Bạn chọn sao cũng được,|cần gì thì cứ gọi mình.", "whatever you choose|call me if you need help", "Bạn chọn thế nào cũng được,|cần gì thì cứ gọi mình.", "whatever you choose|call me if you need help"),
    ],
  },
  {
    order: 23, unitOrder, unitSlug, unitTitle,
    title: "Set a boundary with an elder",
    scenario: "Protect an adult decision while maintaining respect and affection.",
    difficulty: 4.65,
    rounds: [
      p("Acknowledge the elder’s intention.", "I know you’re saying this because you’re worried about me.", "Recognize care before defending your choice.", "Con biết mẹ nói vậy|là vì lo cho con.", "I know you’re saying this|because you’re worried about me", "Con biết mẹ nói thế|là vì lo cho con ạ.", "I know you’re saying this|because you’re worried about me"),
      p("State that the decision was considered.", "I didn’t decide impulsively; I’ve thought about it for a long time.", "Show that your choice is deliberate.", "Con không quyết định bốc đồng đâu,|con suy nghĩ lâu rồi.", "I didn’t decide impulsively|I’ve thought about it for a long time"),
      p("Set the core boundary clearly.", "I need to make this choice myself, even if it turns out to be wrong.", "Claim responsibility without attacking the elder.", "Dù sau này có sai,|con vẫn cần tự quyết định chuyện này.", "even if it turns out to be wrong|I still need to make this choice myself"),
      p("Ask for a specific form of support.", "You don’t have to agree; I only hope you can respect my decision.", "Separate agreement from respect.", "Mẹ không cần đồng ý,|con chỉ mong mẹ tôn trọng quyết định của con.", "you don’t have to agree|I only hope you can respect my decision"),
      p("Reaffirm the relationship.", "Whatever I decide, I still value what you tell me.", "Keep the disagreement from becoming rejection.", "Dù con quyết định sao,|con vẫn coi trọng lời mẹ nói.", "whatever I decide|I still value what you tell me", "Dù con quyết định thế nào,|con vẫn coi trọng lời mẹ nói ạ.", "whatever I decide|I still value what you tell me"),
    ],
  },
  {
    order: 24, unitOrder, unitSlug, unitTitle,
    title: "Address growing resentment",
    scenario: "Raise a recurring imbalance before it becomes a larger conflict.",
    difficulty: 4.7,
    rounds: [
      p("Choose a calm opening.", "I want to talk now so this doesn’t build into something bigger.", "Explain why you are raising the issue.", "Mình muốn nói ngay,|để chuyện này khỏi dồn lại.", "I want to talk now|so this doesn’t build into something bigger"),
      p("Describe the pattern concretely.", "The last three times, I ended up handling everything alone.", "Name repeated events without using always or never.", "Ba lần gần đây|cuối cùng mình đều phải lo một mình.", "the last three times|I ended up handling everything alone"),
      p("State the emotional effect without blame.", "It leaves me feeling as if my time matters less.", "Describe your interpretation as a feeling.", "Nó làm mình có cảm giác|thời gian của mình không được coi trọng.", "it leaves me feeling|as if my time matters less"),
      p("Invite the other person’s perspective.", "Maybe there’s something going on that I don’t understand.", "Create room for information you may be missing.", "Có thể bạn đang có chuyện|mà mình chưa hiểu.", "maybe there’s something going on|that I don’t understand"),
      p("Request a future change.", "Next time, if you can’t help, please tell me in advance.", "Ask for a specific, achievable behavior.", "Lần sau nếu bạn không phụ được,|nói mình trước nha.", "next time, if you can’t help|please tell me in advance", "Lần sau nếu bạn không giúp được,|nói mình trước nhé.", "next time, if you can’t help|please tell me in advance"),
    ],
  },
  {
    order: 25, unitOrder, unitSlug, unitTitle,
    title: "Repair a damaged relationship",
    scenario: "Acknowledge history and begin rebuilding trust after a serious conflict.",
    difficulty: 4.75,
    rounds: [
      p("Name the unresolved distance.", "I know things have been uncomfortable between us for a long time.", "Acknowledge the relationship as it is now.", "Mình biết lâu nay|hai đứa gặp nhau không được tự nhiên.", "I know for a long time|things have been uncomfortable between us", "Mình biết lâu nay|hai đứa gặp nhau không được thoải mái.", "I know for a long time|things have been uncomfortable between us"),
      p("Own your contribution specifically.", "I avoided the conversation, and that made the situation worse.", "Take responsibility for an action, not just the outcome.", "Mình cứ né không chịu nói,|nên chuyện càng tệ hơn.", "I avoided the conversation|and that made the situation worse"),
      p("Apologize without demanding forgiveness.", "I’m truly sorry; I don’t expect you to forget it immediately.", "Apologize while allowing the other person time.", "Mình thật lòng xin lỗi,|không mong bạn quên ngay đâu.", "I’m truly sorry|I don’t expect you to forget it immediately"),
      p("State what you hope to rebuild.", "I hope we can speak honestly again, even if it takes time.", "Express a realistic relationship goal.", "Mình mong hai đứa nói chuyện thật với nhau lại,|dù phải mất thời gian.", "I hope we can speak honestly again|even if it takes time"),
      p("Invite the next step without pressure.", "When you’re ready, I’d like to hear how this felt for you.", "Give the other person control over timing.", "Khi nào bạn sẵn sàng,|mình muốn nghe bạn nói thật lòng.", "when you’re ready|I’d like to hear how this felt for you"),
    ],
  },
];
