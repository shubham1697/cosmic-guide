import 'package:flutter/material.dart';
import '../models/zodiac.dart';

class MockData {
  static const List<ZodiacSign> zodiacSigns = [
    ZodiacSign(
      name: 'Aries',
      symbol: '\u2648',
      element: 'Fire',
      dateRange: 'Mar 21 - Apr 19',
      rulingPlanet: 'Mars',
      icon: Icons.local_fire_department,
    ),
    ZodiacSign(
      name: 'Taurus',
      symbol: '\u2649',
      element: 'Earth',
      dateRange: 'Apr 20 - May 20',
      rulingPlanet: 'Venus',
      icon: Icons.landscape,
    ),
    ZodiacSign(
      name: 'Gemini',
      symbol: '\u264A',
      element: 'Air',
      dateRange: 'May 21 - Jun 20',
      rulingPlanet: 'Mercury',
      icon: Icons.air,
    ),
    ZodiacSign(
      name: 'Cancer',
      symbol: '\u264B',
      element: 'Water',
      dateRange: 'Jun 21 - Jul 22',
      rulingPlanet: 'Moon',
      icon: Icons.water_drop,
    ),
    ZodiacSign(
      name: 'Leo',
      symbol: '\u264C',
      element: 'Fire',
      dateRange: 'Jul 23 - Aug 22',
      rulingPlanet: 'Sun',
      icon: Icons.wb_sunny,
    ),
    ZodiacSign(
      name: 'Virgo',
      symbol: '\u264D',
      element: 'Earth',
      dateRange: 'Aug 23 - Sep 22',
      rulingPlanet: 'Mercury',
      icon: Icons.eco,
    ),
    ZodiacSign(
      name: 'Libra',
      symbol: '\u264E',
      element: 'Air',
      dateRange: 'Sep 23 - Oct 22',
      rulingPlanet: 'Venus',
      icon: Icons.balance,
    ),
    ZodiacSign(
      name: 'Scorpio',
      symbol: '\u264F',
      element: 'Water',
      dateRange: 'Oct 23 - Nov 21',
      rulingPlanet: 'Pluto',
      icon: Icons.whatshot,
    ),
    ZodiacSign(
      name: 'Sagittarius',
      symbol: '\u2650',
      element: 'Fire',
      dateRange: 'Nov 22 - Dec 21',
      rulingPlanet: 'Jupiter',
      icon: Icons.explore,
    ),
    ZodiacSign(
      name: 'Capricorn',
      symbol: '\u2651',
      element: 'Earth',
      dateRange: 'Dec 22 - Jan 19',
      rulingPlanet: 'Saturn',
      icon: Icons.terrain,
    ),
    ZodiacSign(
      name: 'Aquarius',
      symbol: '\u2652',
      element: 'Air',
      dateRange: 'Jan 20 - Feb 18',
      rulingPlanet: 'Uranus',
      icon: Icons.waves,
    ),
    ZodiacSign(
      name: 'Pisces',
      symbol: '\u2653',
      element: 'Water',
      dateRange: 'Feb 19 - Mar 20',
      rulingPlanet: 'Neptune',
      icon: Icons.pool,
    ),
  ];

