"""Static Vedic reference data used by the Vedic summary service."""

TITHI_NAMES = [
    "Pratipada",
    "Dvitiya",
    "Tritiya",
    "Chaturthi",
    "Panchami",
    "Shashthi",
    "Saptami",
    "Ashtami",
    "Navami",
    "Dashami",
    "Ekadashi",
    "Dwadashi",
    "Trayodashi",
    "Chaturdashi",
    "Purnima",
    "Pratipada",
    "Dvitiya",
    "Tritiya",
    "Chaturthi",
    "Panchami",
    "Shashthi",
    "Saptami",
    "Ashtami",
    "Navami",
    "Dashami",
    "Ekadashi",
    "Dwadashi",
    "Trayodashi",
    "Chaturdashi",
    "Amavasya",
]

YOGA_NAMES = [
    "Vishkumbha", "Priti", "Ayushman", "Saubhagya", "Shobhana",
    "Atiganda", "Sukarma", "Dhriti", "Shoola", "Ganda",
    "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra",
    "Siddhi", "Vyatipata", "Variyana", "Parigha", "Shiva",
    "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma",
    "Indra", "Vaidhriti",
]

KARANA_SEQUENCE = [
    "Bava", "Balava", "Kaulava", "Taitila", "Garaja", "Vanija", "Vishti",
]

KARANA_FIXED = {
    1: "Kimstughna",
    58: "Shakuni",
    59: "Chatushpada",
    60: "Naga",
}

VARA_NAMES = [
    "Somvaar",
    "Mangalvaar",
    "Budhvaar",
    "Guruvaar",
    "Shukrvaar",
    "Shanivaar",
    "Ravivaar",
]

VARA_RULERS = [
    "Moon",
    "Mars",
    "Mercury",
    "Jupiter",
    "Venus",
    "Saturn",
    "Sun",
]

VARA_SYMBOLS = ["Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Sun"]

RASHI_NAMES = [
    "Mesha", "Vrishabha", "Mithuna", "Karka", "Simha", "Kanya",
    "Tula", "Vrischika", "Dhanu", "Makara", "Kumbha", "Meena",
]

DASHA_SEQUENCE = [
    "Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury",
]

DASHA_YEARS = {
    "Ketu": 7,
    "Venus": 20,
    "Sun": 6,
    "Moon": 10,
    "Mars": 7,
    "Rahu": 18,
    "Jupiter": 16,
    "Saturn": 19,
    "Mercury": 17,
}

PLANET_GEMSTONES = {
    "Sun": "Ruby",
    "Moon": "Pearl",
    "Mars": "Red Coral",
    "Mercury": "Emerald",
    "Jupiter": "Yellow Sapphire",
    "Venus": "Diamond",
    "Saturn": "Blue Sapphire",
    "Rahu": "Hessonite",
    "Ketu": "Cat's Eye",
}

PLANET_MANTRAS = {
    "Sun": "Om Suryaya Namah",
    "Moon": "Om Chandraya Namah",
    "Mars": "Om Mangalaya Namah",
    "Mercury": "Om Budhaya Namah",
    "Jupiter": "Om Gurave Namah",
    "Venus": "Om Shukraya Namah",
    "Saturn": "Om Shanaye Namah",
    "Rahu": "Om Rahave Namah",
    "Ketu": "Om Ketave Namah",
}

PLANET_FASTING_DAYS = {
    "Sun": "Sunday",
    "Moon": "Monday",
    "Mars": "Tuesday",
    "Mercury": "Wednesday",
    "Jupiter": "Thursday",
    "Venus": "Friday",
    "Saturn": "Saturday",
    "Rahu": "Saturday",
    "Ketu": "Tuesday",
}

HINDU_MONTH_WINDOWS = [
    ((1, 14), "Pausha"),
    ((2, 13), "Magha"),
    ((3, 14), "Phalguna"),
    ((4, 14), "Chaitra"),
    ((5, 15), "Vaishakha"),
    ((6, 15), "Jyeshtha"),
    ((7, 16), "Ashadha"),
    ((8, 17), "Shravana"),
    ((9, 17), "Bhadrapada"),
    ((10, 18), "Ashwin"),
    ((11, 16), "Kartika"),
    ((12, 16), "Margashirsha"),
]

FESTIVAL_DATES = [
    {"name": "Akshaya Tritiya", "date": "2026-05-10"},
    {"name": "Guru Purnima", "date": "2026-07-29"},
    {"name": "Janmashtami", "date": "2026-09-04"},
    {"name": "Navratri Begins", "date": "2026-10-12"},
    {"name": "Dussehra", "date": "2026-10-21"},
    {"name": "Diwali", "date": "2026-11-08"},
    {"name": "Makar Sankranti", "date": "2027-01-14"},
    {"name": "Mahashivratri", "date": "2027-03-07"},
    {"name": "Holi", "date": "2027-03-24"},
]

MUHURTA_LABELS = {
    "abhijit": "Abhijit Muhurta",
    "brahma": "Brahma Muhurta",
}
