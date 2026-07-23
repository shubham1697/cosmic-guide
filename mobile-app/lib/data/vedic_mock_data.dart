import '../models/zodiac.dart';

const vedicHomeMockData = VedicHomeSummaryData(
  location: VedicLocationData(
    name: 'Delhi',
    latitude: 28.6139,
    longitude: 77.2090,
    timezone: 'Asia/Kolkata',
  ),
  panchang: PanchangSummaryData(
    date: '2026-04-30',
    vara: 'Guruvaar',
    varaRuler: 'Jupiter',
    tithi: 'Dwadashi',
    paksha: 'Shukla',
    nakshatra: 'Rohini',
    yoga: 'Sukarma',
    karana: 'Bava',
    insight:
        'Ruled by Jupiter, today leans toward wisdom, growth, and auspicious effort. The waxing Moon favours new beginnings, growth, and outward momentum.',
  ),
  calendar: VedicCalendarData(
    monthName: 'Vaishakha',
    samvatYear: 2083,
    nextFestivalName: 'Akshaya Tritiya',
    nextFestivalDate: '10 May 2026',
    note:
        'Akshaya Tritiya is traditionally associated with lasting prosperity, generosity, and auspicious beginnings.',
  ),
  muhurta: MuhurtaSummaryData(
    label: 'Abhijit Muhurta',
    startsAt: '11:57 AM',
    endsAt: '12:48 PM',
    note:
        'Use your strongest window for high-intent actions and keep routine work outside it.',
  ),
  timings: DailyTimingsData(
    sunrise: '5:42 AM',
    sunset: '7:01 PM',
    dayLength: '13h 19m',
    abhijit: '11:57 AM – 12:48 PM',
    brahmaMuhurta: '4:06 AM – 4:54 AM',
    rahuKaal: '1:57 PM – 3:37 PM',
    yamaganda: '5:42 AM – 7:22 AM',
    gulika: '9:02 AM – 10:42 AM',
  ),
  kundli: KundliSummaryData(
    lagna: 'Tula',
    moonSign: 'Vrishabha',
    nakshatra: 'Rohini',
    note: 'Chart summary ready.',
  ),
  dasha: DashaSummaryData(
    mahadasha: 'Moon',
    mahadashaEndsOn: '2031-08-10',
    antardasha: 'Jupiter',
    guidance:
        'A Moon period deepens emotional sensitivity, family focus, and inner nourishment.',
  ),
  dosha: DoshaSummaryData(
    activeCount: 1,
    topDoshas: ['Manglik Dosha'],
    summary:
        'Manglik influence is best handled with patience, clear communication, and steady emotional maturity.',
  ),
  remedy: RemedySummaryData(
    focus: 'Manglik Dosha',
    gemstone: 'Red Coral',
    mantra: 'Om Mangalaya Namah',
    fastingDay: 'Tuesday',
    guidance:
        'For Mars-heavy periods, calm speech, Tuesday discipline, and grounding routines matter more than dramatic fixes.',
  ),
);