  static const List<TarotCard> tarotDeck = [
    TarotCard(
      name: 'The Fool',
      number: '0',
      meaning: 'New beginnings, innocence, spontaneity',
      interpretation:
          'A journey awaits you. Embrace the unknown with an open heart. The universe is guiding you toward fresh opportunities. Trust in the path ahead, even if you cannot see where it leads.',
      reversedInterpretation:
          'Recklessness and poor judgement cloud your path. You may be taking unnecessary risks or refusing to see obvious warnings. Pause and reconsider before making any major decisions.',
    ),
    TarotCard(
      name: 'The Magician',
      number: 'I',
      meaning: 'Manifestation, resourcefulness, power',
      interpretation:
          'You possess all the tools you need to succeed. Channel your willpower and focus your intent. The stars align to amplify your abilities — now is the time to create the reality you desire.',
      reversedInterpretation:
          'Manipulation or trickery may be at play. You might be misusing your talents or feeling disconnected from your power. Realign with your authentic self and honest intentions.',
    ),
    TarotCard(
      name: 'The High Priestess',
      number: 'II',
      meaning: 'Intuition, sacred knowledge, mystery',
      interpretation:
          'Listen to your inner voice. Hidden truths are revealing themselves. Your subconscious holds the answers you seek. Be still, meditate, and trust the wisdom that rises from within.',
      reversedInterpretation:
          'You are ignoring your intuition or suppressing inner knowledge. Information is being withheld. Reconnect with your subconscious mind through meditation or journaling.',
    ),
    TarotCard(
      name: 'The Empress',
      number: 'III',
      meaning: 'Abundance, nurturing, fertility',
      interpretation:
          'Nature and creativity surround you with abundance. A period of growth and nurturing energy is upon you. Allow beauty and love to flow into your life freely.',
      reversedInterpretation:
          'Creative blocks or neglecting self-care may be draining you. You might be smothering others or yourself. Find balance between giving and receiving nurturing energy.',
    ),
    TarotCard(
      name: 'The Emperor',
      number: 'IV',
      meaning: 'Authority, structure, control',
      interpretation:
          'Now is the time to take charge and establish order. Your leadership qualities are needed. Build strong foundations and exercise your authority with wisdom and fairness.',
      reversedInterpretation:
          'Rigidity or excessive control is limiting your growth. Authority may be misused. Consider whether you are being too domineering or, conversely, giving away your power.',
    ),
    TarotCard(
      name: 'The Hierophant',
      number: 'V',
      meaning: 'Tradition, conformity, spiritual wisdom',
      interpretation:
          'Seek guidance from tradition and established wisdom. A teacher or mentor may appear. Spiritual learning and conventional paths hold the answers you need at this time.',
      reversedInterpretation:
          'Questioning established norms and traditions. You may feel restricted by conventional expectations. Trust your own spiritual path, even if it diverges from the mainstream.',
    ),
    TarotCard(
      name: 'The Lovers',
      number: 'VI',
      meaning: 'Love, harmony, relationships',
      interpretation:
          'A significant choice in love or values lies before you. Follow your heart while staying true to your beliefs. Deep connections and meaningful relationships are highlighted now.',
      reversedInterpretation:
          'Disharmony in relationships or inner conflict about values. You may be avoiding a difficult choice. Misalignment between head and heart causes tension. Seek honest communication.',
    ),
    TarotCard(
      name: 'The Chariot',
      number: 'VII',
      meaning: 'Determination, willpower, triumph',
      interpretation:
          'Victory through determination is within reach. Harness your inner drive and stay focused on your goals. Overcome obstacles through sheer willpower and confidence.',
      reversedInterpretation:
          'Loss of direction or control. Opposing forces pull you in different directions. Aggression without purpose wastes energy. Regain your focus before charging ahead.',
    ),
    TarotCard(
      name: 'Strength',
      number: 'VIII',
      meaning: 'Courage, patience, inner strength',
      interpretation:
          'True strength comes from within. Face challenges with patience and compassion rather than force. Your gentle courage will tame even the fiercest obstacles.',
      reversedInterpretation:
          'Self-doubt or inner weakness undermines your confidence. You may be using force instead of grace. Reconnect with your inner courage through self-compassion and patience.',
    ),
    TarotCard(
      name: 'The Hermit',
      number: 'IX',
      meaning: 'Soul-searching, introspection, solitude',
      interpretation:
          'Withdraw from the noise and look within. Solitude and contemplation will reveal profound insights. Your inner light is your guide through this period of reflection.',
      reversedInterpretation:
          'Isolation has become loneliness rather than contemplation. You may be withdrawing too much or refusing needed guidance. Balance solitude with meaningful connection.',
    ),
    TarotCard(
      name: 'Wheel of Fortune',
      number: 'X',
      meaning: 'Change, cycles, destiny',
      interpretation:
          'The wheel turns and fate shifts in your favor. Embrace the cycles of change — what goes down must come up. Destiny has a plan for you, and cosmic forces are at work.',
      reversedInterpretation:
          'Resistance to change or feeling stuck in a cycle. Bad luck may seem to persist. Remember that the wheel always turns — this too shall pass. Find what you can control.',
    ),
    TarotCard(
      name: 'Justice',
      number: 'XI',
      meaning: 'Fairness, truth, cause and effect',
      interpretation:
          'Truth and fairness prevail. The consequences of past actions come to fruition. Stay honest and balanced, for the universe rewards integrity and righteous action.',
      reversedInterpretation:
          'Injustice or dishonesty disrupts your peace. You may be avoiding accountability or experiencing unfair treatment. Seek truth even when it is uncomfortable.',
    ),
    TarotCard(
      name: 'The Hanged Man',
      number: 'XII',
      meaning: 'Surrender, new perspective, letting go',
      interpretation:
          'Surrender to gain a new perspective. What seems like a pause is actually profound transformation. Let go of old patterns and see the world from a different angle. Patience reveals hidden wisdom.',
      reversedInterpretation:
          'Stubbornly clinging to old ways or resisting necessary sacrifice. Stalling and indecision keep you stuck. Sometimes you must let go to move forward.',
    ),
    TarotCard(
      name: 'Death',
      number: 'XIII',
      meaning: 'Transformation, endings, new beginnings',
      interpretation:
          'A powerful transformation is underway. Something must end for something new to begin. Release what no longer serves you. This is not an ending but a profound rebirth.',
      reversedInterpretation:
          'Resisting inevitable change or clinging to the past. Fear of transformation keeps you stuck. Accept that some things must end. The new beginning you seek is on the other side of letting go.',
    ),
    TarotCard(
      name: 'Temperance',
      number: 'XIV',
      meaning: 'Balance, patience, moderation',
      interpretation:
          'Balance and moderation bring peace. Blend opposing forces in your life with patience and grace. Healing comes through gentle, steady progress. A middle path serves you best now.',
      reversedInterpretation:
          'Imbalance and excess disrupt your harmony. You may be going to extremes or lacking patience. Restore equilibrium through mindful choices and self-discipline.',
    ),
    TarotCard(
      name: 'The Devil',
      number: 'XV',
      meaning: 'Shadow self, attachment, illusion',
      interpretation:
          'Examine what binds you — addictions, toxic patterns, or limiting beliefs. The chains you see are of your own making. Awareness is the first step to liberation. Face your shadow with honesty.',
      reversedInterpretation:
          'Breaking free from bondage and unhealthy attachments. You are reclaiming your power from toxic influences. Liberation comes through honest self-examination.',
    ),
    TarotCard(
      name: 'The Tower',
      number: 'XVI',
      meaning: 'Upheaval, revelation, sudden change',
      interpretation:
          'Sudden upheaval destroys false structures. Though shocking, this destruction clears the way for truth. What is built on lies cannot stand. From the rubble, build something real and lasting.',
      reversedInterpretation:
          'Resisting necessary upheaval or narrowly avoiding disaster. You may be prolonging an unsustainable situation. Sometimes controlled demolition is better than waiting for the collapse.',
    ),
    TarotCard(
      name: 'The Star',
      number: 'XVII',
      meaning: 'Hope, faith, renewal',
      interpretation:
          'Hope shines brightly in your sky. After hardship, a period of healing and inspiration arrives. Have faith in the universe and in your own divine purpose. Renewal is here.',
      reversedInterpretation:
          'Loss of hope or faith. You may feel disconnected from your purpose or uninspired. The star still shines — you just need to look up. Reconnect with what inspires you.',
    ),
    TarotCard(
      name: 'The Moon',
      number: 'XVIII',
      meaning: 'Illusion, fear, subconscious',
      interpretation:
          'Not everything is as it appears. Navigate through uncertainty with intuition rather than logic. Hidden emotions and subconscious patterns are surfacing for healing.',
      reversedInterpretation:
          'Confusion lifts as truth emerges. Fears and anxieties that haunted you begin to fade. Clarity returns after a period of uncertainty. Trust the process of illumination.',
    ),
    TarotCard(
      name: 'The Sun',
      number: 'XIX',
      meaning: 'Joy, success, vitality',
      interpretation:
          'Radiant energy surrounds you. Success, joy, and celebration are yours. Bask in the warmth of positivity and share your light with those around you. Life is beautiful.',
      reversedInterpretation:
          'Temporary sadness or dimmed enthusiasm. The sun is still there behind the clouds. Do not let setbacks steal your joy. Reconnect with your inner child and what brings genuine happiness.',
    ),
    TarotCard(
      name: 'Judgement',
      number: 'XX',
      meaning: 'Reflection, reckoning, inner calling',
      interpretation:
          'A moment of reckoning and rebirth. Reflect on your journey and answer your inner calling. Past actions meet their consequences — good or bad. Rise to your higher purpose with clarity.',
      reversedInterpretation:
          'Self-doubt blocks your calling. You may be too harsh in self-judgement or avoiding accountability. Forgive yourself and others to move forward. Your higher self awaits.',
    ),
    TarotCard(
      name: 'The World',
      number: 'XXI',
      meaning: 'Completion, accomplishment, travel',
      interpretation:
          'A cycle reaches its glorious completion. You have achieved wholeness and integration. Celebrate your accomplishments and prepare for a new, even grander chapter.',
      reversedInterpretation:
          'Feeling incomplete despite achievements. A cycle struggles to close — loose ends need tying. You may be seeking external validation instead of inner fulfillment. Completion comes from within.',
    ),

    // === MINOR ARCANA — WANDS (Fire) ===
    TarotCard(
      name: 'Ace of Wands',
      number: 'Wands I',
      meaning: 'Inspiration, new opportunities, growth',
      interpretation:
          'A spark of inspiration ignites within you. New creative opportunities emerge, and the universe invites you to take bold action. This is the seed of a passionate new venture — plant it with confidence.',
      reversedInterpretation:
          'Creative blocks or false starts frustrate your ambitions. The spark fizzles before catching fire. Reassess your approach and wait for clearer inspiration before committing.',
    ),
    TarotCard(
      name: 'Two of Wands',
      number: 'Wands II',
      meaning: 'Planning, decisions, discovery',
      interpretation:
          'You stand at a crossroads with the world at your feet. Future planning and big decisions are favored now. Explore your options with courage — the horizon holds endless possibility.',
      reversedInterpretation:
          'Fear of the unknown holds you back from taking the next step. Poor planning or lack of vision stalls progress. Broaden your perspective before deciding.',
    ),
    TarotCard(
      name: 'Three of Wands',
      number: 'Wands III',
      meaning: 'Expansion, foresight, overseas opportunities',
      interpretation:
          'Your plans are taking shape and expansion is underway. Look beyond your immediate surroundings for opportunities. Ships are coming in — your patience and foresight are being rewarded.',
      reversedInterpretation:
          'Delays and obstacles frustrate your plans for growth. Overreaching ambitions need grounding. Rethink your strategy and focus on sustainable progress.',
    ),
    TarotCard(
      name: 'Four of Wands',
      number: 'Wands IV',
      meaning: 'Celebration, harmony, homecoming',
      interpretation:
          'A time of celebration and joyful milestones. Harmony reigns in your home and relationships. Gather with loved ones and honor how far you have come. Stability brings contentment.',
      reversedInterpretation:
          'Domestic unrest or cancelled celebrations create disappointment. Foundations feel unstable. Address underlying tensions to restore harmony in your personal life.',
    ),
    TarotCard(
      name: 'Five of Wands',
      number: 'Wands V',
      meaning: 'Competition, conflict, tension',
      interpretation:
          'Healthy competition or minor conflicts arise. Multiple perspectives clash, but this tension can fuel growth. Stand your ground with grace and use disagreement as a catalyst for innovation.',
      reversedInterpretation:
          'Avoiding conflict at all costs or engaging in petty battles. Find constructive ways to channel competitive energy. Seek compromise over dominance.',
    ),
    TarotCard(
      name: 'Six of Wands',
      number: 'Wands VI',
      meaning: 'Victory, recognition, triumph',
      interpretation:
          'Public recognition and victory are yours. Your efforts are applauded, and you ride high on success. Accept praise with humility and let this triumph fuel your next chapter.',
      reversedInterpretation:
          'Lack of recognition or a fall from grace. Ego may be inflated or deflated. Seek validation from within rather than external applause.',
    ),
    TarotCard(
      name: 'Seven of Wands',
      number: 'Wands VII',
      meaning: 'Perseverance, defense, standing your ground',
      interpretation:
          'Challenges test your resolve, but you have the high ground. Defend your position with courage and conviction. Perseverance is your greatest weapon — do not yield to pressure.',
      reversedInterpretation:
          'Feeling overwhelmed by opposition. The fight drains you and you question whether it is worth it. Choose your battles wisely and consider strategic retreat.',
    ),
    TarotCard(
      name: 'Eight of Wands',
      number: 'Wands VIII',
      meaning: 'Speed, action, swift change',
      interpretation:
          'Events accelerate rapidly. Messages, travel, and swift developments bring exciting momentum. Ride the wave of change and act decisively — delays are over and progress is unstoppable.',
      reversedInterpretation:
          'Delays, frustration, and stalled momentum. Plans hit unexpected resistance. Patience is forced upon you — use this slowdown to prepare for when things accelerate again.',
    ),
    TarotCard(
      name: 'Nine of Wands',
      number: 'Wands IX',
      meaning: 'Resilience, courage, persistence',
      interpretation:
          'You have been through the fire and still stand tall. Though weary, your resilience is remarkable. One last push is needed before breakthrough. Gather your remaining strength — victory is near.',
      reversedInterpretation:
          'Exhaustion and paranoia drain your defenses. You may be fighting battles that no longer matter. Know when perseverance becomes stubbornness and rest when needed.',
    ),
    TarotCard(
      name: 'Ten of Wands',
      number: 'Wands X',
      meaning: 'Burden, responsibility, hard work',
      interpretation:
          'You carry a heavy load of responsibilities. While your dedication is admirable, consider what you can delegate or release. Lightening your burden creates space for joy and renewal.',
      reversedInterpretation:
          'Burnout from taking on too much. You collapse under the weight of obligations. Delegate, simplify, and learn to say no before responsibility crushes your spirit.',
    ),
    TarotCard(
      name: 'Page of Wands',
      number: 'Wands Page',
      meaning: 'Enthusiasm, exploration, free spirit',
      interpretation:
          'A youthful energy of exploration and discovery fills your spirit. Embrace new ideas with enthusiasm and curiosity. An exciting message or opportunity related to your passion may arrive soon.',
      reversedInterpretation:
          'Scattered energy and lack of direction. Enthusiasm without follow-through wastes potential. Focus your restless energy on one pursuit before moving to the next.',
    ),
    TarotCard(
      name: 'Knight of Wands',
      number: 'Wands Knight',
      meaning: 'Energy, passion, adventure',
      interpretation:
          'Fiery energy propels you forward with passion and daring. An adventurous spirit takes hold — pursue your desires with bold confidence. Action and impulsiveness blend; channel this energy wisely.',
      reversedInterpretation:
          'Reckless haste or frustrating delays dampen your fiery spirit. Impulsive decisions backfire. Slow down and think before charging ahead blindly.',
    ),
    TarotCard(
      name: 'Queen of Wands',
      number: 'Wands Queen',
      meaning: 'Courage, confidence, independence',
      interpretation:
          'Radiant confidence and warmth define your energy now. Lead with courage and inspire others through your vibrant example. Your independence and determination attract success and admiration.',
      reversedInterpretation:
          'Insecurity hides behind a brave face. Jealousy or self-doubt undermine your confidence. Reconnect with your inner fire and authentic self-worth.',
    ),
    TarotCard(
      name: 'King of Wands',
      number: 'Wands King',
      meaning: 'Leadership, vision, entrepreneurship',
      interpretation:
          'A natural leader emerges. Your bold vision and charismatic presence command respect. Take charge of ambitious ventures with honor and integrity. Your fire inspires those around you.',
      reversedInterpretation:
          'Tyrannical leadership or unrealistic expectations alienate others. Your vision may lack practical grounding. Lead with empathy, not ego.',
    ),

    // === MINOR ARCANA — CUPS (Water) ===
    TarotCard(
      name: 'Ace of Cups',
      number: 'Cups I',
      meaning: 'New feelings, emotional awakening, love',
      interpretation:
          'An overflow of emotional energy pours into your life. New love, deep compassion, or spiritual awakening stirs within. Open your heart to receive the blessings the universe offers.',
      reversedInterpretation:
          'Blocked emotions or repressed feelings stifle your growth. A love opportunity is missed or rejected. Open the floodgates gently and let yourself feel.',
    ),
    TarotCard(
      name: 'Two of Cups',
      number: 'Cups II',
      meaning: 'Partnership, mutual attraction, unity',
      interpretation:
          'A beautiful partnership forms through mutual respect and attraction. Whether romantic or platonic, this bond is built on equality and shared feelings. Two souls meet in harmony.',
      reversedInterpretation:
          'Imbalance in a relationship or a breakup looms. One-sided feelings or mismatched expectations create tension. Honest communication is needed to restore equilibrium.',
    ),
    TarotCard(
      name: 'Three of Cups',
      number: 'Cups III',
      meaning: 'Friendship, celebration, community',
      interpretation:
          'Joyful gatherings and the warmth of friendship surround you. Celebrate your connections with loved ones. Community support lifts you higher than you could rise alone. Share your happiness generously.',
      reversedInterpretation:
          'Social isolation or overindulgence in escapism. Gossip or betrayal within your circle. Reevaluate which friendships truly nourish your spirit.',
    ),
    TarotCard(
      name: 'Four of Cups',
      number: 'Cups IV',
      meaning: 'Contemplation, apathy, reevaluation',
      interpretation:
          'A period of introspection and emotional reassessment. You may feel disconnected or uninspired by current offerings. Look beyond your immediate discontent — a new opportunity awaits if you open your eyes.',
      reversedInterpretation:
          'Breaking free from emotional stagnation. You finally see the opportunity you have been ignoring. Motivation returns as you reengage with life.',
    ),
    TarotCard(
      name: 'Five of Cups',
      number: 'Cups V',
      meaning: 'Loss, grief, regret',
      interpretation:
          'Emotional loss weighs heavily, but not all is lost. While grief is natural, three cups still stand behind you. Shift your gaze from what has spilled to what remains. Healing begins with acceptance.',
      reversedInterpretation:
          'Healing begins as you accept the past and move forward. Forgiveness — of yourself and others — frees you from grief. Hope returns gradually.',
    ),
    TarotCard(
      name: 'Six of Cups',
      number: 'Cups VI',
      meaning: 'Nostalgia, childhood, innocence',
      interpretation:
          'Sweet memories and nostalgic feelings surface. Reconnect with your inner child and the simple joys of the past. An old friend or familiar comfort returns to brighten your present.',
      reversedInterpretation:
          'Clinging to the past prevents growth. Idealized memories distort your perception of reality. Honor your history but live fully in the present.',
    ),
    TarotCard(
      name: 'Seven of Cups',
      number: 'Cups VII',
      meaning: 'Fantasy, choices, illusion',
      interpretation:
          'Many tantalizing options appear before you, but not all are what they seem. Distinguish fantasy from reality before committing. Ground your dreams in practical action to manifest real results.',
      reversedInterpretation:
          'Clarity emerges from confusion. You see through illusions and make grounded choices. Narrowing your focus brings real progress after a period of fantasy.',
    ),
    TarotCard(
      name: 'Eight of Cups',
      number: 'Cups VIII',
      meaning: 'Walking away, seeking truth, courage to leave',
      interpretation:
          'The courage to walk away from what no longer fulfills you emerges. Though it hurts to leave the familiar, your soul craves deeper meaning. Trust that something more aligned awaits ahead.',
      reversedInterpretation:
          'Fear of change keeps you in an unfulfilling situation. You know you should leave but cannot find the courage. The comfort of the familiar becomes your prison.',
    ),
    TarotCard(
      name: 'Nine of Cups',
      number: 'Cups IX',
      meaning: 'Wishes fulfilled, contentment, satisfaction',
      interpretation:
          'Your wishes come true and deep satisfaction fills your heart. This is the card of emotional fulfillment — enjoy the abundance you have cultivated. Gratitude amplifies your blessings.',
      reversedInterpretation:
          'Dissatisfaction despite having what you wanted. Material wishes fulfilled but emotional emptiness remains. Redefine what true happiness means to you.',
    ),
    TarotCard(
      name: 'Ten of Cups',
      number: 'Cups X',
      meaning: 'Harmony, family, emotional fulfillment',
      interpretation:
          'Complete emotional fulfillment and family harmony bless your life. The rainbow appears after the storm — lasting happiness is yours. Cherish these bonds and the peace they bring.',
      reversedInterpretation:
          'Family discord or shattered ideals of domestic bliss. The perfect picture has cracks. Address conflicts with compassion to repair what matters most.',
    ),
    TarotCard(
      name: 'Page of Cups',
      number: 'Cups Page',
      meaning: 'Creative opportunity, curiosity, imagination',
      interpretation:
          'A message of emotional or creative significance arrives. Approach life with wonder and imaginative openness. A gentle, intuitive energy encourages you to explore your artistic and emotional depths.',
      reversedInterpretation:
          'Creative blocks or emotional immaturity hinder expression. Daydreaming replaces action. Channel your imagination into tangible creative output.',
    ),
    TarotCard(
      name: 'Knight of Cups',
      number: 'Cups Knight',
      meaning: 'Romance, charm, following the heart',
      interpretation:
          'A romantic, idealistic energy sweeps through your life. Follow your heart with grace and charm. An invitation or proposal — romantic or creative — may arrive. Let beauty guide your actions.',
      reversedInterpretation:
          'Moodiness or unrealistic romantic expectations. Charm used for manipulation rather than genuine connection. Ground your idealism in reality.',
    ),
    TarotCard(
      name: 'Queen of Cups',
      number: 'Cups Queen',
      meaning: 'Compassion, emotional security, intuition',
      interpretation:
          'Deep compassion and emotional wisdom guide your path. Trust your intuition — it is remarkably accurate now. Nurture others from a place of inner security and calm.',
      reversedInterpretation:
          'Emotional overwhelm or codependency. You absorb others’ feelings at the expense of your own well-being. Establish healthy boundaries to protect your sensitive nature.',
    ),
    TarotCard(
      name: 'King of Cups',
      number: 'Cups King',
      meaning: 'Emotional balance, diplomacy, wisdom',
      interpretation:
          'Emotional mastery and diplomatic wisdom define your influence. Lead with your heart while maintaining composure. Your ability to balance feeling with reason earns deep respect from others.',
      reversedInterpretation:
          'Emotional manipulation or suppressed feelings create inner turmoil. The mask of calm hides a storm within. Address your own emotional needs before guiding others.',
    ),

    // === MINOR ARCANA — SWORDS (Air) ===
    TarotCard(
      name: 'Ace of Swords',
      number: 'Swords I',
      meaning: 'Clarity, breakthrough, new ideas',
      interpretation:
          'A powerful breakthrough in understanding cuts through confusion. Mental clarity and truth emerge with sharp precision. Use this intellectual power to champion justice and communicate your ideas boldly.',
      reversedInterpretation:
          'Confusion and misinformation cloud your judgement. A breakthrough is blocked by muddled thinking. Seek clarity before acting on incomplete information.',
    ),
    TarotCard(
      name: 'Two of Swords',
      number: 'Swords II',
      meaning: 'Indecision, stalemate, difficult choices',
      interpretation:
          'You stand blindfolded at a crossroads, torn between two paths. Avoidance will not resolve this impasse. Remove the blindfold — face the truth and make the difficult choice that awaits.',
      reversedInterpretation:
          'Information overload or forced decisions under pressure. The blindfold comes off but the truth is overwhelming. Take one step at a time through the confusion.',
    ),
    TarotCard(
      name: 'Three of Swords',
      number: 'Swords III',
      meaning: 'Heartbreak, sorrow, grief',
      interpretation:
          'Pain pierces the heart through betrayal, loss, or sorrow. Allow yourself to grieve fully — suppressing pain only delays healing. The storm will pass, and your heart will mend stronger than before.',
      reversedInterpretation:
          'Recovery from heartbreak begins. The worst of the pain has passed. Forgiveness and release open the door to emotional renewal.',
    ),
    TarotCard(
      name: 'Four of Swords',
      number: 'Swords IV',
      meaning: 'Rest, recovery, contemplation',
      interpretation:
          'Your mind and body cry out for rest. Retreat from battle and allow yourself to recuperate. This is not defeat but strategic recovery. Clarity returns after proper rest and quiet reflection.',
      reversedInterpretation:
          'Restlessness and inability to switch off. You push through exhaustion against your body’s wisdom. Burnout looms if you do not prioritize recovery.',
    ),
    TarotCard(
      name: 'Five of Swords',
      number: 'Swords V',
      meaning: 'Conflict, defeat, hollow victory',
      interpretation:
          'A conflict ends, but the victory feels hollow. Consider whether winning at all costs is worth the price. Sometimes the wisest choice is to walk away with your integrity intact.',
      reversedInterpretation:
          'Reconciliation after conflict. Old grudges are released and bridges are rebuilt. Learning from past battles brings wisdom and prevents future strife.',
    ),
    TarotCard(
      name: 'Six of Swords',
      number: 'Swords VI',
      meaning: 'Transition, moving on, healing',
      interpretation:
          'You are crossing to calmer waters, leaving turbulence behind. Though the journey is bittersweet, a more peaceful chapter awaits. Trust that moving forward is the right choice, even when it is hard.',
      reversedInterpretation:
          'Resistance to necessary change. You try to return to troubled waters rather than completing the crossing. Let go of what is behind you and face forward.',
    ),
    TarotCard(
      name: 'Seven of Swords',
      number: 'Swords VII',
      meaning: 'Strategy, deception, cunning',
      interpretation:
          'A situation calls for strategy and careful thinking. Not everything around you is transparent — guard your plans wisely. Use your intellect to navigate tricky waters, but stay true to your ethics.',
      reversedInterpretation:
          'Deception is exposed or a guilty conscience surfaces. Coming clean brings relief even if consequences follow. Honesty heals what cunning cannot.',
    ),
    TarotCard(
      name: 'Eight of Swords',
      number: 'Swords VIII',
      meaning: 'Restriction, imprisonment, self-limiting beliefs',
      interpretation:
          'You feel trapped, but the bindings are largely of your own making. Limiting beliefs and fear keep you imprisoned. The moment you choose to see differently, the path to freedom reveals itself.',
      reversedInterpretation:
          'Breaking free from mental imprisonment. Self-awareness dissolves limiting beliefs. You reclaim your power and see clearly for the first time in a while.',
    ),
    TarotCard(
      name: 'Nine of Swords',
      number: 'Swords IX',
      meaning: 'Anxiety, worry, nightmares',
      interpretation:
          'Worry and anxiety haunt your nights. Your fears feel overwhelming, but they are magnified by darkness. When dawn breaks, perspective returns. Reach out for support — you need not carry this burden alone.',
      reversedInterpretation:
          'The worst of the anxiety passes. You learn to manage worry and find healthy coping strategies. A trusted confidant or professional support brings relief.',
    ),
    TarotCard(
      name: 'Ten of Swords',
      number: 'Swords X',
      meaning: 'Ending, painful conclusion, rock bottom',
      interpretation:
          'A painful chapter reaches its absolute end. You have hit bottom, but there is nowhere to go but up. The darkest hour is just before dawn. Release, accept, and prepare for renewal.',
      reversedInterpretation:
          'Recovery begins after hitting bottom. The worst is behind you. Rising from the ashes, you carry hard-won wisdom that prevents repeating past mistakes.',
    ),
    TarotCard(
      name: 'Page of Swords',
      number: 'Swords Page',
      meaning: 'Curiosity, restlessness, mental energy',
      interpretation:
          'A sharp, curious mind seeks new information and ideas. Your mental energy is high — channel it into learning and communication. A message carrying important information may arrive soon.',
      reversedInterpretation:
          'Gossip, hasty words, or information used carelessly. Think before you speak and verify before you share. Mental restlessness needs constructive outlets.',
    ),
    TarotCard(
      name: 'Knight of Swords',
      number: 'Swords Knight',
      meaning: 'Ambition, action, speed',
      interpretation:
          'Swift, decisive action cuts through delays and hesitation. Your ambition and mental agility drive you forward at full speed. Charge ahead with determination, but mind the consequences of haste.',
      reversedInterpretation:
          'Reckless haste leads to mistakes. Charging forward without thinking causes collateral damage. Slow down, strategize, then act with precision.',
    ),
    TarotCard(
      name: 'Queen of Swords',
      number: 'Swords Queen',
      meaning: 'Perception, clear thinking, independence',
      interpretation:
          'Sharp perception and unbiased judgement are your strengths now. See through deception with clear, independent thinking. Communicate truth with authority and grace, even when it is uncomfortable.',
      reversedInterpretation:
          'Cold detachment or cruel honesty without compassion. Your sharp tongue wounds rather than clarifies. Balance truth-telling with empathy and kindness.',
    ),
    TarotCard(
      name: 'King of Swords',
      number: 'Swords King',
      meaning: 'Intellectual power, authority, truth',
      interpretation:
          'Command your realm with intellectual authority and fair judgement. Truth is your sword and clarity your shield. Make decisions from logic and ethical principle. Your wisdom guides others.',
      reversedInterpretation:
          'Abuse of intellectual power or tyrannical judgement. Using logic to manipulate rather than illuminate. Wisdom requires humility alongside intelligence.',
    ),

    // === MINOR ARCANA — PENTACLES (Earth) ===
    TarotCard(
      name: 'Ace of Pentacles',
      number: 'Pentacles I',
      meaning: 'New financial opportunity, prosperity, abundance',
      interpretation:
          'A golden opportunity for material prosperity appears. A new job, investment, or financial venture shows great promise. Plant this seed with care and diligence — it has the potential for tremendous growth.',
      reversedInterpretation:
          'A missed financial opportunity or poor investment. Material plans fall through or lack solid foundation. Reassess your approach to money and resources.',
    ),
    TarotCard(
      name: 'Two of Pentacles',
      number: 'Pentacles II',
      meaning: 'Balance, adaptability, juggling priorities',
      interpretation:
          'Life demands you juggle multiple responsibilities with grace. Adaptability and flexibility keep you afloat. Find your rhythm amidst the chaos — balance is an art, not a destination.',
      reversedInterpretation:
          'Overwhelm from too many commitments. Dropping balls and losing balance. Simplify your obligations and focus on what truly matters.',
    ),
    TarotCard(
      name: 'Three of Pentacles',
      number: 'Pentacles III',
      meaning: 'Teamwork, collaboration, skilled work',
      interpretation:
          'Collaboration and skilled craftsmanship lead to excellence. Your expertise is valued within a team. Together, you build something of lasting quality. Recognition for your mastery follows dedication.',
      reversedInterpretation:
          'Poor teamwork or lack of recognition for your contributions. Miscommunication with collaborators. Clarify roles and expectations to restore productive harmony.',
    ),
    TarotCard(
      name: 'Four of Pentacles',
      number: 'Pentacles IV',
      meaning: 'Security, conservation, control',
      interpretation:
          'A need for financial security drives you to hold tight. While stability is wise, beware of hoarding or excessive control. True abundance comes from knowing when to save and when to share.',
      reversedInterpretation:
          'Letting go of material attachment or reckless spending. Either extreme — hoarding or squandering — disrupts your balance. Find the middle ground with money.',
    ),
    TarotCard(
      name: 'Five of Pentacles',
      number: 'Pentacles V',
      meaning: 'Hardship, insecurity, worry',
      interpretation:
          'Financial hardship or feelings of being left out in the cold weigh on you. Help is closer than you think — look up and seek the warmth that awaits. Hard times are temporary; your spirit is resilient.',
      reversedInterpretation:
          'Recovery from financial difficulty. A helping hand appears or inner resources are discovered. The worst of the hardship passes and stability slowly returns.',
    ),
    TarotCard(
      name: 'Six of Pentacles',
      number: 'Pentacles VI',
      meaning: 'Generosity, charity, sharing wealth',
      interpretation:
          'The flow of giving and receiving is highlighted. Share your resources generously, or accept help with grace. Balance in material exchanges brings karmic rewards and deepens your connections.',
      reversedInterpretation:
          'Strings attached to generosity or unfair distribution of resources. Debt or obligation taints giving. Ensure your generosity comes without hidden conditions.',
    ),
    TarotCard(
      name: 'Seven of Pentacles',
      number: 'Pentacles VII',
      meaning: 'Patience, investment, long-term view',
      interpretation:
          'Your investments of time and effort are growing, though slowly. Patience is required — the harvest is not yet ready. Evaluate your progress and trust that steady nurturing yields the richest rewards.',
      reversedInterpretation:
          'Impatience with slow results or wasted effort. Your investment may not yield the expected return. Reassess whether this path is worth continued effort.',
    ),
    TarotCard(
      name: 'Eight of Pentacles',
      number: 'Pentacles VIII',
      meaning: 'Apprenticeship, skill development, diligence',
      interpretation:
          'Dedicated practice and skill refinement define this moment. Pour yourself into mastering your craft with focus and diligence. Each careful repetition brings you closer to excellence.',
      reversedInterpretation:
          'Shortcuts undermine quality. Boredom with repetitive work or perfectionism that paralyzes progress. Find joy in the process, not just the product.',
    ),
    TarotCard(
      name: 'Nine of Pentacles',
      number: 'Pentacles IX',
      meaning: 'Luxury, self-sufficiency, financial independence',
      interpretation:
          'You have earned this moment of luxury and self-sufficiency through hard work. Enjoy the fruits of your labor with gratitude. Financial independence and personal refinement are your well-deserved rewards.',
      reversedInterpretation:
          'Financial setbacks threaten your independence. Over-reliance on others or living beyond your means. Recalibrate your lifestyle to match your actual resources.',
    ),
    TarotCard(
      name: 'Ten of Pentacles',
      number: 'Pentacles X',
      meaning: 'Legacy, inheritance, long-term success',
      interpretation:
          'Lasting wealth and family legacy are themes now. Your efforts create security not just for you but for future generations. Traditions, inheritance, and the wisdom of your lineage bring deep fulfillment.',
      reversedInterpretation:
          'Family financial disputes or a legacy under threat. Inheritance conflicts or broken family traditions. Focus on what truly matters beyond material wealth.',
    ),
    TarotCard(
      name: 'Page of Pentacles',
      number: 'Pentacles Page',
      meaning: 'Ambition, desire to learn, new venture',
      interpretation:
          'A studious energy focuses on new goals and practical learning. A promising opportunity for growth requires dedication and a willingness to start at the beginning. Your ambition is your compass.',
      reversedInterpretation:
          'Lack of focus or unrealistic goals. Procrastination prevents progress on practical matters. Ground your ambitions in actionable steps and commit to the work.',
    ),
    TarotCard(
      name: 'Knight of Pentacles',
      number: 'Pentacles Knight',
      meaning: 'Hard work, routine, responsibility',
      interpretation:
          'Steady, methodical progress defines your path forward. Though not flashy, your reliable approach and tireless work ethic build unshakable foundations. Trust the process — consistency creates greatness.',
      reversedInterpretation:
          'Stubbornness, boredom, or stagnation in routine. Your methodical approach becomes monotonous. Introduce small changes to reignite motivation while maintaining stability.',
    ),
    TarotCard(
      name: 'Queen of Pentacles',
      number: 'Pentacles Queen',
      meaning: 'Nurturing, practical, providing',
      interpretation:
          'Grounded abundance and nurturing energy flow through you. Create a secure, comfortable environment for yourself and others. Your practical wisdom and generous spirit make the world a warmer place.',
      reversedInterpretation:
          'Neglecting self-care while providing for everyone else. Work-life imbalance or financial anxiety. Nurture yourself with the same generosity you show others.',
    ),
    TarotCard(
      name: 'King of Pentacles',
      number: 'Pentacles King',
      meaning: 'Wealth, business, leadership, security',
      interpretation:
          'Material mastery and prosperous leadership define your influence. Your disciplined approach to wealth and business commands respect. Enjoy your success while continuing to build with integrity and vision.',
      reversedInterpretation:
          'Greed, materialism, or financial mismanagement. Success at the expense of relationships or health. Rebalance your priorities — wealth without well-being is hollow.',
    ),
  ];

