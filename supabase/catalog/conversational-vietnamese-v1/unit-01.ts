import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 1;
const unitSlug = "keep-conversation-moving";
const unitTitle = "Keep the conversation moving";

export const unit01: LessonSpec[] = [
  {
    order: 1, unitOrder, unitSlug, unitTitle,
    title: "What have you been up to?",
    scenario: "Catch up with a friend and give a meaningful update about recent life.",
    difficulty: 3.05,
    rounds: [
      p("A friend asks what is new with you.", "Nothing major, I’ve just been pretty busy with work lately.", "Give a relaxed update about your life.", [["Cũng không có gì mới,", "nothing major"], ["dạo này mình hơi bận công việc thôi.", "I’ve just been pretty busy with work lately"]]),
      p("Explain a recent change in your routine.", "I recently started going to the gym after work.", "Describe a new habit you have started.", [["Dạo này", "recently"], ["mình mới bắt đầu đi tập sau giờ làm.", "I started going to the gym after work"]]),
      p("Say how the new routine is going.", "It’s tiring, but I’m gradually getting used to it.", "Balance a difficulty with progress.", [["Mệt thì cũng mệt,", "it’s tiring"], ["nhưng mình quen dần rồi.", "but I’m gradually getting used to it"]]),
      p("Mention something you have not had time for.", "I haven’t had much time to meet everyone lately.", "Explain what your schedule has limited.", [["Dạo này mình không có nhiều thời gian", "I haven’t had much time lately"], ["để gặp mọi người.", "to meet everyone"]]),
      p("Turn the conversation back to your friend.", "What about you? Is everything still the same at work?", "Ask for a specific update in return.", [["Còn bạn thì sao?", "what about you"], ["Công việc vẫn vậy hả?", "is everything still the same at work"]], [["Còn bạn thì sao?", "what about you"], ["Công việc vẫn thế à?", "is everything still the same at work"]]),
    ],
  },
  {
    order: 2, unitOrder, unitSlug, unitTitle,
    title: "Ask better follow-up questions",
    scenario: "Show genuine interest while a friend talks about a new job.",
    difficulty: 3.1,
    rounds: [
      p("Your friend says they changed jobs.", "Really? When did you start the new job?", "React and ask when the change happened.", [["Vậy hả?", "really"], ["Bạn bắt đầu việc mới khi nào?", "when did you start the new job"]], [["Thế à?", "really"], ["Bạn bắt đầu công việc mới khi nào?", "when did you start the new job"]]),
      p("Ask what motivated the decision.", "What made you decide to switch?", "Ask naturally about the reason for changing jobs.", [["Sao tự nhiên", "what made you"], ["bạn quyết định đổi vậy?", "decide to switch"]], [["Sao tự nhiên", "what made you"], ["bạn quyết định đổi thế?", "decide to switch"]]),
      p("Ask about the new environment.", "How are the people on the new team?", "Invite your friend to describe their coworkers.", [["Mọi người ở nhóm mới", "the people on the new team"], ["thế nào?", "how are they"]]),
      p("Follow up on a concern they mentioned.", "So is the commute much farther than before?", "Check a practical detail from the story.", [["Vậy là đi làm", "so the commute"], ["xa hơn hồi trước nhiều hả?", "is much farther than before"]], [["Thế là đi làm", "so the commute"], ["xa hơn trước nhiều à?", "is much farther than before"]]),
      p("Ask how they feel overall.", "All things considered, are you happy with the change?", "Ask for their overall judgment.", [["Nói chung", "all things considered"], ["bạn thấy đổi vậy ổn không?", "are you happy with the change"]], [["Nói chung", "all things considered"], ["bạn thấy đổi như thế ổn không?", "are you happy with the change"]]),
    ],
  },
  {
    order: 3, unitOrder, unitSlug, unitTitle,
    title: "React naturally",
    scenario: "Respond naturally as a friend shares good news and a setback.",
    difficulty: 3.15,
    rounds: [
      p("Your friend says they passed an interview.", "That’s great! I knew you could do it.", "Celebrate warmly without sounding formal.", [["Hay quá!", "that’s great"], ["Mình biết là bạn làm được mà.", "I knew you could do it"]]),
      p("They explain that the process took months.", "No wonder you looked stressed all this time.", "Connect the news to something you noticed.", [["Hèn chi", "no wonder"], ["mấy bữa nay thấy bạn căng thẳng.", "you looked stressed all this time"]], [["Bảo sao", "no wonder"], ["dạo này thấy bạn căng thẳng.", "you looked stressed all this time"]]),
      p("They say the start date was delayed.", "Oh, that’s a bit frustrating.", "Show mild sympathy about the setback.", [["Ủa, vậy cũng", "oh, that’s"], ["hơi phiền ha.", "a bit frustrating"]], [["Ôi, thế cũng", "oh, that’s"], ["hơi phiền nhỉ.", "a bit frustrating"]]),
      p("They say the delay gives them time to rest.", "Actually, when you put it that way, that’s not bad.", "Reconsider the situation positively.", [["Mà nghĩ vậy thì", "actually, when you put it that way"], ["cũng không tệ.", "that’s not bad"]], [["Mà nghĩ thế thì", "actually, when you put it that way"], ["cũng không tệ.", "that’s not bad"]]),
      p("End with sincere encouragement.", "Either way, I’m really happy for you.", "Express support whatever happens next.", [["Dù sao thì", "either way"], ["mình cũng mừng cho bạn lắm.", "I’m really happy for you"]]),
    ],
  },
  {
    order: 4, unitOrder, unitSlug, unitTitle,
    title: "Explain yourself more clearly",
    scenario: "Rephrase and add context when someone misunderstands what you mean.",
    difficulty: 3.2,
    rounds: [
      p("A friend misunderstands your comment.", "No, that’s not quite what I meant.", "Signal a misunderstanding gently.", [["Không,", "no"], ["ý mình không hẳn là vậy.", "that’s not quite what I meant"]], [["Không,", "no"], ["ý mình không hẳn là thế.", "that’s not quite what I meant"]]),
      p("State your actual point.", "What I mean is that we should wait a little longer.", "Introduce a clearer version of your point.", [["Ý mình là", "what I mean is"], ["tụi mình nên chờ thêm chút nữa.", "we should wait a little longer"]], [["Ý mình là", "what I mean is"], ["bọn mình nên chờ thêm một chút.", "we should wait a little longer"]]),
      p("Explain why waiting matters.", "If we decide now, it might be a little rushed.", "Add the consequence behind your point.", [["Quyết định bây giờ", "if we decide now"], ["thì có khi hơi gấp.", "it might be a little rushed"]]),
      p("Make clear that you are not refusing.", "I’m not saying no; I just want to think it through.", "Separate hesitation from refusal.", [["Mình đâu có nói không,", "I’m not saying no"], ["mình chỉ muốn suy nghĩ kỹ thôi.", "I just want to think it through"]]),
      p("Check that the listener now understands.", "Do you see what I mean now?", "Confirm that your explanation landed.", [["Giờ bạn hiểu", "do you understand now"], ["ý mình chưa?", "what I mean"]], [["Giờ bạn hiểu", "do you understand now"], ["ý mình chưa?", "what I mean"]]),
    ],
  },
  {
    order: 5, unitOrder, unitSlug, unitTitle,
    title: "Have a proper catch-up",
    scenario: "Carry a catch-up from an opening update to a natural goodbye.",
    difficulty: 3.25,
    rounds: [
      p("Open after not seeing a friend for months.", "It’s been so long. You look exactly the same.", "Greet an old friend warmly.", [["Lâu quá mới gặp,", "it’s been so long"], ["trông bạn vẫn y chang.", "you look exactly the same"]], [["Lâu quá mới gặp,", "it’s been so long"], ["trông bạn vẫn y như trước.", "you look exactly the same"]]),
      p("Give the headline of your own update.", "I moved recently, so everything has been a little hectic.", "Share one important recent change.", [["Mình mới chuyển nhà,", "I moved recently"], ["nên mọi thứ hơi lu bu.", "so everything has been a little hectic"]], [["Mình mới chuyển nhà,", "I moved recently"], ["nên mọi thứ hơi bận rộn.", "so everything has been a little hectic"]]),
      p("Ask about something you remember.", "How is that project you told me about last time?", "Reconnect to a detail from your last conversation.", [["Còn dự án", "how is that project"], ["bữa trước bạn kể sao rồi?", "you told me about last time"]], [["Còn dự án", "how is that project"], ["lần trước bạn kể thế nào rồi?", "you told me about last time"]]),
      p("Acknowledge that time has passed quickly.", "Talking like this makes me realize how fast time goes.", "Reflect naturally during the catch-up.", [["Nói chuyện mới thấy", "talking like this makes me realize"], ["thời gian trôi nhanh thiệt.", "how fast time goes"]], [["Nói chuyện mới thấy", "talking like this makes me realize"], ["thời gian trôi nhanh thật.", "how fast time goes"]]),
      p("End while suggesting another meeting.", "Let’s not wait this long before meeting again.", "Close warmly and suggest staying in touch.", [["Bữa sau đừng để lâu vậy", "next time let’s not wait this long"], ["rồi mới gặp nữa nha.", "before meeting again"]], [["Lần sau đừng để lâu thế", "next time let’s not wait this long"], ["rồi mới gặp nhau nữa nhé.", "before meeting again"]]),
    ],
  },
];
