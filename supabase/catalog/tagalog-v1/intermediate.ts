import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const peopleYouLove = {
  unitOrder: 1,
  unitSlug: "people-you-love",
  unitTitle: "The people you love",
};
const plansAndPracticalities = {
  unitOrder: 2,
  unitSlug: "plans-and-practicalities",
  unitTitle: "Plans and practicalities",
};
const workCelebrationsFixes = {
  unitOrder: 3,
  unitSlug: "work-celebrations-fixes",
  unitTitle: "Work, celebrations and fixes",
};

export const intermediateLessons: LessonSpec[] = [
  {
    order: 1,
    ...peopleYouLove,
    title: "Sunday lunch at Lola's",
    scenario: "Eat, praise the cooking and turn down a third plate politely.",
    difficulty: 2.25,
    goalTags: ["family", "culture"],
    rounds: [
      r(
        "You walk into your partner's grandmother's kitchen for Sunday lunch. The whole table is covered in dishes.",
        "It smells so good, Lola! What did you cook?",
        "Compliment the smell and ask her what she cooked, respectfully.",
        [
          s(
            "Ang bango po",
            "it smells so good",
            "Ang + adjective is an exclamation: 'how fragrant!'",
          ),
          s("dito, Lola!", "in here, Grandma!"),
          s(
            "Ano pong niluto ninyo?",
            "what did you cook?",
            "Po takes the linker -ng before a verb: 'ano pong'. Ninyo is the respectful 'you'.",
          ),
        ],
      ),
      r(
        "You take the first bite of her kare-kare. Lola watches you, waiting for your verdict.",
        "Wow, your kare-kare is delicious!",
        "Tell her the dish is delicious.",
        [
          s("Grabe,", "wow,", "Grabe is an all-purpose 'wow' for anything extreme."),
          s(
            "ang sarap po",
            "it's so delicious",
            "Sarap is the go-to compliment for food. Ang makes it an exclamation.",
          ),
          s(
            "ng kare-kare ninyo!",
            "your kare-kare!",
            "Ng marks whose delicious thing it is: 'the deliciousness of your kare-kare'.",
          ),
        ],
      ),
      r(
        "Lola spoons more rice towards your plate and insists you keep eating.",
        "Okay, but just a little rice.",
        "Accept, but ask for only a small amount.",
        [
          s("Sige po,", "okay,", "Sige is 'okay, go ahead'. Add po for an elder."),
          s("pero konting kanin", "but a little rice", "Konting is konti + the linker -ng."),
          s("lang.", "only.", "Lang means 'just, only' and softens the request."),
        ],
      ),
      r(
        "She is already reaching for the serving spoon a third time.",
        "Oh no, I'm completely full, Lola.",
        "Turn down the third serving politely.",
        [
          s("Naku,", "oh no,", "Naku softens a refusal with a little drama."),
          s(
            "busog na busog",
            "completely full",
            "Repeating an adjective with na intensifies it: 'very, very full'.",
          ),
          s(
            "na po ako, Lola.",
            "I already am, Grandma.",
            "Short words go first: na, then po, then ako.",
          ),
        ],
      ),
      r(
        "Lola looks disappointed that so much food is left. Offer her a way out.",
        "Just wrap some up for me, so I have food for tomorrow.",
        "Ask her to pack some leftovers so you can eat them tomorrow.",
        [
          s(
            "Pabalot na lang po ako,",
            "just wrap some for me,",
            "Pa- turns a verb into a request: pabalot is 'have it wrapped'. Na lang means 'instead'.",
          ),
          s("para may baon ako", "so I have food to bring", "Baon is food you take with you."),
          s("bukas.", "tomorrow."),
        ],
      ),
    ],
  },
  {
    order: 2,
    ...peopleYouLove,
    title: "Sound natural with little words",
    scenario: "Catch up with an old friend using the small words locals love.",
    difficulty: 2.3,
    goalTags: ["lifeInThePhilippines", "culture"],
    rounds: [
      r(
        "You bump into your old friend Bea at a coffee shop in Makati. You only recognise her at the last second.",
        "Hey, it's you! We haven't seen each other in so long.",
        "Show your surprise at seeing her and say it's been ages.",
        [
          s("Uy,", "hey,"),
          s(
            "ikaw pala!",
            "oh, it's you!",
            "Pala marks a sudden realisation: 'so it's you!'",
          ),
          s("Ang tagal na", "it's been so long", "Ang + adjective again: 'how long it's been'."),
          s(
            "nating hindi nagkita.",
            "since we've seen each other.",
            "Natin takes -g as a linker: 'natin' becomes 'nating'.",
          ),
        ],
      ),
      r(
        "Bea asks how you've been lately.",
        "I'm okay. Just a bit busy with work.",
        "Say you're fine, only a little busy at work.",
        [
          s(
            "Okay naman ako,",
            "I'm okay,",
            "Naman softens your answer: 'I'm okay, all things considered'.",
          ),
          s("medyo busy lang", "just a bit busy", "Lang downplays it: 'only a bit'."),
          s("sa trabaho.", "at work."),
        ],
      ),
      r(
        "You arrived twenty minutes late. Explain why.",
        "I was late earlier because the traffic on EDSA was terrible.",
        "Say you were late and give the reason: the traffic.",
        [
          s(
            "Na-late ako kanina",
            "I was late earlier",
            "Na- + English verb means it happened to you.",
          ),
          s(
            "kasi grabe",
            "because it was terrible",
            "Kasi means 'because'. It's how people give reasons in conversation.",
          ),
          s("ang traffic sa EDSA.", "the traffic on EDSA."),
        ],
      ),
      r(
        "You heard some gossip about your old classmate Carlo. Pass it on.",
        "Apparently Carlo is getting married in December!",
        "Share the news you heard from someone else.",
        [
          s(
            "Ikakasal na raw",
            "is apparently getting married",
            "Raw means 'they say'. Use raw after a vowel and daw after a consonant.",
          ),
          s("si Carlo", "Carlo", "Si marks a person's name."),
          s("sa Disyembre!", "in December!"),
        ],
      ),
      r(
        "You've talked about yourself enough. Turn the question back to Bea.",
        "How about you, how's your love life?",
        "Turn the conversation to her and ask about her love life.",
        [
          s(
            "Ikaw naman,",
            "how about you,",
            "Ikaw naman means 'your turn': naman shifts the focus to the other person.",
          ),
          s("kumusta na", "how is it now"),
          s("ang love life mo?", "your love life?"),
        ],
      ),
    ],
  },
  {
    order: 3,
    ...peopleYouLove,
    title: "Weekend stories",
    scenario: "Say what you did, what you're doing and what you will do.",
    difficulty: 2.4,
    goalTags: ["family", "partner"],
    rounds: [
      r(
        "It's Saturday evening and you're on a video call with your partner Mark's sister, Joy. She asks about your day.",
        "This morning I did the laundry and cleaned the house.",
        "Tell her the chores you finished this morning.",
        [
          s("Kaninang umaga,", "this morning,", "Kanina means 'earlier today'."),
          s(
            "naglaba ako",
            "I did the laundry",
            "Completed aspect: mag- becomes nag-. Maglaba, naglaba.",
          ),
          s("at naglinis ng bahay.", "and cleaned the house.", "Same pattern: maglinis, naglinis."),
        ],
      ),
      r(
        "Joy asks what you did after that.",
        "After that, Mark and I ate out.",
        "Say you and Mark went out to eat.",
        [
          s("Pagkatapos,", "after that,"),
          s(
            "kumain kami",
            "we ate",
            "Completed aspect of -um- verbs: kain becomes kumain. Kami means 'we, not you'.",
          ),
          s("ni Mark sa labas.", "Mark and I, out.", "Kami ni Mark means 'Mark and I'."),
        ],
      ),
      r(
        "Joy hears a movie playing in the background.",
        "Right now we're watching a movie at home.",
        "Tell her what you two are doing at the moment.",
        [
          s("Ngayon,", "right now,"),
          s(
            "nanonood kami",
            "we're watching",
            "Ongoing aspect: repeat the first syllable of the root. Nood becomes nanonood.",
          ),
          s("ng pelikula sa bahay.", "a movie at home."),
        ],
      ),
      r(
        "Joy asks if you have plans for tomorrow.",
        "Tomorrow we're going to Tagaytay to eat bulalo.",
        "Tell her your plan for tomorrow and why.",
        [
          s("Bukas,", "tomorrow,"),
          s(
            "pupunta kami sa Tagaytay",
            "we'll go to Tagaytay",
            "Contemplated aspect: repeat the first syllable, no -um-. Punta becomes pupunta.",
          ),
          s("para kumain ng bulalo.", "to eat bulalo.", "After para, use the plain infinitive."),
        ],
      ),
      r(
        "There's a free seat in the car. Invite Joy along.",
        "Are you coming with us? We're leaving around seven.",
        "Invite her and say what time you're leaving.",
        [
          s(
            "Sasama ka ba",
            "will you come along",
            "Contemplated aspect of sumama: sasama. Ba turns it into a question.",
          ),
          s("sa amin?", "with us?"),
          s(
            "Aalis kami",
            "we'll leave",
            "Alis becomes aalis: a vowel root just doubles its vowel.",
          ),
          s("mga alas-siyete.", "around seven.", "Mga before a time means 'around'."),
        ],
      ),
    ],
  },
  {
    order: 4,
    ...peopleYouLove,
    title: "Ask someone out to the movies",
    scenario: "Ask for a date, set the time and place, then book the tickets.",
    difficulty: 2.45,
    goalTags: ["partner"],
    rounds: [
      r(
        "You've been chatting with Mika after your dance class for weeks. You finally work up the nerve.",
        "Are you free on Saturday night?",
        "Ask if she's free on Saturday night.",
        [
          s("Libre ka ba", "are you free", "Libre means both 'free of plans' and 'my treat'."),
          s("sa Sabado ng gabi?", "on Saturday night?"),
        ],
      ),
      r(
        "She smiles and says she is. Make your invitation.",
        "Would you like to watch a movie with me?",
        "Invite her to see a movie with you.",
        [
          s(
            "Gusto mo bang",
            "would you like",
            "Ba takes the linker -ng before the next verb: 'bang manood'.",
          ),
          s("manood ng sine", "to watch a movie", "Sine is the everyday word for the cinema."),
          s("kasama ko?", "with me?"),
        ],
      ),
      r(
        "She says yes. Suggest a place and a time to meet.",
        "Let's meet at Megamall around six, is that okay?",
        "Suggest meeting at the mall at about six and check it works for her.",
        [
          s("Kita tayo", "let's meet", "Kita tayo is the casual short form of magkita tayo."),
          s("sa Megamall", "at Megamall"),
          s("mga alas-sais,", "around six,", "Clock times use Spanish numbers: alas-sais."),
          s("okay lang ba?", "is that okay?"),
        ],
      ),
      r(
        "Saturday night at the cinema counter. The young cashier is waiting.",
        "Two tickets for the seven-thirty show, please.",
        "Ask the cashier for two tickets to the half past seven screening.",
        [
          s(
            "Dalawang ticket po",
            "two tickets, please",
            "Numbers link to the noun with -ng: dalawa becomes dalawang.",
          ),
          s("para sa alas-siyete y medya.", "for half past seven.", "Y medya means 'and a half'."),
        ],
      ),
      r(
        "The cashier turns the screen to show you the seating map.",
        "Can we sit together, somewhere in the middle?",
        "Ask for two seats next to each other near the middle.",
        [
          s("Pwede po bang", "may we", "Pwede po bang opens any polite request."),
          s(
            "magkatabi kami,",
            "sit side by side,",
            "Magka- means 'together': magkatabi is 'next to each other'.",
          ),
          s("sa bandang gitna?", "around the middle?", "Banda means 'around, near'."),
        ],
      ),
    ],
  },
  {
    order: 5,
    ...plansAndPracticalities,
    title: "Island trip to Puerto Galera",
    scenario: "Book the boat, deal with a tricycle driver and check in.",
    difficulty: 2.55,
    goalTags: ["travel"],
    rounds: [
      r(
        "You're at the ticket booth at Batangas port. The ferry office has a long queue behind you.",
        "One round trip to Puerto Galera, the ten o'clock one, please.",
        "Ask for a return ticket on the ten o'clock boat.",
        [
          s("Isang round trip po", "one round trip, please"),
          s("papuntang Puerto Galera,", "going to Puerto Galera,", "Papunta means 'heading to'."),
          s(
            "yung alas-diyes.",
            "the ten o'clock one.",
            "Yung points to a specific one: 'the one at ten'.",
          ),
        ],
      ),
      r(
        "You'll be coming back tomorrow and want to plan ahead.",
        "What time is the last trip back tomorrow?",
        "Ask the clerk when the last boat back leaves tomorrow.",
        [
          s("Anong oras po", "what time", "Anong is ano + -ng: 'what time'."),
          s("ang huling biyahe", "is the last trip", "Huli + -ng: 'huling' means 'last'."),
          s("pabalik bukas?", "back tomorrow?", "Pabalik means 'heading back'."),
        ],
      ),
      r(
        "The boat docks. Tricycle drivers crowd the pier. You wave one over.",
        "How much to White Beach, sir?",
        "Ask the driver the fare to the beach.",
        [
          s(
            "Kuya,",
            "sir,",
            "Kuya ('big brother') is how you address any man a bit older: drivers, guards, vendors.",
          ),
          s("magkano po", "how much"),
          s("hanggang White Beach?", "to White Beach?", "Hanggang means 'up to, as far as'."),
        ],
      ),
      r(
        "He quotes a price that's clearly for tourists. Haggle politely.",
        "That's too expensive. Can we make it fifty instead?",
        "Say it's too pricey and offer fifty pesos.",
        [
          s(
            "Ang mahal naman po.",
            "that's too expensive.",
            "Naman here adds a gentle complaint: 'that's a bit much'.",
          ),
          s("Pwede bang", "can it be"),
          s(
            "singkwenta na lang?",
            "just fifty instead?",
            "Prices often use Spanish numbers: singkwenta is fifty. Na lang means 'instead'.",
          ),
        ],
      ),
      r(
        "You reach the beach resort. A receptionist greets you at the front desk.",
        "Hi, I have a booking under the name Alex Smith.",
        "Greet the receptionist and give the name on your booking.",
        [
          s("Hi po,", "hi,", "Even an English 'hi' gets po for staff and strangers."),
          s("may booking po ako", "I have a booking", "May means 'there is, have'."),
          s("sa pangalang Alex Smith.", "under the name Alex Smith."),
        ],
      ),
    ],
  },
  {
    order: 6,
    ...plansAndPracticalities,
    title: "At the doctor and the pharmacy",
    scenario: "Describe your symptoms and leave with the right medicine.",
    difficulty: 2.6,
    goalTags: ["lifeInThePhilippines", "travel"],
    rounds: [
      r(
        "You're sitting across from the doctor at a clinic in Quezon City. She asks what's wrong.",
        "Doc, I've had a fever for three days.",
        "Tell the doctor how long you've had a fever.",
        [
          s("Dok,", "Doc,", "Dok is how everyone addresses a doctor."),
          s(
            "tatlong araw na",
            "three days now",
            "Na after a length of time means 'already, so far'.",
          ),
          s(
            "po akong may lagnat.",
            "I've had a fever.",
            "Ako takes the linker -ng before may: 'akong may lagnat'.",
          ),
        ],
      ),
      r(
        "The doctor asks if you have any other symptoms.",
        "My throat hurts too, and I've been coughing.",
        "Describe your sore throat and your cough.",
        [
          s(
            "Masakit din po",
            "also hurts",
            "Din follows a consonant (masakit); rin would follow a vowel.",
          ),
          s("ang lalamunan ko,", "my throat,"),
          s(
            "at inuubo ako.",
            "and I've been coughing.",
            "Inuubo is 'being hit by a cough': the illness is the doer.",
          ),
        ],
      ),
      r(
        "Before writing the prescription, she asks if you're allergic to anything.",
        "I'm not allergic to any medicine.",
        "Tell her you have no medicine allergies.",
        [
          s("Wala po akong allergy", "I don't have an allergy", "Wala + -ng means 'have no'."),
          s("sa kahit anong gamot.", "to any medicine.", "Kahit ano means 'any at all'."),
        ],
      ),
      r(
        "At the pharmacy counter, you hand the prescription to the pharmacist, a young woman.",
        "Miss, here's my prescription from the doctor.",
        "Hand over the prescription and say where it's from.",
        [
          s("Ate,", "miss,", "Ate ('big sister') is a warm way to address a woman serving you."),
          s("heto po ang reseta ko", "here's my prescription", "Heto means 'here it is'."),
          s("galing sa doktor.", "from the doctor.", "Galing sa means 'coming from'."),
        ],
      ),
      r(
        "She puts the tablets on the counter. You want to be sure how to take them.",
        "How many times a day should I take this?",
        "Ask how many times a day to take the medicine.",
        [
          s("Ilang beses", "how many times", "Ilan + -g: 'ilang beses' means 'how many times'."),
          s(
            "ko po ba ito iinumin",
            "should I take this",
            "Short words line up: ko, then po, then ba. Iinumin is the future of inumin.",
          ),
          s("sa isang araw?", "in a day?"),
        ],
      ),
    ],
  },
  {
    order: 7,
    ...plansAndPracticalities,
    title: "Renting a condo",
    scenario: "View a unit, ask the right questions and agree on the rent.",
    difficulty: 2.7,
    goalTags: ["lifeInThePhilippines"],
    rounds: [
      r(
        "The landlady, Mrs. Reyes, is showing you a one-bedroom unit in Mandaluyong. You like the view.",
        "How much is the rent per month?",
        "Ask her the monthly rent.",
        [
          s("Magkano po", "how much"),
          s("ang upa", "is the rent", "Upa is rent. Many people also just say 'rent'."),
          s("kada buwan?", "per month?", "Kada means 'every, per'."),
        ],
      ),
      r(
        "She tells you the price. Check what it covers.",
        "Are water and electricity already included in the rent?",
        "Ask whether utilities are part of the rent.",
        [
          s("Kasama na po ba", "is it already included", "Kasama means 'included, together with'."),
          s("ang tubig at kuryente", "the water and electricity"),
          s("sa upa?", "in the rent?"),
        ],
      ),
      r(
        "She mentions an upfront payment. Ask the details.",
        "How many months of advance and deposit do you need?",
        "Ask how many months you have to pay upfront.",
        [
          s("Ilang buwan po", "how many months"),
          s(
            "ang advance at deposit",
            "the advance and deposit",
            "Landlords use the English terms.",
          ),
          s(
            "na kailangan?",
            "that's needed?",
            "Na here is a linker joining the noun to its description.",
          ),
        ],
      ),
      r(
        "The rent is a bit above your budget. Try to negotiate.",
        "If I sign for a year, could you lower it a little?",
        "Offer a one-year contract in exchange for a lower rent.",
        [
          s(
            "Kung pipirma po ako",
            "if I sign",
            "Kung means 'if'. Pipirma is the future of pumirma.",
          ),
          s("ng isang taon,", "for one year,"),
          s("pwede bang bawasan", "can you lower it"),
          s(
            "nang kaunti?",
            "a little?",
            "Nang (not ng) introduces how something is done: 'by a little'.",
          ),
        ],
      ),
      r(
        "She agrees to a small discount. You're ready to decide.",
        "Okay, I'll take it. When can I move in?",
        "Accept the unit and ask when you can move in.",
        [
          s("Sige po,", "okay,"),
          s(
            "kukunin ko na.",
            "I'll take it.",
            "Kukunin is the future of kunin. Na: 'now, settled'.",
          ),
          s("Kailan po ako", "when can I"),
          s("pwedeng lumipat?", "move in?", "Pwede + -ng links to the verb: 'pwedeng lumipat'."),
        ],
      ),
    ],
  },
  {
    order: 8,
    ...workCelebrationsFixes,
    title: "Office small talk in Taglish",
    scenario: "Chat with a coworker the way Manila offices really talk.",
    difficulty: 2.75,
    goalTags: ["work"],
    rounds: [
      r(
        "Monday morning in the office pantry in BGC. Your coworker Paolo is making coffee.",
        "Hey, good morning! How was your weekend?",
        "Greet him and ask about his weekend.",
        [
          s("Uy, good morning!", "hey, good morning!", "Offices greet in English all the time."),
          s(
            "Kumusta yung weekend mo?",
            "how was your weekend?",
            "Yung is the casual form of 'iyong', pointing to 'the' weekend.",
          ),
        ],
      ),
      r(
        "He asks how your week is looking.",
        "Wow, I have so many deadlines this week.",
        "Complain about your workload this week.",
        [
          s("Grabe,", "wow,"),
          s(
            "ang dami kong deadlines",
            "I have so many deadlines",
            "Ang dami + ko + -ng: 'how many I have'. English nouns slot right in.",
          ),
          s("this week.", "this week.", "Time words often stay in English in Taglish."),
        ],
      ),
      r(
        "You both glance at the calendar on his phone.",
        "We still have a meeting at two later, right?",
        "Double-check that you both have a meeting this afternoon.",
        [
          s("May meeting pa tayo", "we still have a meeting", "Pa means 'still, yet to come'."),
          s("mamayang alas-dos,", "at two later,", "Mamaya + -ng: 'later today, at'."),
          s("di ba?", "right?", "Di ba is the tag question 'right?' or 'isn't it?'"),
        ],
      ),
      r(
        "Paolo needs a file from you before the meeting.",
        "Okay, I'll just send you the file after lunch.",
        "Promise to send him the file after lunch.",
        [
          s(
            "Sige, i-send ko",
            "okay, I'll send",
            "I- + English verb, with a hyphen, makes a Tagalog verb: i-send.",
          ),
          s("na lang sa'yo", "to you instead", "Sa'yo is the spoken short form of 'sa iyo'."),
          s("yung file after lunch.", "the file after lunch."),
        ],
      ),
      r(
        "It's almost noon. Suggest eating together.",
        "Come on, let's have lunch together later!",
        "Invite him to eat lunch with you.",
        [
          s("Tara,", "come on,", "Tara means 'let's go'."),
          s(
            "sabay na tayong",
            "let's go together",
            "Sabay means 'at the same time, together'. Tayo + -ng links to the verb.",
          ),
          s("mag-lunch mamaya!", "have lunch later!", "Mag- + English noun: 'to have lunch'."),
        ],
      ),
    ],
  },
  {
    order: 9,
    ...workCelebrationsFixes,
    title: "Christmas in the Philippines",
    scenario: "Dawn Mass, Noche Buena and greeting your godparents.",
    difficulty: 2.8,
    goalTags: ["culture", "family"],
    rounds: [
      r(
        "It's 3:30 in the morning in December. Your cousin is still half asleep on the sofa.",
        "Come on, Simbang Gabi starts at four.",
        "Hurry your cousin along to the dawn Mass.",
        [
          s("Tara na,", "come on,", "Na adds urgency: 'let's go now'."),
          s(
            "alas-kuwatro magsisimula",
            "starts at four",
            "Magsisimula is the future of magsimula.",
          ),
          s(
            "ang Simbang Gabi.",
            "Simbang Gabi.",
            "The dawn Masses held for nine days before Christmas.",
          ),
        ],
      ),
      r(
        "Mass is ending. You can already smell the food stalls outside the church.",
        "Let's buy bibingka and puto bumbong when we get out.",
        "Suggest getting the classic rice cakes after Mass.",
        [
          s("Bili tayo", "let's buy", "Bare root + tayo is a casual 'let's': bili tayo."),
          s(
            "ng bibingka at puto bumbong",
            "bibingka and puto bumbong",
            "Two Christmas rice cakes.",
          ),
          s("paglabas natin.", "when we get out.", "Pag- + verb root means 'when, upon'."),
        ],
      ),
      r(
        "Christmas Eve. The clock strikes midnight and the table is full.",
        "It's midnight! Come on, let's have Noche Buena.",
        "Announce it's midnight and call everyone to eat.",
        [
          s("Alas-dose na!", "it's twelve o'clock!"),
          s("Tara,", "come on,"),
          s(
            "mag-Noche Buena na tayo.",
            "let's have Noche Buena.",
            "Mag- turns an event into a verb: 'to do Noche Buena'.",
          ),
        ],
      ),
      r(
        "On Christmas Day your godfather arrives. You take his hand and press it to your forehead.",
        "Merry Christmas, Ninong! Your blessing, please.",
        "Greet your godfather and ask for his blessing.",
        [
          s("Maligayang Pasko po,", "Merry Christmas,"),
          s("Ninong!", "Godfather!", "Ninong and ninang are your godparents."),
          s(
            "Mano po.",
            "your blessing, please.",
            "Say it as you press an elder's hand to your forehead.",
          ),
        ],
      ),
      r(
        "Your godmother hands you an envelope with a gift inside.",
        "Oh, you didn't have to. Thank you, Ninang!",
        "Thank your godmother warmly for the gift.",
        [
          s("Naku,", "oh,"),
          s(
            "nag-abala pa po kayo.",
            "you went to the trouble.",
            "The polite way to receive a gift: 'you shouldn't have'.",
          ),
          s("Salamat po, Ninang!", "thank you, Godmother!"),
        ],
      ),
    ],
  },
  {
    order: 10,
    ...workCelebrationsFixes,
    title: "Wrong order at the restaurant",
    scenario: "Sort out a mix-up politely but firmly.",
    difficulty: 2.9,
    goalTags: ["lifeInThePhilippines", "travel"],
    rounds: [
      r(
        "The waiter puts a bowl of soup in front of you. It's not what you asked for.",
        "Excuse me, this isn't what I ordered.",
        "Get the waiter's attention and say it's the wrong dish.",
        [
          s("Excuse me po,", "excuse me,", "English 'excuse me' plus po is standard with staff."),
          s("hindi po ito", "this isn't"),
          s(
            "yung in-order ko.",
            "what I ordered.",
            "In- + English verb with a hyphen: 'in-order' means 'ordered'.",
          ),
        ],
      ),
      r(
        "The waiter looks confused and checks his notepad.",
        "I ordered pork sinigang, not shrimp sinigang.",
        "Explain which dish you ordered and which one you got.",
        [
          s("Sinigang na baboy po", "pork sinigang", "Na links the dish to its main ingredient."),
          s("ang in-order ko,", "is what I ordered,"),
          s("hindi sinigang na hipon.", "not shrimp sinigang."),
        ],
      ),
      r(
        "Your friends have already finished eating. Make it clear this has taken too long.",
        "We've already been waiting for half an hour.",
        "Say firmly how long you've been waiting.",
        [
          s("Kalahating oras na po", "half an hour already", "Kalahati + -ng: 'half an hour'."),
          s(
            "kaming naghihintay.",
            "we've been waiting.",
            "Naghihintay is the ongoing form: the wait is still going on.",
          ),
        ],
      ),
      r(
        "The waiter offers to fix it. Shrimp is a real problem for you.",
        "Can you replace it right away? I'm allergic to shrimp.",
        "Ask for a quick replacement and explain your allergy.",
        [
          s("Pwede po bang", "could you"),
          s("palitan ninyo agad?", "replace it right away?", "Agad means 'immediately'."),
          s("May allergy po ako", "I have an allergy"),
          s("sa hipon.", "to shrimp."),
        ],
      ),
      r(
        "The right dish finally arrives. When the bill comes, the shrimp soup is still on it.",
        "Please just remove the shrimp from the bill. Thank you.",
        "Ask firmly but politely for the wrong dish to be taken off the bill.",
        [
          s(
            "Pakitanggal na lang po",
            "please just remove",
            "Paki- + verb is a polite 'please': pakitanggal.",
          ),
          s("yung hipon sa bill.", "the shrimp from the bill."),
          s("Salamat po.", "thank you."),
        ],
      ),
    ],
  },
];
