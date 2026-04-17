"""Tarot card data and drawing logic."""

import random

TAROT_CARDS = [
    {"name": "The Fool", "number": "0", "meaning": "New beginnings, innocence, spontaneity",
     "upright": "A leap of faith is calling you. Trust in the journey ahead, even if the destination is unclear. This is a time for new adventures and fresh starts. Embrace the unknown with childlike wonder.",
     "reversed": "Recklessness and poor judgement cloud your path. You may be taking unnecessary risks or refusing to see obvious warnings. Pause and reconsider before making any major decisions."},
    {"name": "The Magician", "number": "I", "meaning": "Manifestation, power, resourcefulness",
     "upright": "You have all the tools you need to manifest your desires. Channel your willpower and focus your intentions. The universe supports your creative vision right now. Act with confidence and purpose.",
     "reversed": "Manipulation or trickery may be at play. You might be misusing your talents or feeling disconnected from your power. Realign with your authentic self and honest intentions."},
    {"name": "The High Priestess", "number": "II", "meaning": "Intuition, mystery, inner knowledge",
     "upright": "Your intuition speaks loudly today — listen carefully. Hidden knowledge reveals itself to those who are patient. Trust your inner wisdom over external advice. Secrets may come to light.",
     "reversed": "You are ignoring your intuition or suppressing inner knowledge. Information is being withheld. Reconnect with your subconscious mind through meditation or journaling."},
    {"name": "The Empress", "number": "III", "meaning": "Abundance, nurturing, fertility",
     "upright": "Abundance flows to you naturally. This is a time of growth, creativity, and nurturing connections. Embrace the beauty around you and share your gifts generously. New life emerges in many forms.",
     "reversed": "Creative blocks or neglecting self-care may be draining you. You might be smothering others or yourself. Find balance between giving and receiving nurturing energy."},
    {"name": "The Emperor", "number": "IV", "meaning": "Authority, structure, leadership",
     "upright": "Take charge of your situation with authority and wisdom. Structure and discipline lead to success now. Your leadership is needed and respected. Build solid foundations for the future.",
     "reversed": "Rigidity or excessive control is limiting your growth. Authority may be misused. Consider whether you are being too domineering or, conversely, giving away your power."},
    {"name": "The Hierophant", "number": "V", "meaning": "Tradition, wisdom, spiritual guidance",
     "upright": "Seek guidance from established traditions or a wise mentor. Spiritual growth comes through formal learning or community. Honor the wisdom of those who came before you.",
     "reversed": "Questioning established norms and traditions. You may feel restricted by conventional expectations. Trust your own spiritual path, even if it diverges from the mainstream."},
    {"name": "The Lovers", "number": "VI", "meaning": "Love, harmony, partnership",
     "upright": "A significant choice in love or values presents itself. Harmony and deep connection are possible now. Align your actions with your heart's true desires. Partnerships flourish under this energy.",
     "reversed": "Disharmony in relationships or inner conflict about values. You may be avoiding a difficult choice. Misalignment between head and heart causes tension. Seek honest communication."},
    {"name": "The Chariot", "number": "VII", "meaning": "Determination, willpower, victory",
     "upright": "Victory through determination and willpower. You are in control and moving forward with purpose. Obstacles fall away before your focused energy. Stay the course — triumph is near.",
     "reversed": "Loss of direction or control. Opposing forces pull you in different directions. Aggression without purpose wastes energy. Regain your focus before charging ahead."},
    {"name": "Strength", "number": "VIII", "meaning": "Courage, inner strength, compassion",
     "upright": "True strength comes from within — patience and compassion are your greatest powers now. Tame your inner fears with gentle courage. You have more resilience than you realize.",
     "reversed": "Self-doubt or inner weakness undermines your confidence. You may be using force instead of grace. Reconnect with your inner courage through self-compassion and patience."},
    {"name": "The Hermit", "number": "IX", "meaning": "Solitude, reflection, inner guidance",
     "upright": "Withdraw from the noise and seek answers within. Solitude brings clarity and deep understanding. Your inner light guides you through darkness. Wisdom comes through quiet reflection.",
     "reversed": "Isolation has become loneliness rather than contemplation. You may be withdrawing too much or refusing needed guidance. Balance solitude with meaningful connection."},
    {"name": "Wheel of Fortune", "number": "X", "meaning": "Destiny, turning point, cycles",
     "upright": "The wheel turns in your favor. A destined change is coming — embrace it. Luck and opportunity arrive unexpectedly. Trust that the universe has a plan, even if you can't see it yet.",
     "reversed": "Resistance to change or feeling stuck in a cycle. Bad luck may seem to persist. Remember that the wheel always turns — this too shall pass. Find what you can control within the chaos."},
    {"name": "Justice", "number": "XI", "meaning": "Fairness, truth, accountability",
     "upright": "Truth and fairness prevail. Legal matters or decisions resolve in a balanced way. Take responsibility for your actions and expect others to do the same. Karma is at work.",
     "reversed": "Injustice or dishonesty disrupts your peace. You may be avoiding accountability or experiencing unfair treatment. Seek truth even when it's uncomfortable."},
    {"name": "The Hanged Man", "number": "XII", "meaning": "Surrender, new perspective, letting go",
     "upright": "Surrender to gain a new perspective. What seems like a pause is actually profound transformation. Let go of old patterns and see the world from a different angle. Patience reveals hidden wisdom.",
     "reversed": "Stubbornly clinging to old ways or resisting necessary sacrifice. Stalling and indecision keep you stuck. Sometimes you must let go to move forward."},
    {"name": "Death", "number": "XIII", "meaning": "Transformation, endings, new beginnings",
     "upright": "A powerful transformation is underway. Something must end for something new to begin. Release what no longer serves you. This is not an ending but a profound rebirth.",
     "reversed": "Resisting inevitable change or clinging to the past. Fear of transformation keeps you stuck. Accept that some things must end. The new beginning you seek is on the other side of letting go."},
    {"name": "Temperance", "number": "XIV", "meaning": "Balance, patience, moderation",
     "upright": "Balance and moderation bring peace. Blend opposing forces in your life with patience and grace. Healing comes through gentle, steady progress. A middle path serves you best now.",
     "reversed": "Imbalance and excess disrupt your harmony. You may be going to extremes or lacking patience. Restore equilibrium through mindful choices and self-discipline."},
    {"name": "The Devil", "number": "XV", "meaning": "Shadow self, attachment, illusion",
     "upright": "Examine what binds you — addictions, toxic patterns, or limiting beliefs. The chains you see are of your own making. Awareness is the first step to liberation. Face your shadow with honesty.",
     "reversed": "Breaking free from bondage and unhealthy attachments. You are reclaiming your power from toxic influences. Liberation comes through honest self-examination."},
    {"name": "The Tower", "number": "XVI", "meaning": "Upheaval, revelation, sudden change",
     "upright": "Sudden upheaval destroys false structures. Though shocking, this destruction clears the way for truth. What is built on lies cannot stand. From the rubble, build something real and lasting.",
     "reversed": "Resisting necessary upheaval or narrowly avoiding disaster. You may be prolonging an unsustainable situation. Sometimes controlled demolition is better than waiting for the collapse."},
    {"name": "The Star", "number": "XVII", "meaning": "Hope, inspiration, renewal",
     "upright": "Hope shines brightly in your sky. After difficulty, healing and renewal arrive. Trust that the universe guides you toward your highest good. Inspiration flows freely — follow it.",
     "reversed": "Loss of hope or faith. You may feel disconnected from your purpose or uninspired. The star still shines — you just need to look up. Reconnect with what inspires you."},
    {"name": "The Moon", "number": "XVIII", "meaning": "Illusion, intuition, the subconscious",
     "upright": "Not everything is as it seems. Trust your intuition to navigate through illusion and uncertainty. Dreams carry important messages. Your subconscious reveals truths your waking mind resists.",
     "reversed": "Confusion lifts as truth emerges. Fears and anxieties that haunted you begin to fade. Clarity returns after a period of uncertainty. Trust the process of illumination."},
    {"name": "The Sun", "number": "XIX", "meaning": "Joy, success, vitality",
     "upright": "Pure joy and success illuminate your path. Vitality and optimism surge through you. Everything you touch seems to turn to gold. Share your warmth and light with others.",
     "reversed": "Temporary sadness or dimmed enthusiasm. The sun is still there behind the clouds. Don't let setbacks steal your joy. Reconnect with your inner child and what brings you genuine happiness."},
    {"name": "Judgement", "number": "XX", "meaning": "Reflection, reckoning, inner calling",
     "upright": "A moment of reckoning and rebirth. Reflect on your journey and answer your inner calling. Past actions meet their consequences — good or bad. Rise to your higher purpose with clarity.",
     "reversed": "Self-doubt blocks your calling. You may be too harsh in self-judgement or avoiding accountability. Forgive yourself and others to move forward. Your higher self awaits."},
    {"name": "The World", "number": "XXI", "meaning": "Completion, achievement, wholeness",
     "upright": "A cycle reaches its beautiful completion. You have achieved wholeness and integration. Celebrate your journey and accomplishments. The world opens up with infinite new possibilities.",
     "reversed": "Feeling incomplete despite achievements. A cycle struggles to close — loose ends need tying. You may be seeking external validation instead of inner fulfillment. Completion comes from within."},

    # === MINOR ARCANA — WANDS (Fire) ===
    {"name": "Ace of Wands", "number": "Wands I", "meaning": "Inspiration, new opportunities, growth",
     "upright": "A spark of inspiration ignites within you. New creative opportunities emerge, and the universe invites you to take bold action. This is the seed of a passionate new venture — plant it with confidence.",
     "reversed": "Creative blocks or false starts frustrate your ambitions. The spark fizzles before catching fire. Reassess your approach and wait for clearer inspiration before committing."},
    {"name": "Two of Wands", "number": "Wands II", "meaning": "Planning, decisions, discovery",
     "upright": "You stand at a crossroads with the world at your feet. Future planning and big decisions are favored now. Explore your options with courage — the horizon holds endless possibility.",
     "reversed": "Fear of the unknown holds you back from taking the next step. Poor planning or lack of vision stalls progress. Broaden your perspective before deciding."},
    {"name": "Three of Wands", "number": "Wands III", "meaning": "Expansion, foresight, overseas opportunities",
     "upright": "Your plans are taking shape and expansion is underway. Look beyond your immediate surroundings for opportunities. Ships are coming in — your patience and foresight are being rewarded.",
     "reversed": "Delays and obstacles frustrate your plans for growth. Overreaching ambitions need grounding. Rethink your strategy and focus on sustainable progress."},
    {"name": "Four of Wands", "number": "Wands IV", "meaning": "Celebration, harmony, homecoming",
     "upright": "A time of celebration and joyful milestones. Harmony reigns in your home and relationships. Gather with loved ones and honor how far you have come. Stability brings contentment.",
     "reversed": "Domestic unrest or cancelled celebrations create disappointment. Foundations feel unstable. Address underlying tensions to restore harmony in your personal life."},
    {"name": "Five of Wands", "number": "Wands V", "meaning": "Competition, conflict, tension",
     "upright": "Healthy competition or minor conflicts arise. Multiple perspectives clash, but this tension can fuel growth. Stand your ground with grace and use disagreement as a catalyst for innovation.",
     "reversed": "Avoiding conflict at all costs or engaging in petty battles. Find constructive ways to channel competitive energy. Seek compromise over dominance."},
    {"name": "Six of Wands", "number": "Wands VI", "meaning": "Victory, recognition, triumph",
     "upright": "Public recognition and victory are yours. Your efforts are applauded, and you ride high on success. Accept praise with humility and let this triumph fuel your next chapter.",
     "reversed": "Lack of recognition or a fall from grace. Ego may be inflated or deflated. Seek validation from within rather than external applause."},
    {"name": "Seven of Wands", "number": "Wands VII", "meaning": "Perseverance, defense, standing your ground",
     "upright": "Challenges test your resolve, but you have the high ground. Defend your position with courage and conviction. Perseverance is your greatest weapon — do not yield to pressure.",
     "reversed": "Feeling overwhelmed by opposition. The fight drains you and you question whether it's worth it. Choose your battles wisely and consider strategic retreat."},
    {"name": "Eight of Wands", "number": "Wands VIII", "meaning": "Speed, action, swift change",
     "upright": "Events accelerate rapidly. Messages, travel, and swift developments bring exciting momentum. Ride the wave of change and act decisively — delays are over and progress is unstoppable.",
     "reversed": "Delays, frustration, and stalled momentum. Plans hit unexpected resistance. Patience is forced upon you — use this slowdown to prepare for when things accelerate again."},
    {"name": "Nine of Wands", "number": "Wands IX", "meaning": "Resilience, courage, persistence",
     "upright": "You have been through the fire and still stand tall. Though weary, your resilience is remarkable. One last push is needed before breakthrough. Gather your remaining strength — victory is near.",
     "reversed": "Exhaustion and paranoia drain your defenses. You may be fighting battles that no longer matter. Know when perseverance becomes stubbornness and rest when needed."},
    {"name": "Ten of Wands", "number": "Wands X", "meaning": "Burden, responsibility, hard work",
     "upright": "You carry a heavy load of responsibilities. While your dedication is admirable, consider what you can delegate or release. Lightening your burden creates space for joy and renewal.",
     "reversed": "Burnout from taking on too much. You collapse under the weight of obligations. Delegate, simplify, and learn to say no before responsibility crushes your spirit."},
    {"name": "Page of Wands", "number": "Wands Page", "meaning": "Enthusiasm, exploration, free spirit",
     "upright": "A youthful energy of exploration and discovery fills your spirit. Embrace new ideas with enthusiasm and curiosity. An exciting message or opportunity related to your passion may arrive soon.",
     "reversed": "Scattered energy and lack of direction. Enthusiasm without follow-through wastes potential. Focus your restless energy on one pursuit before moving to the next."},
    {"name": "Knight of Wands", "number": "Wands Knight", "meaning": "Energy, passion, adventure",
     "upright": "Fiery energy propels you forward with passion and daring. An adventurous spirit takes hold — pursue your desires with bold confidence. Action and impulsiveness blend; channel this energy wisely.",
     "reversed": "Reckless haste or frustrating delays dampen your fiery spirit. Impulsive decisions backfire. Slow down and think before charging ahead blindly."},
    {"name": "Queen of Wands", "number": "Wands Queen", "meaning": "Courage, confidence, independence",
     "upright": "Radiant confidence and warmth define your energy now. Lead with courage and inspire others through your vibrant example. Your independence and determination attract success and admiration.",
     "reversed": "Insecurity hides behind a brave face. Jealousy or self-doubt undermine your confidence. Reconnect with your inner fire and authentic self-worth."},
    {"name": "King of Wands", "number": "Wands King", "meaning": "Leadership, vision, entrepreneurship",
     "upright": "A natural leader emerges. Your bold vision and charismatic presence command respect. Take charge of ambitious ventures with honor and integrity. Your fire inspires those around you.",
     "reversed": "Tyrannical leadership or unrealistic expectations alienate others. Your vision may lack practical grounding. Lead with empathy, not ego."},

    # === MINOR ARCANA — CUPS (Water) ===
    {"name": "Ace of Cups", "number": "Cups I", "meaning": "New feelings, emotional awakening, love",
     "upright": "An overflow of emotional energy pours into your life. New love, deep compassion, or spiritual awakening stirs within. Open your heart to receive the blessings the universe offers.",
     "reversed": "Blocked emotions or repressed feelings stifle your growth. A love opportunity is missed or rejected. Open the floodgates gently and let yourself feel."},
    {"name": "Two of Cups", "number": "Cups II", "meaning": "Partnership, mutual attraction, unity",
     "upright": "A beautiful partnership forms through mutual respect and attraction. Whether romantic or platonic, this bond is built on equality and shared feelings. Two souls meet in harmony.",
     "reversed": "Imbalance in a relationship or a breakup looms. One-sided feelings or mismatched expectations create tension. Honest communication is needed to restore equilibrium."},
    {"name": "Three of Cups", "number": "Cups III", "meaning": "Friendship, celebration, community",
     "upright": "Joyful gatherings and the warmth of friendship surround you. Celebrate your connections with loved ones. Community support lifts you higher than you could rise alone.",
     "reversed": "Social isolation or overindulgence in escapism. Gossip or betrayal within your circle. Reevaluate which friendships truly nourish your spirit."},
    {"name": "Four of Cups", "number": "Cups IV", "meaning": "Contemplation, apathy, reevaluation",
     "upright": "A period of introspection and emotional reassessment. You may feel disconnected or uninspired by current offerings. Look beyond your immediate discontent — a new opportunity awaits if you open your eyes.",
     "reversed": "Breaking free from emotional stagnation. You finally see the opportunity you've been ignoring. Motivation returns as you reengage with life's offerings."},
    {"name": "Five of Cups", "number": "Cups V", "meaning": "Loss, grief, regret",
     "upright": "Emotional loss weighs heavily, but not all is lost. While grief is natural, three cups still stand behind you. Shift your gaze from what has spilled to what remains.",
     "reversed": "Healing begins as you accept the past and move forward. Forgiveness — of yourself and others — frees you from grief's grip. Hope returns gradually."},
    {"name": "Six of Cups", "number": "Cups VI", "meaning": "Nostalgia, childhood, innocence",
     "upright": "Sweet memories and nostalgic feelings surface. Reconnect with your inner child and the simple joys of the past. An old friend or familiar comfort returns to brighten your present.",
     "reversed": "Clinging to the past prevents growth. Idealized memories distort your perception of reality. Honor your history but live fully in the present."},
    {"name": "Seven of Cups", "number": "Cups VII", "meaning": "Fantasy, choices, illusion",
     "upright": "Many tantalizing options appear before you, but not all are what they seem. Distinguish fantasy from reality before committing. Ground your dreams in practical action.",
     "reversed": "Clarity emerges from confusion. You see through illusions and make grounded choices. Narrowing your focus brings real progress after a period of fantasy."},
    {"name": "Eight of Cups", "number": "Cups VIII", "meaning": "Walking away, seeking truth, courage to leave",
     "upright": "The courage to walk away from what no longer fulfills you emerges. Though it hurts to leave the familiar, your soul craves deeper meaning. Trust that something more aligned awaits.",
     "reversed": "Fear of change keeps you in an unfulfilling situation. You know you should leave but cannot find the courage. The comfort of the familiar becomes your prison."},
    {"name": "Nine of Cups", "number": "Cups IX", "meaning": "Wishes fulfilled, contentment, satisfaction",
     "upright": "Your wishes come true and deep satisfaction fills your heart. This is the card of emotional fulfillment — enjoy the abundance you have cultivated. Gratitude amplifies your blessings.",
     "reversed": "Dissatisfaction despite having what you wanted. Material wishes fulfilled but emotional emptiness remains. Redefine what true happiness means to you."},
    {"name": "Ten of Cups", "number": "Cups X", "meaning": "Harmony, family, emotional fulfillment",
     "upright": "Complete emotional fulfillment and family harmony bless your life. The rainbow appears after the storm — lasting happiness is yours. Cherish these bonds and the peace they bring.",
     "reversed": "Family discord or shattered ideals of domestic bliss. The perfect picture has cracks. Address conflicts with compassion to repair what matters most."},
    {"name": "Page of Cups", "number": "Cups Page", "meaning": "Creative opportunity, curiosity, imagination",
     "upright": "A message of emotional or creative significance arrives. Approach life with wonder and imaginative openness. A gentle, intuitive energy encourages you to explore your artistic and emotional depths.",
     "reversed": "Creative blocks or emotional immaturity hinder expression. Daydreaming replaces action. Channel your imagination into tangible creative output."},
    {"name": "Knight of Cups", "number": "Cups Knight", "meaning": "Romance, charm, following the heart",
     "upright": "A romantic, idealistic energy sweeps through your life. Follow your heart with grace and charm. An invitation or proposal — romantic or creative — may arrive.",
     "reversed": "Moodiness or unrealistic romantic expectations. Charm used for manipulation rather than genuine connection. Ground your idealism in reality."},
    {"name": "Queen of Cups", "number": "Cups Queen", "meaning": "Compassion, emotional security, intuition",
     "upright": "Deep compassion and emotional wisdom guide your path. Trust your intuition — it is remarkably accurate now. Nurture others from a place of inner security and calm.",
     "reversed": "Emotional overwhelm or codependency. You absorb others' feelings at the expense of your own well-being. Establish healthy boundaries to protect your sensitive nature."},
    {"name": "King of Cups", "number": "Cups King", "meaning": "Emotional balance, diplomacy, wisdom",
     "upright": "Emotional mastery and diplomatic wisdom define your influence. Lead with your heart while maintaining composure. Your ability to balance feeling with reason earns deep respect.",
     "reversed": "Emotional manipulation or suppressed feelings create inner turmoil. The mask of calm hides a storm within. Address your own emotional needs before guiding others."},

    # === MINOR ARCANA — SWORDS (Air) ===
    {"name": "Ace of Swords", "number": "Swords I", "meaning": "Clarity, breakthrough, new ideas",
     "upright": "A powerful breakthrough in understanding cuts through confusion. Mental clarity and truth emerge with sharp precision. Use this intellectual power to champion justice and communicate boldly.",
     "reversed": "Confusion and misinformation cloud your judgement. A breakthrough is blocked by muddled thinking. Seek clarity before acting on incomplete information."},
    {"name": "Two of Swords", "number": "Swords II", "meaning": "Indecision, stalemate, difficult choices",
     "upright": "You stand blindfolded at a crossroads, torn between two paths. Avoidance will not resolve this impasse. Remove the blindfold — face the truth and make the difficult choice.",
     "reversed": "Information overload or forced decisions under pressure. The blindfold comes off but the truth is overwhelming. Take one step at a time through the confusion."},
    {"name": "Three of Swords", "number": "Swords III", "meaning": "Heartbreak, sorrow, grief",
     "upright": "Pain pierces the heart through betrayal, loss, or sorrow. Allow yourself to grieve fully — suppressing pain only delays healing. The storm will pass, and your heart will mend stronger.",
     "reversed": "Recovery from heartbreak begins. The worst of the pain has passed. Forgiveness and release open the door to emotional renewal."},
    {"name": "Four of Swords", "number": "Swords IV", "meaning": "Rest, recovery, contemplation",
     "upright": "Your mind and body cry out for rest. Retreat from battle and allow yourself to recuperate. This is not defeat but strategic recovery. Clarity returns after proper rest.",
     "reversed": "Restlessness and inability to switch off. You push through exhaustion against your body's wisdom. Burnout looms if you don't prioritize recovery."},
    {"name": "Five of Swords", "number": "Swords V", "meaning": "Conflict, defeat, hollow victory",
     "upright": "A conflict ends, but the victory feels hollow. Consider whether winning at all costs is worth the price. Sometimes the wisest choice is to walk away with your integrity intact.",
     "reversed": "Reconciliation after conflict. Old grudges are released and bridges are rebuilt. Learning from past battles brings wisdom and prevents future strife."},
    {"name": "Six of Swords", "number": "Swords VI", "meaning": "Transition, moving on, healing",
     "upright": "You are crossing to calmer waters, leaving turbulence behind. Though the journey is bittersweet, a more peaceful chapter awaits. Trust that moving forward is the right choice.",
     "reversed": "Resistance to necessary change. You try to return to troubled waters rather than completing the crossing. Let go of what's behind you and face forward."},
    {"name": "Seven of Swords", "number": "Swords VII", "meaning": "Strategy, deception, cunning",
     "upright": "A situation calls for strategy and careful thinking. Not everything around you is transparent — guard your plans wisely. Use your intellect to navigate tricky waters ethically.",
     "reversed": "Deception is exposed or a guilty conscience surfaces. Coming clean brings relief even if consequences follow. Honesty heals what cunning cannot."},
    {"name": "Eight of Swords", "number": "Swords VIII", "meaning": "Restriction, imprisonment, self-limiting beliefs",
     "upright": "You feel trapped, but the bindings are largely of your own making. Limiting beliefs and fear keep you imprisoned. The moment you choose to see differently, freedom reveals itself.",
     "reversed": "Breaking free from mental imprisonment. Self-awareness dissolves limiting beliefs. You reclaim your power and see clearly for the first time in a while."},
    {"name": "Nine of Swords", "number": "Swords IX", "meaning": "Anxiety, worry, nightmares",
     "upright": "Worry and anxiety haunt your nights. Your fears feel overwhelming, but they are magnified by darkness. When dawn breaks, perspective returns. Reach out for support.",
     "reversed": "The worst of the anxiety passes. You learn to manage worry and find healthy coping strategies. Professional support or a trusted confidant brings relief."},
    {"name": "Ten of Swords", "number": "Swords X", "meaning": "Ending, painful conclusion, rock bottom",
     "upright": "A painful chapter reaches its absolute end. You have hit bottom, but there is nowhere to go but up. The darkest hour is just before dawn. Release, accept, and prepare for renewal.",
     "reversed": "Recovery begins after hitting bottom. The worst is behind you. Rising from the ashes, you carry hard-won wisdom that prevents repeating past mistakes."},
    {"name": "Page of Swords", "number": "Swords Page", "meaning": "Curiosity, restlessness, mental energy",
     "upright": "A sharp, curious mind seeks new information and ideas. Your mental energy is high — channel it into learning and communication. An important message may arrive soon.",
     "reversed": "Gossip, hasty words, or information used carelessly. Think before you speak and verify before you share. Mental restlessness needs constructive outlets."},
    {"name": "Knight of Swords", "number": "Swords Knight", "meaning": "Ambition, action, speed",
     "upright": "Swift, decisive action cuts through delays and hesitation. Your ambition and mental agility drive you forward at full speed. Charge ahead with determination, but mind the consequences of haste.",
     "reversed": "Reckless haste leads to mistakes. Charging forward without thinking causes collateral damage. Slow down, strategize, then act with precision."},
    {"name": "Queen of Swords", "number": "Swords Queen", "meaning": "Perception, clear thinking, independence",
     "upright": "Sharp perception and unbiased judgement are your strengths now. See through deception with clear, independent thinking. Communicate truth with authority and grace.",
     "reversed": "Cold detachment or cruel honesty without compassion. Your sharp tongue wounds rather than clarifies. Balance truth-telling with empathy and kindness."},
    {"name": "King of Swords", "number": "Swords King", "meaning": "Intellectual power, authority, truth",
     "upright": "Command your realm with intellectual authority and fair judgement. Truth is your sword and clarity your shield. Make decisions from logic and ethical principle.",
     "reversed": "Abuse of intellectual power or tyrannical judgement. Using logic to manipulate rather than illuminate. Wisdom requires humility alongside intelligence."},

    # === MINOR ARCANA — PENTACLES (Earth) ===
    {"name": "Ace of Pentacles", "number": "Pentacles I", "meaning": "New financial opportunity, prosperity, abundance",
     "upright": "A golden opportunity for material prosperity appears. A new job, investment, or financial venture shows great promise. Plant this seed with care and diligence — it has tremendous growth potential.",
     "reversed": "A missed financial opportunity or poor investment. Material plans fall through or lack solid foundation. Reassess your approach to money and resources."},
    {"name": "Two of Pentacles", "number": "Pentacles II", "meaning": "Balance, adaptability, juggling priorities",
     "upright": "Life demands you juggle multiple responsibilities with grace. Adaptability and flexibility keep you afloat. Find your rhythm amidst the chaos — balance is an art, not a destination.",
     "reversed": "Overwhelm from too many commitments. Dropping balls and losing balance. Simplify your obligations and focus on what truly matters."},
    {"name": "Three of Pentacles", "number": "Pentacles III", "meaning": "Teamwork, collaboration, skilled work",
     "upright": "Collaboration and skilled craftsmanship lead to excellence. Your expertise is valued within a team. Together, you build something of lasting quality.",
     "reversed": "Poor teamwork or lack of recognition for your contributions. Miscommunication with collaborators. Clarify roles and expectations to restore productive harmony."},
    {"name": "Four of Pentacles", "number": "Pentacles IV", "meaning": "Security, conservation, control",
     "upright": "A need for financial security drives you to hold tight. While stability is wise, beware of hoarding or excessive control. True abundance comes from knowing when to save and when to share.",
     "reversed": "Letting go of material attachment or reckless spending. Either extreme — hoarding or squandering — disrupts your balance. Find the middle ground with money."},
    {"name": "Five of Pentacles", "number": "Pentacles V", "meaning": "Hardship, insecurity, worry",
     "upright": "Financial hardship or feelings of being left out in the cold weigh on you. Help is closer than you think — look up and seek the warmth that awaits. Hard times are temporary.",
     "reversed": "Recovery from financial difficulty. A helping hand appears or inner resources are discovered. The worst of the hardship passes and stability slowly returns."},
    {"name": "Six of Pentacles", "number": "Pentacles VI", "meaning": "Generosity, charity, sharing wealth",
     "upright": "The flow of giving and receiving is highlighted. Share your resources generously, or accept help with grace. Balance in material exchanges brings karmic rewards.",
     "reversed": "Strings attached to generosity or unfair distribution of resources. Debt or obligation taints giving. Ensure your generosity — given or received — comes without hidden conditions."},
    {"name": "Seven of Pentacles", "number": "Pentacles VII", "meaning": "Patience, investment, long-term view",
     "upright": "Your investments of time and effort are growing, though slowly. Patience is required — the harvest is not yet ready. Evaluate your progress and trust that steady nurturing yields the richest rewards.",
     "reversed": "Impatience with slow results or wasted effort. Your investment may not yield the expected return. Reassess whether this path is worth continued effort."},
    {"name": "Eight of Pentacles", "number": "Pentacles VIII", "meaning": "Apprenticeship, skill development, diligence",
     "upright": "Dedicated practice and skill refinement define this moment. Pour yourself into mastering your craft with focus and diligence. Each careful repetition brings you closer to excellence.",
     "reversed": "Shortcuts undermine quality. Boredom with repetitive work or perfectionism that paralyzes progress. Find joy in the process, not just the product."},
    {"name": "Nine of Pentacles", "number": "Pentacles IX", "meaning": "Luxury, self-sufficiency, financial independence",
     "upright": "You have earned this moment of luxury and self-sufficiency through hard work. Enjoy the fruits of your labor with gratitude. Financial independence and personal refinement are your well-deserved rewards.",
     "reversed": "Financial setbacks threaten your independence. Over-reliance on others or living beyond your means. Recalibrate your lifestyle to match your actual resources."},
    {"name": "Ten of Pentacles", "number": "Pentacles X", "meaning": "Legacy, inheritance, long-term success",
     "upright": "Lasting wealth and family legacy are themes now. Your efforts create security not just for you but for future generations. Traditions, inheritance, and lineage wisdom bring deep fulfillment.",
     "reversed": "Family financial disputes or a legacy under threat. Inheritance conflicts or broken family traditions. Focus on what truly matters beyond material wealth."},
    {"name": "Page of Pentacles", "number": "Pentacles Page", "meaning": "Ambition, desire to learn, new venture",
     "upright": "A studious energy focuses on new goals and practical learning. A promising opportunity for growth requires dedication and a willingness to start at the beginning. Your ambition is your compass.",
     "reversed": "Lack of focus or unrealistic goals. Procrastination prevents progress on practical matters. Ground your ambitions in actionable steps and commit to the work."},
    {"name": "Knight of Pentacles", "number": "Pentacles Knight", "meaning": "Hard work, routine, responsibility",
     "upright": "Steady, methodical progress defines your path forward. Though not flashy, your reliable approach and tireless work ethic build unshakable foundations. Consistency creates greatness.",
     "reversed": "Stubbornness, boredom, or stagnation in routine. Your methodical approach becomes monotonous. Introduce small changes to reignite motivation while maintaining stability."},
    {"name": "Queen of Pentacles", "number": "Pentacles Queen", "meaning": "Nurturing, practical, providing",
     "upright": "Grounded abundance and nurturing energy flow through you. Create a secure, comfortable environment for yourself and others. Your practical wisdom and generous spirit make the world warmer.",
     "reversed": "Neglecting self-care while providing for everyone else. Work-life imbalance or financial anxiety. Nurture yourself with the same generosity you show others."},
    {"name": "King of Pentacles", "number": "Pentacles King", "meaning": "Wealth, business, leadership, security",
     "upright": "Material mastery and prosperous leadership define your influence. Your disciplined approach to wealth and business commands respect. Enjoy your success while continuing to build with integrity.",
     "reversed": "Greed, materialism, or financial mismanagement. Success at the expense of relationships or health. Rebalance your priorities — wealth without well-being is hollow."},
]