  static HoroscopeData getHoroscope(String sign) {
    final horoscopes = {
      'Aries': const HoroscopeData(
        sign: 'Aries',
        date: 'Today',
        general:
            'Today brings a surge of energy and motivation. The stars align to support bold decisions. Trust your instincts and take that leap of faith you\'ve been contemplating.',
        love:
            'Romance is in the air. If single, an unexpected encounter could spark something beautiful. Couples should plan a spontaneous date to reignite the flame.',
        career:
            'Your leadership skills shine brightly today. A new project or opportunity may present itself. Colleagues look to you for guidance — embrace it confidently.',
        health:
            'Channel your abundant energy into physical activity. A morning workout sets the tone for a vibrant day. Stay hydrated and take breaks when needed.',
        overallScore: 85,
        luckyNumber: '7',
        luckyColor: 'Red',
        mood: 'Energetic',
      ),
      'Taurus': const HoroscopeData(
        sign: 'Taurus',
        date: 'Today',
        general:
            'Stability and comfort are your themes today. Focus on building lasting foundations in all areas of life. Your patience will be rewarded with meaningful progress.',
        love:
            'Show your partner your appreciation through small, thoughtful gestures. Singles may find comfort in a familiar face that sees you in a new light.',
        career:
            'Financial opportunities arise. Your practical approach to work impresses superiors. A steady, methodical approach yields the best results today.',
        health:
            'Treat yourself to nourishing food and gentle exercise. A walk in nature reconnects you with your earthy energy. Avoid overindulgence.',
        overallScore: 78,
        luckyNumber: '4',
        luckyColor: 'Green',
        mood: 'Grounded',
      ),
      'Gemini': const HoroscopeData(
        sign: 'Gemini',
        date: 'Today',
        general:
            'Your mind buzzes with brilliant ideas today. Social connections bring unexpected opportunities. Embrace your dual nature — both logic and creativity serve you well right now.',
        love:
            'Communication is your superpower in love today. Share your thoughts openly — vulnerability strengthens bonds. Singles may find sparks flying through witty conversation.',
        career:
            'Multitasking comes naturally today. A brainstorming session yields breakthrough ideas. Network actively — your charm opens doors that effort alone cannot.',
        health:
            'Mental stimulation is as vital as physical health. Try a puzzle or learn something new. Calm your racing mind with breathing exercises before bed.',
        overallScore: 82,
        luckyNumber: '5',
        luckyColor: 'Yellow',
        mood: 'Curious',
      ),
      'Cancer': const HoroscopeData(
        sign: 'Cancer',
        date: 'Today',
        general:
            'Home and family take center stage today. Your nurturing instincts are heightened — trust them. Emotional insights guide you toward meaningful decisions that benefit everyone around you.',
        love:
            'Deep emotional connections flourish today. Express your feelings without fear — your partner craves your tenderness. Singles may feel drawn to someone who feels like home.',
        career:
            'Your intuition about workplace dynamics is spot-on today. A supportive gesture toward a colleague builds a lasting alliance. Creative projects benefit from your emotional depth.',
        health:
            'Comfort food calls, but balance indulgence with nutrition. Water activities soothe your soul — consider a swim or a long bath. Prioritize rest tonight.',
        overallScore: 79,
        luckyNumber: '2',
        luckyColor: 'Silver',
        mood: 'Nurturing',
      ),
      'Leo': const HoroscopeData(
        sign: 'Leo',
        date: 'Today',
        general:
            'The spotlight finds you effortlessly today. Your natural radiance draws admiration and opportunity. Step into your power with confidence — the universe rewards bold self-expression.',
        love:
            'Passion runs high today. Grand gestures and heartfelt words strengthen romantic bonds. Singles should let their magnetic personality shine — someone special is watching.',
        career:
            'Leadership opportunities abound. Your creative vision inspires your team and catches the attention of decision-makers. Present your ideas with the confidence they deserve.',
        health:
            'Your vitality is strong today. Channel it into an activity you love — dance, sports, or outdoor adventures. Protect your heart with cardiovascular exercise.',
        overallScore: 88,
        luckyNumber: '1',
        luckyColor: 'Gold',
        mood: 'Confident',
      ),
      'Virgo': const HoroscopeData(
        sign: 'Virgo',
        date: 'Today',
        general:
            'Details matter today, and you see them all. Your analytical mind solves problems others overlook. Focus on organization and refinement — small improvements lead to significant results.',
        love:
            'Acts of service speak louder than words in love today. Show you care through practical support. Singles may connect with someone who appreciates your thoughtful, grounded nature.',
        career:
            'Precision and thoroughness earn you recognition. A complex task that others gave up on yields to your methodical approach. Document your process — it will be valuable later.',
        health:
            'Pay attention to nutrition and digestive health today. A clean, balanced meal plan works wonders. Gentle yoga or stretching helps release tension you carry in your shoulders.',
        overallScore: 81,
        luckyNumber: '6',
        luckyColor: 'Navy',
        mood: 'Analytical',
      ),
      'Libra': const HoroscopeData(
        sign: 'Libra',
        date: 'Today',
        general:
            'Harmony and balance guide you today. Your diplomatic skills resolve tensions with grace. Beauty surrounds you — take time to appreciate art, music, or the natural world.',
        love:
            'Partnership energy is strong. Compromise comes easily and deepens your connection. Singles are drawn to elegance and intellect — an art gallery or concert may hold romantic potential.',
        career:
            'Collaboration yields exceptional results. Your ability to see all sides makes you an invaluable mediator. A partnership or joint venture shows promising signs today.',
        health:
            'Seek aesthetic pleasure in your wellness routine. A beautifully prepared meal or a luxurious skincare ritual lifts your spirits. Balance social time with peaceful solitude.',
        overallScore: 80,
        luckyNumber: '8',
        luckyColor: 'Pink',
        mood: 'Harmonious',
      ),
      'Scorpio': const HoroscopeData(
        sign: 'Scorpio',
        date: 'Today',
        general:
            'Powerful transformations stir beneath the surface today. Your intensity and depth of perception reveal hidden truths. Trust your instincts — they pierce through illusion like no other sign.',
        love:
            'Intimacy deepens as you allow yourself to be truly seen. Magnetic attraction draws others to your enigmatic presence. Singles may feel an intense, almost fated connection.',
        career:
            'Research and investigation yield breakthroughs. Your ability to dig deeper where others stop gives you a competitive edge. A secret or hidden information comes to light in your favor.',
        health:
            'Emotional release is vital for your well-being today. Journal, meditate, or engage in intense exercise to process deep feelings. Hydration and detoxifying foods support your body.',
        overallScore: 83,
        luckyNumber: '3',
        luckyColor: 'Crimson',
        mood: 'Intense',
      ),
      'Sagittarius': const HoroscopeData(
        sign: 'Sagittarius',
        date: 'Today',
        general:
            'Adventure beckons and your optimism is infectious. The horizon expands with possibilities — say yes to new experiences. A philosophical insight shifts your perspective in a meaningful way.',
        love:
            'Freedom and excitement fuel your romantic energy. Surprise your partner with a spontaneous adventure. Singles thrive in travel or educational settings — love finds the open-minded.',
        career:
            'Big-picture thinking sets you apart today. An international or cross-cultural opportunity may arise. Your enthusiasm for learning opens doors to growth. Teach others what you know.',
        health:
            'Outdoor activity is your best medicine. Hiking, cycling, or exploring a new trail invigorates your body and spirit. Watch your tendency to overdo — moderation sustains energy.',
        overallScore: 86,
        luckyNumber: '11',
        luckyColor: 'Turquoise',
        mood: 'Adventurous',
      ),
      'Capricorn': const HoroscopeData(
        sign: 'Capricorn',
        date: 'Today',
        general:
            'Discipline and ambition drive you toward your goals today. Long-term plans crystallize into actionable steps. Your reputation for reliability opens doors — honor your commitments.',
        love:
            'Steady devotion speaks volumes today. Show your commitment through consistency and dependability. Singles may find attraction in someone ambitious and grounded like themselves.',
        career:
            'Authority figures take notice of your dedication. A promotion or increased responsibility is on the horizon. Your strategic planning pays dividends — stay the course.',
        health:
            'Bone and joint health deserve attention. Strength training and calcium-rich foods support your framework. Take breaks from desk work — your posture will thank you.',
        overallScore: 77,
        luckyNumber: '10',
        luckyColor: 'Charcoal',
        mood: 'Determined',
      ),
      'Aquarius': const HoroscopeData(
        sign: 'Aquarius',
        date: 'Today',
        general:
            'Innovation and originality mark your day. Your unconventional ideas are ahead of their time — don\'t let skeptics dim your vision. Community involvement brings unexpected fulfillment.',
        love:
            'Intellectual connection sparks romance. Share your visions for the future with someone who appreciates your uniqueness. Singles may find love through humanitarian causes or group activities.',
        career:
            'Technology and innovation are your allies. A creative solution to a longstanding problem earns respect. Collaborate with like-minded visionaries — together you can change the game.',
        health:
            'Circulation and nervous system health benefit from attention today. Try something unconventional — cold plunges, acupuncture, or sound healing. Social wellness matters too.',
        overallScore: 84,
        luckyNumber: '22',
        luckyColor: 'Electric Blue',
        mood: 'Visionary',
      ),
      'Pisces': const HoroscopeData(
        sign: 'Pisces',
        date: 'Today',
        general:
            'Your imagination and intuition are exceptionally strong today. Dreams may hold meaningful messages — pay attention. Creative and spiritual pursuits bring deep satisfaction and clarity.',
        love:
            'Your empathetic nature creates soul-deep connections. Romance feels almost magical today — lean into it. Singles may sense a kindred spirit through art, music, or shared vulnerability.',
        career:
            'Creative projects flourish under your inspired touch. Your ability to sense what others need makes you invaluable in collaborative settings. Trust your artistic vision — it\'s right on target.',
        health:
            'Water is your healing element today. Swimming, baths, or simply drinking more water restores your energy. Protect your sensitive nature with healthy boundaries and quiet reflection.',
        overallScore: 76,
        luckyNumber: '12',
        luckyColor: 'Sea Green',
        mood: 'Dreamy',
      ),
    };
    return horoscopes[sign] ??
        HoroscopeData(
          sign: sign,
          date: 'Today',
          general:
              'The cosmos sends you waves of positive energy today. Embrace new opportunities and trust in the universal flow. Your intuition is your greatest guide.',
          love:
              'Open your heart to love\'s possibilities. Whether deepening existing bonds or discovering new connections, the stars favor matters of the heart.',
          career:
              'Professional growth is highlighted. Your unique talents catch the eye of someone influential. Stay focused and dedicated to your goals.',
          health:
              'Balance is key today. Nourish your body, mind, and spirit equally. Gentle exercise and meditation bring harmony to your well-being.',
          overallScore: 75,
          luckyNumber: '9',
          luckyColor: 'Purple',
          mood: 'Intuitive',
        );
  }

