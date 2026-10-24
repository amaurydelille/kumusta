import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const holdYourOwn = { unitOrder: 1, unitSlug: "hold-your-own", unitTitle: "Hold your own" };
const soundLikeALocal = {
  unitOrder: 2,
  unitSlug: "sound-like-a-local",
  unitTitle: "Sound like a local",
};
const lifesBigMoments = {
  unitOrder: 3,
  unitSlug: "lifes-big-moments",
  unitTitle: "Life's big moments",
};

export const advancedLessons: LessonSpec[] = [
  {
    order: 1,
    ...holdYourOwn,
    title: "Meeting your partner's parents",
    scenario: "Win over your partner's parents at dinner and dodge the wedding talk.",
    difficulty: 3.05,
    goalTags: ["partner", "family", "culture"],
    rounds: [
      r(
        "You arrive for dinner at your partner's family home. Their parents, Tito Ben and Tita Lorna, open the door.",
        "Good evening, Tito, Tita. I brought some leche flan; I hope you like it.",
        "Greet both parents respectfully and offer the dessert you brought.",
        [
          s(
            "Magandang gabi po, Tito, Tita.",
            "good evening, Tito, Tita",
            "A partner's parents are usually Tito and Tita, always with po.",
          ),
          s(
            "May dala po akong leche flan,",
            "I brought some leche flan",
            "Never arrive empty-handed: 'may dala' means you brought something along.",
          ),
          s(
            "sana magustuhan ninyo.",
            "I hope you'll like it",
            "Ninyo is the respectful 'you' here, as the ones doing the liking.",
          ),
        ],
      ),
      r(
        "Dinner is served, and Tita Lorna's kare-kare is excellent. She watches you take the first bite.",
        "Your kare-kare is so delicious, Tita! Did you cook this yourself?",
        "Compliment her cooking warmly and ask whether she made it herself.",
        [
          s(
            "Ang sarap po ng kare-kare ninyo, Tita!",
            "your kare-kare is so delicious, Tita!",
            "Ang + adjective is an exclamation: 'so tasty!'. Po sits right after the first word.",
          ),
          s(
            "Kayo po ba mismo",
            "was it you yourself",
            "Mismo means 'yourself, in person'; ba turns it into a question.",
          ),
          s("ang nagluto nito?", "who cooked this?", "Nagluto = cooked (completed action)."),
        ],
      ),
      r(
        "Tito Ben puts down his spoon and asks what you do for a living. This is your chance to sound serious.",
        "I work at a BPO in Makati, and we're already saving up for a house of our own.",
        "Tell him where you work and that the two of you are saving for a home.",
        [
          s(
            "Nagtatrabaho po ako",
            "I work",
            "Nagtatrabaho is the ongoing aspect: 'am working'.",
          ),
          s(
            "sa isang BPO sa Makati,",
            "at a BPO in Makati",
            "BPO (outsourcing, call centres) stays in English, as in any Manila conversation.",
          ),
          s(
            "at nag-iipon na rin po kami",
            "and we're already saving up too",
            "Kami is 'we' without the listener: you and your partner, not Tito.",
          ),
          s("para sa sariling bahay.", "for a house of our own", "Sarili + -ng = 'own'."),
        ],
      ),
      r(
        "Tita Lorna leans in with a big smile and asks when the wedding is. The whole table goes quiet.",
        "Oh, Tita, we're already talking about it. But of course, we want to be truly ready first.",
        "Laugh it off gently: say you're discussing it, but want to be ready first.",
        [
          s("Naku, Tita,", "oh my, Tita", "Naku buys you a second and keeps the mood light."),
          s(
            "pinag-uusapan na po namin 'yan.",
            "we're already talking about that",
            "Pinag-uusapan = being discussed (ongoing); namin = by us.",
          ),
          s("Pero siyempre,", "but of course"),
          s(
            "gusto muna naming maging handa talaga.",
            "we want to be really ready first",
            "Muna means 'first, for now': the polite way to buy time.",
          ),
        ],
      ),
      r(
        "The evening is over. As you leave, you take each parent's hand for the traditional blessing.",
        "Bless me, Tito, Tita. Thank you for the wonderful dinner; next time I'll do the cooking.",
        "Ask for their blessing, thank them for dinner, and offer to cook next time.",
        [
          s(
            "Mano po, Tito, Tita.",
            "your hand for a blessing, Tito, Tita",
            "Say it as you press their hand to your forehead: the mano.",
          ),
          s(
            "Salamat po sa napakasarap na hapunan.",
            "thank you for the wonderful dinner",
            "Napaka- + adjective = 'very, so'.",
          ),
          s(
            "Next time, ako na po ang magluluto.",
            "next time, I'll be the one cooking",
            "Magluluto is the future aspect; 'ako na' = 'let me take over'.",
          ),
        ],
      ),
    ],
  },
  {
    order: 2,
    ...holdYourOwn,
    title: "Chismis with your best friend",
    scenario: "Share family gossip with your best friend and swear them to secrecy.",
    difficulty: 3.1,
    goalTags: ["family", "culture"],
    rounds: [
      r(
        "You're having merienda with your best friend at a cafe. You can't hold the news in any longer.",
        "Bestie, I've got some gossip for you, but promise this stays between the two of us, okay?",
        "Tell your friend you have juicy news, and make them promise to keep it secret.",
        [
          s(
            "Bes, may chika ako sa'yo,",
            "bestie, I've got some news for you",
            "Bes (from bestie) works for any close friend; chika = gossip, the latest.",
          ),
          s("pero promise,", "but promise"),
          s(
            "sa ating dalawa lang 'to, ha?",
            "this stays between the two of us, okay?",
            "Ha? at the end asks for agreement, like 'okay?'.",
          ),
        ],
      ),
      r(
        "Your friend leans in. Spill it: your cousin Mark has secretly proposed to his girlfriend Liza.",
        "Apparently my cousin Mark proposed to Liza, but Tita Baby doesn't know yet!",
        "Share the news you heard about your cousin, and that his mum hasn't been told.",
        [
          s(
            "'Yung pinsan kong si Mark,",
            "my cousin Mark",
            "Opening with 'yung + the person sets up the story, very conversational.",
          ),
          s(
            "nag-propose na raw kay Liza,",
            "apparently already proposed to Liza",
            "Raw (daw after consonants) = 'reportedly': the essential gossip word.",
          ),
          s(
            "pero hindi pa alam ni Tita Baby!",
            "but Tita Baby doesn't know yet!",
            "Hindi pa = not yet.",
          ),
        ],
      ),
      r(
        "Your friend asks how you could possibly know that. Explain what you spotted online.",
        "I saw the ring on her IG story, and then she deleted it right away after five minutes.",
        "Explain that you saw the ring on social media before it was quickly deleted.",
        [
          s(
            "Nakita ko kasi 'yung singsing",
            "because I saw the ring",
            "Kasi ('because') often comes right after the first words in casual talk.",
          ),
          s("sa IG story niya,", "on her IG story"),
          s(
            "tapos dinelete niya agad",
            "then she deleted it right away",
            "Dinelete: an English verb with the Tagalog -in- infix for a completed action.",
          ),
          s(
            "after five minutes.",
            "after five minutes",
            "Manila speakers often switch to English for small numbers and times like this.",
          ),
        ],
      ),
      r(
        "Your friend's eyes light up. Remind them how much trouble you'd be in if this got out.",
        "Don't spread it around, okay? If Tita finds out it came from me, I'm dead.",
        "Warn your friend not to spread it, and say what happens if your aunt traces it to you.",
        [
          s(
            "Huwag mong ikakalat, ha?",
            "don't you spread it around, okay?",
            "Huwag + mo + -ng + verb = 'don't you ...'.",
          ),
          s(
            "Pag nalaman ni Tita",
            "if Tita finds out",
            "Pag (short for kapag) = 'if, when'; nalaman = found out.",
          ),
          s("na sa akin galing,", "that it came from me"),
          s("patay ako.", "I'm dead", "Playful exaggeration, exactly like the English."),
        ],
      ),
      r(
        "Your friend laughs and calls you the family gossip. Defend yourself, jokingly.",
        "Hey, I'm not a gossip! I'm just a concerned citizen, and you're the only one I've told.",
        "Deny being a gossip, joke about being a concerned citizen, and say only they know.",
        [
          s(
            "Hoy, hindi ako Marites, ha!",
            "hey, I'm not a gossip, okay!",
            "Marites (from 'Mare, ano'ng latest?') is the playful nickname for a gossip.",
          ),
          s(
            "Concerned citizen lang ako,",
            "I'm just a concerned citizen",
            "A classic tongue-in-cheek Taglish defence.",
          ),
          s(
            "at ikaw lang naman ang sinabihan ko.",
            "and you're the only one I told anyway",
            "Naman softens it: 'it's only you, after all'.",
          ),
        ],
      ),
    ],
  },
  {
    order: 3,
    ...holdYourOwn,
    title: "The big debate: working abroad or staying home",
    scenario: "Disagree respectfully with Tito about working abroad or staying home.",
    difficulty: 3.15,
    goalTags: ["family", "work", "lifeInThePhilippines"],
    rounds: [
      r(
        "At a family lunch, Tito Ramon, a former OFW, insists every young person should work overseas.",
        "I understand your point, Tito; the pay abroad really is much bigger.",
        "Open by showing him you understand his point about the salary.",
        [
          s(
            "Naiintindihan ko po",
            "I understand",
            "Agreeing first is the polite way into a disagreement with an elder.",
          ),
          s("ang punto ninyo, Tito,", "your point, Tito"),
          s(
            "mas malaki talaga ang sweldo sa abroad.",
            "the salary abroad really is bigger",
            "'Sa abroad' is everyday Taglish for working overseas.",
          ),
        ],
      ),
      r(
        "Tito Ramon nods, waiting for your 'but'. Gently bring in the other side.",
        "But in my view, not everything can be paid for with money, especially time with family.",
        "Respectfully say that money can't buy everything, especially family time.",
        [
          s(
            "Pero sa tingin ko po,",
            "but in my opinion",
            "Sa tingin ko ('the way I see it') is much softer than a flat no.",
          ),
          s(
            "hindi lahat ng bagay nababayaran ng pera,",
            "not everything can be paid for with money",
            "Nababayaran = can be paid for (abilitative).",
          ),
          s("lalo na 'yung oras kasama ang pamilya.", "especially time spent with family"),
        ],
      ),
      r(
        "Tito Ramon reminds you he spent twelve years in Dubai so his children could study.",
        "I know you sacrificed a lot, and that's why my cousins were able to finish school.",
        "Honour his sacrifice and acknowledge what it made possible for your cousins.",
        [
          s(
            "Alam ko pong",
            "I know (respectfully)",
            "Po + the linker -ng becomes 'pong' before the next clause.",
          ),
          s("malaki ang naisakripisyo ninyo,", "you sacrificed a great deal"),
          s(
            "kaya nakapagtapos ang mga pinsan ko.",
            "that's why my cousins managed to graduate",
            "Nakapag- = managed to; kaya = so, that's why.",
          ),
        ],
      ),
      r(
        "He asks you straight out what you would do in his shoes. State your own position.",
        "But if there's decent work here, I'd rather stay and help our own country.",
        "Say that, given decent work at home, you'd prefer to stay and help the country.",
        [
          s(
            "Pero kung may maayos na trabaho naman dito,",
            "but if there's decent work here anyway",
          ),
          s(
            "mas gusto ko pong manatili",
            "I'd prefer to stay",
            "Mas gusto = prefer; manatili is a slightly formal 'remain', good for a serious point.",
          ),
          s(
            "at tumulong sa sarili nating bayan.",
            "and help our own country",
            "Natin includes Tito: it's his country too.",
          ),
        ],
      ),
      r(
        "The debate is getting warm and Tita is giving you both a look. Close it gracefully.",
        "Maybe we're both right; it really just depends on each family's situation.",
        "Suggest you're both right and that it depends on each family.",
        [
          s("Siguro po,", "maybe"),
          s(
            "pareho tayong tama,",
            "we're both right",
            "Tayo includes the listener: a gracious way to end a debate.",
          ),
          s(
            "depende lang talaga sa sitwasyon ng bawat pamilya.",
            "it really just depends on each family's situation",
          ),
        ],
      ),
    ],
  },
  {
    order: 4,
    ...soundLikeALocal,
    title: "Hay naku, sayang, bahala na: everyday expressions",
    scenario: "Miss the last bus with a friend and react like a true local.",
    difficulty: 3.2,
    goalTags: ["lifeInThePhilippines", "travel", "culture"],
    rounds: [
      r(
        "You and your friend Migs run into the Cubao bus terminal, sweaty after an hour stuck on the highway.",
        "Oh man, the traffic on EDSA! The last bus to Baguio already left.",
        "Sigh about the traffic and break the news that the last bus is gone.",
        [
          s(
            "Hay naku,",
            "oh, good grief",
            "Hay naku is the all-purpose sigh of exasperation.",
          ),
          s(
            "ang traffic sa EDSA!",
            "the traffic on EDSA!",
            "Ang + noun works as an exclamation: 'such traffic!'.",
          ),
          s("Umalis na 'yung huling bus papuntang Baguio.", "the last bus to Baguio already left"),
        ],
      ),
      r(
        "Migs waves the two printed tickets you bought online. Now they're useless.",
        "What a waste of our tickets, and we even paid for them in full yesterday!",
        "Lament the wasted tickets and point out you'd already paid in full.",
        [
          s(
            "Sayang 'yung ticket natin,",
            "what a waste, our tickets",
            "Sayang = 'what a waste, too bad': hard to translate, used constantly.",
          ),
          s(
            "binayaran pa naman natin",
            "and to think we even paid for them",
            "Pa naman adds 'and to think we even ...'.",
          ),
          s(
            "nang buo kahapon!",
            "in full yesterday!",
            "Nang (not ng) introduces how something was done.",
          ),
        ],
      ),
      r(
        "There's a provincial bus leaving in ten minutes, with no guarantee of seats. Make the call.",
        "Okay, come what may! Let's just take any bus, as long as we get there before twelve.",
        "Decide to risk it: take any bus, as long as you arrive before midnight.",
        [
          s(
            "Sige, bahala na!",
            "okay, come what may!",
            "Bahala na = 'leave it to fate': part courage, part shrug.",
          ),
          s(
            "Sakay na lang tayo ng kahit anong bus,",
            "let's just ride any bus",
            "Na lang = 'just, instead', for a fallback plan.",
          ),
          s(
            "basta makarating tayo bago mag-alas dose.",
            "as long as we get there before twelve",
            "Clock times use Spanish numbers: alas dose = twelve o'clock.",
          ),
        ],
      ),
      r(
        "Somehow Migs talks to the conductor and gets you two seats right behind the driver.",
        "You got two seats at the front? Your street smarts are something else, you're the best!",
        "Praise how resourceful he is, half impressed and half teasing.",
        [
          s(
            "Nakakuha ka ng dalawang upuan sa harap?",
            "you got two seats up front?",
            "Nakakuha = managed to get.",
          ),
          s(
            "Iba talaga ang diskarte mo,",
            "your hustle is really something else",
            "Diskarte = street-smart resourcefulness, a real compliment.",
          ),
          s("ikaw na!", "you're the best!", "Ikaw na! means 'you win': half praise, half teasing."),
        ],
      ),
      r(
        "The conductor even hands Migs free snacks because he was so charming. You get nothing.",
        "Your snacks were free too? Lucky you! Next time you're in charge of everything, just kidding.",
        "Tease him about his luck, put him in charge of the next trip, then say you're kidding.",
        [
          s("Libre pa 'yung snacks mo?", "your snacks were free too?", "Libre = free of charge."),
          s(
            "Sana all talaga!",
            "lucky you, I wish that were all of us!",
            "Sana all = 'I wish everyone got that': playful envy that has stuck around for years.",
          ),
          s(
            "Next time, ikaw na ang bahala sa lahat,",
            "next time, you're in charge of everything",
            "Ikaw na ang bahala = 'it's all up to you': bahala again, now meaning 'in charge'.",
          ),
          s("charot.", "just kidding", "Charot (or char) tacks 'kidding!' onto a teasing line."),
        ],
      ),
    ],
  },
  {
    order: 5,
    ...soundLikeALocal,
    title: "Lola's adobo, step by step",
    scenario: "Learn the family adobo recipe from Lola in her own kitchen.",
    difficulty: 3.25,
    goalTags: ["family", "culture"],
    rounds: [
      r(
        "It's Sunday at your grandmother's house. Lola is tying on her apron in the kitchen.",
        "Lola, please teach me your adobo, the one the whole family loves.",
        "Sweetly ask your grandmother to teach you her famous adobo.",
        [
          s(
            "Lola, turuan n'yo naman po ako",
            "Lola, please teach me",
            "Naman po turns a request into a sweet plea; n'yo is short for ninyo.",
          ),
          s("ng adobo ninyo,", "your adobo"),
          s("'yung sikat sa buong pamilya.", "the one famous in the whole family"),
        ],
      ),
      r(
        "Lola puts the chicken in a bowl and starts adding things. Check the first step with her.",
        "First, you marinate the chicken in soy sauce, vinegar and garlic for about an hour, right?",
        "Repeat the marinade step back to her and check you've got it right.",
        [
          s(
            "Una po, ibababad muna ang manok",
            "first, the chicken gets marinated",
            "Ibababad = will be soaked (future, object focus).",
          ),
          s("sa toyo, suka at bawang", "in soy sauce, vinegar and garlic"),
          s("nang mga isang oras,", "for about an hour", "Mga before a number means 'about'."),
          s("tama po ba?", "is that right?"),
        ],
      ),
      r(
        "Lola slaps your hand away from the spoon. The vinegar has to boil before anyone stirs.",
        "Oh, so that's why you don't stir right after pouring in the vinegar, so it doesn't taste raw.",
        "Show you've understood why she won't let you stir yet.",
        [
          s("Ah, kaya pala", "oh, so that's why", "Kaya pala is the 'aha, now I get it' phrase."),
          s(
            "hindi muna hinahalo pagkabuhos ng suka,",
            "you don't stir yet once the vinegar is in",
            "Pagka- + root = 'right after ...'.",
          ),
          s(
            "para hindi lumabas na hilaw ang lasa.",
            "so the taste doesn't come out raw",
            "Kitchen lore: let the vinegar boil off before stirring.",
          ),
        ],
      ),
      r(
        "Lola winks and says there's one more thing that makes hers special. Ask about it.",
        "What's your secret, Lola? Do you add a little sugar, or just bay leaf?",
        "Ask what her secret is, guessing between sugar and bay leaf.",
        [
          s("Ano po 'yung sikreto ninyo, Lola?", "what's your secret, Lola?"),
          s(
            "Nilalagyan n'yo po ba ng konting asukal,",
            "do you put in a little sugar",
            "Nilalagyan = put something into (habitual, location focus).",
          ),
          s("o laurel lang?", "or just bay leaf?", "Laurel = bay leaf, from Spanish."),
        ],
      ),
      r(
        "The adobo is done. Lola hands you a spoonful over rice and waits for your verdict.",
        "It's delicious! No matter how many times I copy it, Lola's cooking is still something else.",
        "Praise the taste and say your version will never match hers.",
        [
          s("Ang sarap po!", "so delicious!"),
          s(
            "Kahit ilang beses ko pang gayahin,",
            "no matter how many times I copy it",
            "Kahit ilang beses = 'no matter how many times'.",
          ),
          s(
            "iba pa rin talaga ang luto ni Lola.",
            "Lola's cooking is still something else",
            "Calling her 'Lola' in the third person, to her face, is affectionate.",
          ),
        ],
      ),
    ],
  },
  {
    order: 6,
    ...soundLikeALocal,
    title: "Teleserye talk and a videoke night",
    scenario: "Gush over last night's teleserye finale, then plan a videoke night.",
    difficulty: 3.3,
    goalTags: ["culture", "lifeInThePhilippines"],
    rounds: [
      r(
        "At lunch, your officemate Tin sits down looking like she barely slept. The big drama ended last night.",
        "Did you watch the finale last night? Wow, I never imagined Lorenzo was the real father!",
        "Ask whether she saw the finale, and react to the big twist about the father.",
        [
          s(
            "Napanood mo ba 'yung finale kagabi?",
            "did you watch the finale last night?",
            "Napanood = got to watch (completed).",
          ),
          s("Grabe,", "wow, intense", "Grabe = 'that's insane': reaction word number one."),
          s(
            "hindi ko inakalang si Lorenzo pala",
            "I never thought it would turn out to be Lorenzo",
            "Pala marks a surprise discovery: 'so it turns out'.",
          ),
          s("ang tunay na ama!", "who was the real father!"),
        ],
      ),
      r(
        "Tin can't stand the scheming villain, Veronica. You agree, but you're also impressed.",
        "The villain is so annoying, but she acts so well that she'll surely win an award.",
        "Say the villain is infuriating, but praise her acting and predict an award.",
        [
          s(
            "Nakakainis 'yung kontrabida,",
            "the villain is so infuriating",
            "Kontrabida = villain; every teleserye needs one.",
          ),
          s("pero ang galing niyang umarte,", "but she's such a good actress"),
          s("kaya siguradong mananalo siya ng award.", "so she's sure to win an award"),
        ],
      ),
      r(
        "Tin admits she cried at the ending. Confess that you did too.",
        "Honestly, I cried my eyes out at the last scene, especially when she hugged her mother.",
        "Admit you sobbed at the final scene, especially the hug with her mother.",
        [
          s("Sa totoo lang,", "honestly"),
          s(
            "umiyak ako nang todo sa huling eksena,",
            "I cried hard at the final scene",
            "Nang todo = all-out (nang before a manner word).",
          ),
          s(
            "lalo na nung niyakap niya ang nanay niya.",
            "especially when she hugged her mum",
            "Nung is the spoken form of noong, 'when' in the past.",
          ),
        ],
      ),
      r(
        "You want to celebrate the finale with the whole team. Invite them over for the weekend.",
        "Let's do videoke on Saturday at my place! I'll take care of the food, you guys bring drinks.",
        "Invite everyone to a Saturday videoke at your house and split the food and drinks.",
        [
          s(
            "Videoke tayo sa Sabado sa bahay!",
            "let's do videoke on Saturday at my place!",
            "Activity + tayo = 'let's do ...'.",
          ),
          s("Ako na ang bahala sa pagkain,", "I'll take care of the food"),
          s(
            "kayo na lang sa drinks.",
            "you all just handle the drinks",
            "Kayo here is the plural 'you all', not the respectful form.",
          ),
        ],
      ),
      r(
        "Tin is already planning her song list. Call dibs on the drama's theme song.",
        "But I get to sing the theme song first, then you belt out the chorus, deal?",
        "Claim the first turn on the theme song and give her the big chorus.",
        [
          s(
            "Basta ako ang unang kakanta",
            "as long as I'm the first to sing",
            "Basta = 'as long as, just make sure'.",
          ),
          s("ng theme song,", "the theme song"),
          s(
            "tapos ikaw ang bibirit sa chorus, deal?",
            "then you belt out the chorus, deal?",
            "Bumirit = to belt out a high note, a videoke must.",
          ),
        ],
      ),
    ],
  },
  {
    order: 7,
    ...soundLikeALocal,
    title: "Run a meeting in office Taglish",
    scenario: "Lead a team meeting in office Taglish and push back on a deadline.",
    difficulty: 3.35,
    goalTags: ["work"],
    rounds: [
      r(
        "It's Monday at your Ortigas office. You're leading the weekly meeting, and everyone is settling in.",
        "Good morning, team! Let's get started so we finish on time. First on the agenda, the client launch.",
        "Open the meeting, keep it moving, and announce the first item.",
        [
          s(
            "Good morning, team!",
            "good morning, team!",
            "Manila office meetings often open fully in English.",
          ),
          s(
            "Simulan na natin",
            "let's start now",
            "Simulan na natin = 'let's begin' (natin includes everyone).",
          ),
          s("para matapos tayo on time.", "so we finish on time"),
          s("Una sa agenda, 'yung client launch.", "first on the agenda, the client launch"),
        ],
      ),
      r(
        "Jessa, your designer, has the latest mock-ups open on her laptop. Ask her for an update.",
        "Jessa, could you share the design update? Where are we on the timeline?",
        "Ask Jessa to share her update and where the project stands on the timeline.",
        [
          s(
            "Jessa, puwede mo bang i-share",
            "Jessa, could you share",
            "I- + English verb is the standard Taglish pattern: i-share, i-check, i-move.",
          ),
          s("'yung update sa design?", "the update on the design?"),
          s("Nasaan na tayo sa timeline?", "where are we on the timeline?"),
        ],
      ),
      r(
        "Your manager joins the call and says the client wants everything by Friday. Push back respectfully.",
        "Sir, with all due respect, one week is a bit short for us to test it properly.",
        "Tell your manager, respectfully, that a week isn't enough to test properly.",
        [
          s(
            "Sir, with all due respect,",
            "sir, with all due respect",
            "Bosses are Sir or Ma'am; careful pushback often starts in English.",
          ),
          s(
            "medyo kulang po ang isang linggo",
            "one week is a bit short",
            "Medyo ('somewhat') softens the bad news.",
          ),
          s(
            "para ma-test namin nang maayos.",
            "for us to test it properly",
            "Namin excludes the boss: 'we, the team'.",
          ),
        ],
      ),
      r(
        "Your manager asks what you suggest instead. Offer a realistic new date.",
        "If it's all right with you, could we move it to the end of the month?",
        "Politely propose moving the deadline to the end of the month.",
        [
          s("Kung okay lang po sa inyo,", "if it's all right with you"),
          s(
            "puwede po bang i-move natin",
            "could we move it",
            "Puwede po bang ...? is the polite request frame for a superior.",
          ),
          s("sa katapusan ng buwan?", "to the end of the month?"),
        ],
      ),
      r(
        "Your manager agrees. Wrap up the meeting by assigning who does what.",
        "Okay, so our action items are that I'll talk to the client and Jessa will update the timeline.",
        "Sum up the action items: you'll handle the client, Jessa will update the timeline.",
        [
          s("Sige, so ang action items natin,", "okay, so our action items"),
          s(
            "ako ang kakausap sa client,",
            "I'm the one who'll talk to the client",
            "Kakausap = will talk to (future); 'ako ang ...' = 'I'm the one who ...'.",
          ),
          s(
            "at si Jessa ang mag-a-update ng timeline.",
            "and Jessa will update the timeline",
            "Mag-a-update: the first sound of the English verb repeats to mark the future.",
          ),
        ],
      ),
    ],
  },
  {
    order: 8,
    ...lifesBigMoments,
    title: "Forgot the monthsary",
    scenario: "You forgot your monthsary. Apologise properly and make it up to them.",
    difficulty: 3.4,
    goalTags: ["partner"],
    rounds: [
      r(
        "Your partner has been quiet all morning. Then you check the date and realise what you forgot.",
        "Babe, I'm really sorry, I didn't mean to forget our monthsary yesterday.",
        "Apologise sincerely for forgetting your monthsary, and say it wasn't on purpose.",
        [
          s(
            "Babe, sorry talaga,",
            "babe, I'm really sorry",
            "Talaga makes the apology sincere: 'truly'.",
          ),
          s(
            "hindi ko sinasadyang makalimutan",
            "I didn't mean to forget",
            "Sinasadya = done on purpose; hindi ko sinasadya = I didn't mean it.",
          ),
          s(
            "'yung monthsary natin kahapon.",
            "our monthsary yesterday",
            "Many Filipino couples mark every month together, not just the yearly anniversary.",
          ),
        ],
      ),
      r(
        "Your partner crosses their arms and looks away. Don't make excuses; show you understand.",
        "I have no excuse; I know I hurt you, and I understand why you're upset with me.",
        "Admit you have no excuse, that you hurt them, and that their sulking makes sense.",
        [
          s(
            "Wala akong maidadahilan,",
            "I have no excuse",
            "Literally 'I have nothing I can give as an excuse'.",
          ),
          s("alam kong nasaktan kita,", "I know I hurt you", "Kita = 'I ... you' in one word."),
          s(
            "at naiintindihan ko kung bakit ka nagtatampo.",
            "and I understand why you're sulking",
            "Tampo is a hurt, quiet withdrawal that waits to be coaxed away.",
          ),
        ],
      ),
      r(
        "They glance back at you. Now offer a real plan to make up for it tonight.",
        "To make it up to you, I'll cook your favourite sinigang, and then let's catch a movie tonight.",
        "Offer to cook their favourite dish and take them to a movie tonight.",
        [
          s("Para bumawi,", "to make it up", "Bumawi = to make up for something."),
          s(
            "ipagluluto kita ng paborito mong sinigang,",
            "I'll cook you your favourite sinigang",
            "Ipagluluto = will cook for someone (future, benefactive).",
          ),
          s("tapos manood tayo ng sine mamayang gabi.", "then let's watch a movie tonight"),
        ],
      ),
      r(
        "A small smile is fighting its way onto their face. Coax them out of the sulk.",
        "Don't sulk anymore, please? Let's make up, okay? I miss you so much.",
        "Sweetly ask them to stop sulking, suggest you make up, and say you miss them.",
        [
          s(
            "Huwag ka nang magtampo, please?",
            "don't sulk anymore, please?",
            "Here nang is na + linker: 'not anymore'.",
          ),
          s(
            "Bati na tayo, ha?",
            "let's make up, okay?",
            "Bati = on good terms again; 'bati na tayo' is the classic make-up line.",
          ),
          s(
            "Miss na miss na kita.",
            "I miss you so much",
            "Repeating the word with na intensifies it.",
          ),
        ],
      ),
      r(
        "They finally laugh and hug you. Make a promise so it never happens again.",
        "I promise I'll put every one of our monthsaries in my calendar so it never happens again.",
        "Promise to put every monthsary in your calendar so you never forget again.",
        [
          s("Promise,", "I promise"),
          s(
            "ilalagay ko na sa calendar ko",
            "I'll put it in my calendar",
            "Ilalagay = will put (future, object focus).",
          ),
          s("ang bawat monthsary natin,", "every monthsary of ours"),
          s(
            "para hindi na mauulit.",
            "so it won't happen again",
            "Hindi na mauulit is the standard 'it won't happen again'.",
          ),
        ],
      ),
    ],
  },
  {
    order: 9,
    ...lifesBigMoments,
    title: "Lolo's story, in his own words",
    scenario: "Play Lolo telling how he left the Philippines to work abroad.",
    difficulty: 3.45,
    goalTags: ["family", "culture"],
    rounds: [
      r(
        "Role-play: you are Lolo. Your grandchild sits beside you on the porch and asks how you ended up abroad.",
        "My grandchild, in 1978 I left Batangas to work as a construction worker in Saudi.",
        "Speaking as Lolo, tell your grandchild the year you left your province and what work you went to do.",
        [
          s(
            "Apo, noong 1978,",
            "grandchild, back in 1978",
            "Apo = grandchild; noong marks a time in the past.",
          ),
          s("umalis ako sa Batangas", "I left Batangas"),
          s(
            "para magtrabaho bilang construction worker sa Saudi.",
            "to work as a construction worker in Saudi",
            "Saudi Arabia was the classic first destination for OFWs of that era.",
          ),
        ],
      ),
      r(
        "Still as Lolo, remember the day you said goodbye to your wife and young son at the airport.",
        "Your grandmother cried and cried at the airport, and your father was only four back then.",
        "As Lolo, describe how Lola cried at the airport and how young the grandchild's father was.",
        [
          s(
            "Iyak nang iyak ang lola mo sa airport,",
            "your grandma kept crying at the airport",
            "Verb + nang + verb = doing it over and over.",
          ),
          s("at ang tatay mo,", "and your father"),
          s(
            "apat na taon pa lang noon.",
            "was only four years old then",
            "Pa lang = 'only, just': it stresses how young he was.",
          ),
        ],
      ),
      r(
        "As Lolo, tell your grandchild what life in the desert camp was really like.",
        "Life there was hard. It was extremely hot, and only your grandma's letters kept my spirits up.",
        "Speaking as Lolo, describe the heat and the letters that kept you going.",
        [
          s("Mahirap ang buhay doon.", "life there was hard"),
          s("Sobrang init,", "it was extremely hot", "Sobra(ng) = too much, extremely."),
          s("at mga sulat lang ng lola mo", "and only your grandma's letters"),
          s(
            "ang nagpapalakas ng loob ko.",
            "were what kept my courage up",
            "Lakas ng loob = inner strength, courage.",
          ),
        ],
      ),
      r(
        "Your grandchild asks why you didn't just come home. As Lolo, explain what kept you there.",
        "I endured all of it because I wanted my children to go to school and not struggle like I did.",
        "As Lolo, explain that you endured it all so your children could study and have it easier.",
        [
          s(
            "Tiniis ko ang lahat,",
            "I endured everything",
            "Tiisin = to endure; tiniis = endured. A core word in OFW stories.",
          ),
          s(
            "kasi gusto kong makapag-aral ang mga anak ko",
            "because I wanted my children to be able to study",
          ),
          s("at hindi sila maghirap tulad ko.", "and not to struggle like me"),
        ],
      ),
      r(
        "As Lolo, end the story by squeezing your grandchild's hand and leaving them with some advice.",
        "So you, my grandchild, never forget where you came from, wherever you end up.",
        "Speaking as Lolo, urge your grandchild never to forget their roots, wherever life takes them.",
        [
          s("Kaya ikaw, apo,", "so you, my grandchild"),
          s(
            "huwag mong kalilimutan",
            "don't ever forget",
            "Kalilimutan (future form) after huwag = 'don't ever forget'.",
          ),
          s(
            "kung saan ka nanggaling,",
            "where you came from",
            "Echoes the proverb about never forgetting where you came from.",
          ),
          s("saan ka man makarating.", "wherever you may end up", "Saan ... man = 'wherever'."),
        ],
      ),
    ],
  },
  {
    order: 10,
    ...lifesBigMoments,
    title: "The best-friend toast at a Filipino wedding",
    scenario: "Give the best-friend speech at your friend's wedding reception.",
    difficulty: 3.5,
    goalTags: ["culture", "family"],
    rounds: [
      r(
        "At the reception, the host hands you the microphone. Two hundred guests, including all the titas, turn to you.",
        "Good evening, everyone! I'm Carlo's best friend, ever since high school.",
        "Greet the whole room respectfully and introduce yourself as the groom's best friend.",
        [
          s(
            "Magandang gabi po sa inyong lahat!",
            "good evening, everyone!",
            "Po to the whole room, because elders are listening.",
          ),
          s("Ako po ang best friend ni Carlo", "I'm Carlo's best friend"),
          s(
            "mula pa noong high school.",
            "ever since high school",
            "Mula pa noong = 'ever since back in'.",
          ),
        ],
      ),
      r(
        "Time for the funny story everyone expects: the groom's nerves when he first met the bride.",
        "When he first saw Anna, he couldn't sleep for three days from thinking about how to approach her.",
        "Tell the story of how sleepless he was over how to approach Anna.",
        [
          s(
            "Noong una niyang makita si Anna,",
            "when he first saw Anna",
            "Noong una + verb = 'when ... for the first time'.",
          ),
          s("tatlong araw siyang hindi makatulog", "he couldn't sleep for three days"),
          s(
            "kakaisip kung paano siya lalapit.",
            "from thinking about how to approach her",
            "Kaka- + root = 'from all that ...ing' (colloquial).",
          ),
        ],
      ),
      r(
        "The guests are laughing. Now turn to the bride and get sincere.",
        "But Anna, you're the reason my friend became a better person.",
        "Speak directly to the bride and tell her how she changed your friend.",
        [
          s("Pero Anna,", "but Anna"),
          s("ikaw ang dahilan kung bakit", "you're the reason why"),
          s(
            "naging mas mabuting tao ang kaibigan ko.",
            "my friend became a better person",
            "Naging = became.",
          ),
        ],
      ),
      r(
        "Face both newlyweds and share one piece of advice about marriage.",
        "To you both, I hope you always remember there's no perfect marriage, but there's love you choose every day.",
        "Wish the couple well with advice about choosing love every day.",
        [
          s("Sa inyong dalawa,", "to the two of you"),
          s(
            "sana lagi ninyong tandaan",
            "I hope you'll always remember",
            "Sana = 'I hope'; ninyo here is the plural 'you': both of them.",
          ),
          s(
            "na walang perpektong pagsasama,",
            "that there's no perfect marriage",
            "Pagsasama = a couple's life together.",
          ),
          s("pero may pagmamahal na pinipili araw-araw.", "but there's love you choose every day"),
        ],
      ),
      r(
        "Raise your glass and lead the whole room in the toast.",
        "So let's raise our glasses. To Carlo and Anna, long live the newlyweds!",
        "Invite everyone to raise their glasses and toast the couple.",
        [
          s("Kaya itaas na natin ang ating mga baso.", "so let's raise our glasses"),
          s(
            "Para kina Carlo at Anna,",
            "to Carlo and Anna",
            "Kina is the plural of kay, for two or more names.",
          ),
          s(
            "mabuhay ang bagong kasal!",
            "long live the newlyweds!",
            "Mabuhay! is the classic toast; the guests cheer it back.",
          ),
        ],
      ),
    ],
  },
];
