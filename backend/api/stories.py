from fastapi import APIRouter, Query
from schemas import StoryResponse, StoryListResponse

router = APIRouter(prefix="/stories", tags=["Stories"])

# Pre-loaded stories (mirrors Flutter mock data)
STORIES = [
    {
        "id": 1, "title": "Mercury Retrograde Survival Guide",
        "summary": "Navigate communication chaos with these proven strategies",
        "category": "Planetary", "read_time": "5 min", "author": "CosmicGuide",
        "content": (
            "Mercury retrograde is a time to slow down, review, and reflect. "
            "During this period, communication mishaps, technology glitches, and travel delays are common. "
            "But it's not all doom and gloom — retrograde is actually an excellent time for revisiting old projects, "
            "reconnecting with people from your past, and refining your plans. "
            "Here are strategies for each element:\n\n"
            "Fire Signs (Aries, Leo, Sagittarius): Channel your restless energy into creative review rather than new launches.\n\n"
            "Earth Signs (Taurus, Virgo, Capricorn): Double-check contracts and financial documents before signing.\n\n"
            "Air Signs (Gemini, Libra, Aquarius): Be extra careful with words — re-read emails before sending.\n\n"
            "Water Signs (Cancer, Scorpio, Pisces): Use this time for deep emotional processing and journaling."
        ),
    },
    {
        "id": 2, "title": "Luckiest Zodiac Signs This Week",
        "summary": "Discover which signs the stars favor from March 18-24",
        "category": "Weekly", "read_time": "3 min", "author": "CosmicGuide",
        "content": (
            "This week brings extraordinary luck to fire signs as Jupiter forms a powerful trine with Mars. "
            "Aries leads the charge with career breakthroughs, while Leo finds unexpected romantic opportunities. "
            "Sagittarius sees financial gains from past investments.\n\n"
            "Earth signs enjoy steady progress, with Taurus receiving recognition at work and Virgo finding peace in daily routines. "
            "Capricorn benefits from networking events.\n\n"
            "Air signs experience intellectual breakthroughs. Gemini's creative projects gain traction, Libra resolves relationship conflicts, "
            "and Aquarius discovers innovative solutions to old problems.\n\n"
            "Water signs should focus on self-care. Cancer finds comfort in family connections, Scorpio undergoes personal transformation, "
            "and Pisces channels heightened intuition into artistic expression."
        ),
    },
    {
        "id": 3, "title": "Your Zodiac Love Language",
        "summary": "How each sign expresses and receives love",
        "category": "Relationships", "read_time": "7 min", "author": "CosmicGuide",
        "content": (
            "Understanding your zodiac love language transforms relationships. "
            "Each sign has a unique way of expressing and receiving love:\n\n"
            "Aries: Acts of courage and adventure. They show love by protecting and championing their partner.\n\n"
            "Taurus: Physical touch and quality gifts. A home-cooked meal is their ultimate love letter.\n\n"
            "Gemini: Words of affirmation and stimulating conversation. They fall in love through the mind first.\n\n"
            "Cancer: Nurturing acts and emotional security. Home is where their heart expresses itself.\n\n"
            "Leo: Grand gestures and generous praise. They love loudly and want the world to know it.\n\n"
            "Virgo: Acts of service and attention to detail. They show love through practical care.\n\n"
            "Libra: Harmonious partnership and aesthetic experiences. Beauty and balance are their love language.\n\n"
            "Scorpio: Deep emotional intimacy and unwavering loyalty. All or nothing in love.\n\n"
            "Sagittarius: Shared adventures and philosophical connection. Freedom within commitment.\n\n"
            "Capricorn: Long-term commitment and building together. Love is an investment they take seriously.\n\n"
            "Aquarius: Intellectual connection and friendship first. They love the unique and unconventional.\n\n"
            "Pisces: Emotional merging and creative expression. They love with their entire soul."
        ),
    },
    {
        "id": 4, "title": "Full Moon Rituals for Each Element",
        "summary": "Harness lunar energy with element-specific practices",
        "category": "Rituals", "read_time": "6 min", "author": "CosmicGuide",
        "content": (
            "The full moon amplifies the energy of each element. "
            "Here are powerful rituals tailored to your elemental nature:\n\n"
            "Fire Signs (Aries, Leo, Sagittarius):\n"
            "Light a red or orange candle and write down what you wish to release. "
            "Safely burn the paper, visualizing the flames transforming your intentions. "
            "Dance or move your body to release stagnant energy.\n\n"
            "Earth Signs (Taurus, Virgo, Capricorn):\n"
            "Create a crystal grid under the moonlight. Place your favorite stones in a sacred pattern. "
            "Ground yourself by walking barefoot on earth or grass. Plant seeds — literal or metaphorical.\n\n"
            "Air Signs (Gemini, Libra, Aquarius):\n"
            "Write letters to your future self under the full moon. Practice breathwork or meditation. "
            "Open windows to let fresh air circulate through your space, carrying away old energy.\n\n"
            "Water Signs (Cancer, Scorpio, Pisces):\n"
            "Take a moonlit bath with sea salt and essential oils. Place a glass of water under the full moon to charge it. "
            "Journal about your emotions and let tears flow if they come — water cleanses the soul."
        ),
    },
    {
        "id": 5, "title": "Career Paths Written in the Stars",
        "summary": "Ideal professions for every zodiac sign",
        "category": "Career", "read_time": "8 min", "author": "CosmicGuide",
        "content": (
            "Your birth chart reveals natural talents and career inclinations. "
            "While your sun sign is just one piece of the puzzle, it offers valuable guidance:\n\n"
            "Aries: Entrepreneur, athlete, military, surgeon, firefighter. Leadership roles where initiative is rewarded.\n\n"
            "Taurus: Banking, real estate, agriculture, culinary arts, luxury goods. Careers involving material security.\n\n"
            "Gemini: Journalism, teaching, marketing, social media, translation. Communication-driven professions.\n\n"
            "Cancer: Nursing, social work, childcare, hospitality, interior design. Nurturing and caring roles.\n\n"
            "Leo: Entertainment, politics, management, fashion, event planning. Center-stage careers.\n\n"
            "Virgo: Healthcare, editing, data analysis, research, nutrition. Detail-oriented precision work.\n\n"
            "Libra: Law, diplomacy, art curation, counseling, public relations. Careers requiring balance and fairness.\n\n"
            "Scorpio: Psychology, investigation, surgery, research, crisis management. Roles requiring depth and intensity.\n\n"
            "Sagittarius: Travel industry, philosophy, publishing, international business. Expansive, freedom-oriented careers.\n\n"
            "Capricorn: Corporate leadership, architecture, engineering, government. Building lasting structures.\n\n"
            "Aquarius: Technology, science, humanitarian work, innovation. Future-oriented and unconventional paths.\n\n"
            "Pisces: Music, film, healing arts, spirituality, marine biology. Creative and intuitive professions."
        ),
    },
]


@router.get("", response_model=StoryListResponse)
def list_stories(
    page: int = Query(1, ge=1),
    per_page: int = Query(10, ge=1, le=50),
    category: str = Query(None, description="Filter by category"),
):
    filtered = STORIES
    if category:
        filtered = [s for s in STORIES if s["category"].lower() == category.lower()]

    total = len(filtered)
    start = (page - 1) * per_page
    end = start + per_page
    page_stories = filtered[start:end]

    return StoryListResponse(
        stories=page_stories,
        total=total,
        page=page,
        per_page=per_page,
    )


@router.get("/{story_id}", response_model=StoryResponse)
def get_story(story_id: int):
    from fastapi import HTTPException
    story = next((s for s in STORIES if s["id"] == story_id), None)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    return story