  static CompatibilityResult getCompatibility(String sign1, String sign2) {
    final scores = {
      'Fire-Fire': 80,
      'Fire-Air': 85,
      'Fire-Earth': 55,
      'Fire-Water': 50,
      'Air-Fire': 85,
      'Air-Air': 75,
      'Air-Earth': 60,
      'Air-Water': 65,
      'Earth-Fire': 55,
      'Earth-Air': 60,
      'Earth-Earth': 90,
      'Earth-Water': 85,
      'Water-Fire': 50,
      'Water-Air': 65,
      'Water-Earth': 85,
      'Water-Water': 80,
    };

    final e1 = zodiacSigns.firstWhere((z) => z.name == sign1).element;
    final e2 = zodiacSigns.firstWhere((z) => z.name == sign2).element;
    final score = scores['$e1-$e2'] ?? 70;

    return CompatibilityResult(
      sign1: sign1,
      sign2: sign2,
      score: score,
      description: score >= 80
          ? 'An excellent cosmic match! You two share a deep, natural connection that flows effortlessly.'
          : score >= 60
          ? 'A promising pairing with room to grow. Your differences complement each other beautifully when embraced.'
          : 'A challenging but potentially transformative match. Growth comes through understanding your differences.',
      loveAdvice: score >= 80
          ? 'Nurture your bond with shared experiences and open communication. Your connection is truly special.'
          : 'Focus on understanding each other\'s needs. Patience and compromise strengthen your bond.',
      strengthsTogether: score >= 80
          ? 'Mutual understanding, shared values, natural chemistry'
          : 'Complementary perspectives, opportunities for growth, dynamic energy',
      challenges: score >= 80
          ? 'Avoid complacency — keep the spark alive through new adventures together.'
          : 'Different communication styles may cause misunderstandings. Practice active listening.',
    );
  }