from logger import get_logger

logger = get_logger(__name__)

# In-memory name→card lookup for fast seeding checks
_CARD_BY_NAME = {c["name"]: c for c in TAROT_CARDS}


def seed_tarot_db(db) -> int:
    """
    Seed the tarot_cards DB table from the static TAROT_CARDS list if empty.
    Returns the number of rows inserted (0 if already seeded).
    """
    from db.models import TarotCard
    existing = db.query(TarotCard).count()
    if existing >= len(TAROT_CARDS):
        logger.debug("seed_tarot_db  already seeded  count=%d", existing)
        return 0

    inserted = 0
    for card in TAROT_CARDS:
        try:
            row = TarotCard(
                name=card["name"],
                number=card["number"],
                meaning=card["meaning"],
                upright_interpretation=card["upright"],
                reversed_interpretation=card["reversed"],
            )
            db.add(row)
            inserted += 1
        except Exception as exc:
            logger.warning("seed_tarot_db  skip '%s': %s", card["name"], exc)
    db.commit()
    logger.info("seed_tarot_db  seeded %d cards", inserted)
    return inserted


def draw_tarot_card(db=None) -> dict:
    """
    Draw a random tarot card.

    Resolution order:
    1. DB table (seeded with static or AI-upgraded interpretations).
    2. In-memory static list (fallback if DB unavailable).
    """
    import random as _random
    is_reversed = _random.random() < 0.3  # 30% reversed

    if db is not None:
        try:
            from db.models import TarotCard
            # Auto-seed on first use
            count = db.query(TarotCard).count()
            if count == 0:
                seed_tarot_db(db)

            total = db.query(TarotCard).count()
            if total > 0:
                offset = _random.randint(0, total - 1)
                card_row = db.query(TarotCard).offset(offset).first()
                if card_row:
                    interpretation = (
                        card_row.reversed_interpretation if is_reversed
                        else card_row.upright_interpretation
                    )
                    logger.info(
                        "draw_tarot_card  DB  card='%s'  reversed=%s",
                        card_row.name, is_reversed,
                    )
                    return {
                        "name": card_row.name,
                        "number": card_row.number,
                        "meaning": card_row.meaning,
                        "interpretation": interpretation,
                        "is_reversed": is_reversed,
                    }
        except Exception as exc:
            logger.warning("draw_tarot_card  DB error (%s) — using static", exc)

    # Static fallback
    import random as _random2
    card = _random2.choice(TAROT_CARDS)
    logger.info("draw_tarot_card  STATIC  card='%s'  reversed=%s", card["name"], is_reversed)
    return {
        "name": card["name"],
        "number": card["number"],
        "meaning": card["meaning"],
        "interpretation": card["reversed"] if is_reversed else card["upright"],
        "is_reversed": is_reversed,
    }