  static KundliResult getKundliResult() {
    return const KundliResult(
      totalScore: 26,
      maxScore: 36,
      kootaScores: {
        'Varna': 1,
        'Vashya': 2,
        'Tara': 3,
        'Yoni': 4,
        'Graha Maitri': 5,
        'Gana': 6,
        'Bhakoot': 3,
        'Nadi': 2,
      },
      compatibility: 'Good',
      analysis:
          'The Gun Milan score indicates good compatibility between the two individuals. The planetary alignments suggest a harmonious relationship with strong emotional and spiritual bonds. Minor challenges in the Nadi koota can be mitigated through understanding and mutual respect.',
      hasManglikDosha: false,
    );
  }

  static const List<AstrologyStory> stories = [
    AstrologyStory(
      title: 'Mercury Retrograde Survival Guide',
      summary: 'Navigate communication chaos with these proven strategies',
      category: 'Planetary',
      readTime: '5 min',
      content:
          'Mercury retrograde is a time to slow down, review, and reflect...',
    ),
    AstrologyStory(
      title: 'Luckiest Zodiac Signs This Week',
      summary: 'Discover which signs the stars favor from March 18-24',
      category: 'Weekly',
      readTime: '3 min',
      content: 'This week brings extraordinary luck to fire signs...',
    ),
    AstrologyStory(
      title: 'Your Zodiac Love Language',
      summary: 'How each sign expresses and receives love',
      category: 'Relationships',
      readTime: '7 min',
      content:
          'Understanding your zodiac love language transforms relationships...',
    ),
    AstrologyStory(
      title: 'Full Moon Rituals for Each Element',
      summary: 'Harness lunar energy with element-specific practices',
      category: 'Rituals',
      readTime: '6 min',
      content: 'The full moon amplifies the energy of each element...',
    ),
    AstrologyStory(
      title: 'Career Paths Written in the Stars',
      summary: 'Ideal professions for every zodiac sign',
      category: 'Career',
      readTime: '8 min',
      content:
          'Your birth chart reveals natural talents and career inclinations...',
    ),
  ];

  static const List<String> fortuneTopics = [
    'Love',
    'Career',
    'Health',
    'Wealth',
    'Spiritual',
  ];
  static const List<String> moods = [
    'Happy',
    'Curious',
    'Anxious',
    'Hopeful',
    'Reflective',
  ];

  static const List<String> fortunes = [
    'The stars whisper of an unexpected encounter that will change your perspective on love. Keep your heart open to the cosmic surprise approaching.',
    'A golden opportunity disguised as a challenge arrives this week. Your determination and creativity will turn obstacles into stepping stones toward success.',
    'The universe is aligning to bring abundance into your life. Trust the timing of your journey — every delay has been a divine redirection.',
    'A past connection resurfaces with new meaning. What once seemed like an ending reveals itself as the beginning of something more beautiful.',
    'Your intuition is your superpower today. That gut feeling you\'ve been ignoring? It\'s the cosmos sending you a message. Listen closely.',
  ];
}
