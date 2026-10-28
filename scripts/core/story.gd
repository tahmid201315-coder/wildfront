class_name Story
extends RefCounted
## All narrative text: cutscenes, NPC dialogue, journals, boss intros/defeats, inscriptions, side quests.
## Pure data so it can be reviewed and tested without running the game.

const FRAGMENT_NAMES := ["Dawn", "Ember", "Tide", "Bloom", "Frost", "Cog", "Eclipse"]

const CUTSCENES := {
	"intro": [
		{"scene": "night", "text": "Once, a star named the Starheart hung above Aetheria and kept every sky-island in the world alight."},
		{"scene": "shatter", "text": "A hundred years ago it broke. Seven fragments fell across the land, and the sky has been grey ever since."},
		{"scene": "kael", "text": "Kael, a young explorer of the Lantern Guild, has followed the old maps this far. Tonight he steps onto the Whispering Meadows."},
		{"scene": "kael", "text": "\"If the Starheart can be mended, I will find every piece. Somebody has to bring the light back.\""},
	],
	"fragment": [
		{"scene": "fragment", "text": "The fragment hums against Kael's chest, as if it recognises him."},
	],
	"reveal1": [
		{"scene": "ruins", "text": "In the Thornwild, Kael finds carvings of seven Keepers who stood around the Starheart on the night it broke."},
		{"scene": "ruins", "text": "The carvings show the Keepers striking it themselves. The Starheart was not destroyed by an enemy. It was shattered on purpose."},
	],
	"reveal2": [
		{"scene": "eclipse", "text": "Beyond the Clockwork Abyss a black sun hangs over broken towers. The Eclipse Realm."},
		{"scene": "eclipse", "text": "The fragments in Kael's chest burn. Something in that place is calling to them. And to him."},
	],
	"finale": [
		{"scene": "architect", "text": "The Architect falls, and the black sun cracks. His voice is no longer a roar. It is tired, and almost gentle."},
		{"scene": "architect", "text": "\"I built Aetheria around a dying star. When it began to fade, I could not bear it. I tried to freeze the world in one unending evening.\""},
		{"scene": "keepers", "text": "\"The Keepers broke the Starheart to stop me. But a heart cannot be destroyed, only scattered. Its last spark fell, and grew, and became a boy.\""},
		{"scene": "kael", "text": "\"You are not a stranger to the Starheart, Kael. You are what it became. The fragments are not pieces you collect. They are pieces of you coming home.\""},
		{"scene": "light", "text": "Kael raises the seven fragments. The Architect gives up the last of his own light to close the Heart, and the sky of Aetheria blazes gold."},
	],
	"ending": [
		{"scene": "dawn", "text": "Dawn spreads over the Whispering Meadows for the first time in a hundred years."},
		{"scene": "dawn", "text": "Kael is still Kael. The Starheart burns in his chest, and the islands drift lightly above him in the warm air."},
		{"scene": "dawn", "text": "Some nights the villagers swear a new star winks from the horizon, the one that walks. The world is whole, and so is he."},
	],
}

const BOSSES := {
	"meadow_colossus": {"name": "Meadow Colossus", "title": "Warden of the Green Islands",
		"intro": ["The stone giant stirs, vines tearing loose from its shoulders.", "COLOSSUS: \"The Heart... is broken. Turn back.\""],
		"defeat": ["The Colossus sinks into the grass, and a green light rises from its chest.", "The Dawn fragment settles into Kael's hands."]},
	"furnace_behemoth": {"name": "Furnace Behemoth", "title": "Engine of the Deep Forge",
		"intro": ["Furnace doors slam open. A hulking engine of iron and flame turns its glowing eyes on Kael.", "BEHEMOTH: \"Fuel... the Heart... fuel...\""],
		"defeat": ["The fires gutter. The Behemoth sags, and a red-gold fragment drops from its boiler.", "The Ember fragment warms Kael's palm."]},
	"astral_watcher": {"name": "Astral Watcher", "title": "The Eye of the Drowned Stars",
		"intro": ["Every window of the observatory turns to look at Kael. A great eye opens in the water.", "WATCHER: \"I have counted the stars for a hundred years. One is missing. You carry it.\""],
		"defeat": ["The eye closes slowly, like a tired sleeper.", "The Tide fragment floats up from the dark water."]},
	"thorn_queen": {"name": "Thorn Queen", "title": "Sovereign of the Rotting Root",
		"intro": ["The forest floor splits. A crown of thorns rises over a woman made of roots and flowers.", "QUEEN: \"You are not the first thief of the light. You smell like it.\""],
		"defeat": ["The thorns wither to soft green moss.", "QUEEN: \"Keep it... it was always meant to go home.\" The Bloom fragment opens like a flower."]},
	"frostbound_king": {"name": "Frostbound King", "title": "Monarch of the Last Winter",
		"intro": ["The citadel doors freeze shut behind Kael. A crowned figure rises from the ice throne.", "KING: \"I stood guard when the sky fell. I will not stand aside now.\""],
		"defeat": ["The ice crown cracks and falls. The king kneels, free of the cold for the first time in a century.", "KING: \"Seven... I remember seven. Go on, little spark.\" The Frost fragment shines pale blue."]},
	"clockwork_sovereign": {"name": "Clockwork Sovereign", "title": "Regent of the Endless Gears",
		"intro": ["Gears the size of towns grind together. At their centre a brass colossus unfolds six arms.", "SOVEREIGN: \"All is measured. All is ordered. You are an error.\""],
		"defeat": ["The Sovereign's mechanism spins down. One by one the gears fall silent.", "The Cog fragment drops into Kael's hands, still turning."]},
	"eclipse_architect": {"name": "Eclipse Architect", "title": "Builder of the Black Sun",
		"intro": ["The black sun lowers. A figure steps out of it, robed in broken constellations.", "ARCHITECT: \"Six pieces. Come to finish what I started? Come, Starheart. Come home.\""],
		"defeat": ["The Architect staggers. Where the black sun hung, there is only sky.", "ARCHITECT: \"There. You see? It was never about the fragments.\""]},
}

const JOURNALS := {
	"meadows_a": {"title": "Lantern Guild Log, Day 1", "text": "The Whispering Meadows are quiet, too quiet. The islands float a little lower each year, as though the sky itself were tired. I mark every shrine I find. If a map can save the world, mine will."},
	"meadows_b": {"title": "A Stonemason's Note", "text": "The Colossus was not built to fight. It was built to hold the islands up. Somebody woke it angry. That is a different kind of wrong."},
	"ember_a": {"title": "Forgeman Dorrick", "text": "Furnace Seven runs without a hand on it. We stopped feeding it coal a hundred years ago. It still burns. I think it burns the Starheart."},
	"ember_b": {"title": "Scrap of Letter", "text": "Do not trust the cheerful lava. Do not trust the quiet one either. The Behemoth's rhythm: three stomps, then it vents. Run when it vents."},
	"obs_a": {"title": "Astronomer's Ledger", "text": "Night 4,011. The sixth star blinked and did not return. We drew the sky wrong for a century because of that gap. Whoever finds it will know where the lost light went."},
	"obs_b": {"title": "Flooded Notes", "text": "The water rose the night the Heart broke, as though the sky had spilled. The Watcher counts, and counts, and never sleeps. Dazzle its eye and it blinks."},
	"thorn_a": {"title": "Ranger's Warning", "text": "The thorns remember who walks past them. Bring a lantern and a quick step. Spores drift down by the old roots: they slow you, never kill you, but things hunt in the slow."},
	"thorn_b": {"title": "Carved in Bark", "text": "THE SEVEN STOOD. THE SEVEN STRUCK. THE SEVEN WEPT. -- a Keeper's memory, preserved in the forest's rings."},
	"frost_a": {"title": "Sentry's Diary", "text": "The king never leaves the throne room now. The cold has become his armour. Ice makes you slide, so mind your jumps near the edges. Cold feet, warm heart, they say."},
	"frost_b": {"title": "Cracked Tablet", "text": "WHEN THE HEART BROKE, THE KEEPERS WERE ORDERED TO GUARD THE PIECES, NOT TO MEND IT. WHO GAVE THE ORDER IS NOT WRITTEN HERE."},
	"clock_a": {"title": "Gearwright's Manual", "text": "Every wheel in the Abyss is connected. Stop one and the rest will shudder. A stilled mechanism gives you a moment to cross. Tinka says: use the stasis, then run!"},
	"clock_b": {"title": "Unfinished Blueprint", "text": "The Sovereign was meant to build bridges. Someone changed the plans so it would build walls. The drawing is signed with a small black circle."},
	"eclipse_a": {"title": "Black Sun Fragment", "text": "He called it mercy: a world that never ends, never changes, never grieves. A gentler cage than a falling sky. We believed him once."},
	"eclipse_b": {"title": "The Last Page", "text": "The spark fell into the meadow. A child found it. We hid the child's name even from ourselves. Forgive us. -- the Seventh Keeper"},
}

const NPCS := {
	"merchant": {"name": "Orrin the Peddler", "color": Color(0.8, 0.5, 0.25),
		"lines": ["Shards for goods, friend! I follow the paths nobody else will.", "Take a look at my stock. Fair prices, I promise.", "Mind the dark corners, hm? That is where the interesting things hide."],
		"after_boss": "Seven fragments! The whole sky is talking about you, you know."},
	"inventor": {"name": "Tinka Gearsong", "color": Color(0.3, 0.7, 0.6),
		"lines": ["Aether dust! Bring me dust and I will sharpen anything you carry.", "I can improve your equipment, if you have the dust. Each upgrade makes it better.", "Stasis plus a moving platform equals free movement! Science!"],
		"after_boss": "You beat the Sovereign?! My gears are jealous."},
	"scholar": {"name": "Sage Veyla", "color": Color(0.5, 0.45, 0.85),
		"lines": ["The Keepers left pages everywhere. Gather them, and a story will assemble itself.", "The shrines are not just rest stops. They are the Starheart remembering where it used to burn.", "Look at the walls closely. The Astral Lens reveals what the stone hides."],
		"after_boss": "You carry the Heart. I suspected, but... never mind. Walk lightly, Kael."},
	"warrior": {"name": "Captain Brann", "color": Color(0.75, 0.3, 0.3),
		"lines": ["Keep your guard up and your dodge ready. A dodge is worth three potions.", "Strike, strike, strike for the finisher. Patience wins fights; panic loses them.", "Telegraphs, kid. Every monster tells you before it bites. Learn to read them."],
		"after_boss": "I fought beside giants once. You would have stood with them."},
}

# type: kill (target = enemy kind), journals, chests, shrines, shards, boss (target boss id), bosses (count)
const QUESTS := {
	"slime_trouble": {"title": "Slime Trouble", "giver": "warrior", "desc": "Defeat 8 Sky Slimes in the Meadows.", "type": "kill", "target": "slime", "count": 8, "reward": {"shards": 40}},
	"lost_pages": {"title": "Pages of the Keepers", "giver": "scholar", "desc": "Find 5 journal pages anywhere in Aetheria.", "type": "journals", "target": "", "count": 5, "reward": {"skill_point": 1}},
	"treasure_hunter": {"title": "Treasure Hunter", "giver": "merchant", "desc": "Open 6 chests.", "type": "chests", "target": "", "count": 6, "reward": {"shards": 60, "dust": 5}},
	"guard_duty": {"title": "Guard Duty", "giver": "warrior", "desc": "Defeat 6 Ruin Guards.", "type": "kill", "target": "guard", "count": 6, "reward": {"skill_point": 1}},
	"cinder_cleanup": {"title": "Cinder Cleanup", "giver": "inventor", "desc": "Defeat 6 Ember Crawlers in the Emberforge.", "type": "kill", "target": "crawler", "count": 6, "reward": {"dust": 12}},
	"shrine_pilgrim": {"title": "Shrine Pilgrim", "giver": "scholar", "desc": "Rest at 5 different Starshrines.", "type": "shrines", "target": "", "count": 5, "reward": {"shards": 80}},
	"archers_bane": {"title": "Archer's Bane", "giver": "warrior", "desc": "Defeat 5 Crystal Archers.", "type": "kill", "target": "archer", "count": 5, "reward": {"shards": 90}},
	"thorn_hunt": {"title": "Thorn in the Side", "giver": "merchant", "desc": "Defeat 4 Thorn Stalkers.", "type": "kill", "target": "stalker", "count": 4, "reward": {"dust": 10, "shards": 40}},
	"skybound_scrap": {"title": "Skybound Scrap", "giver": "inventor", "desc": "Defeat 5 Clockwork Drones.", "type": "kill", "target": "drone", "count": 5, "reward": {"dust": 14}},
	"frozen_court": {"title": "The Frozen Court", "giver": "warrior", "desc": "Defeat 3 Frost Knights.", "type": "kill", "target": "knight", "count": 3, "reward": {"skill_point": 1}},
	"wraith_whispers": {"title": "Whispers in the Dark", "giver": "scholar", "desc": "Defeat 4 Eclipse Wraiths.", "type": "kill", "target": "wraith", "count": 4, "reward": {"shards": 150}},
	"shard_collector": {"title": "Collector's Pride", "giver": "merchant", "desc": "Collect 300 Star Shards in total.", "type": "shards", "target": "", "count": 300, "reward": {"heart": 1}},
	"giant_slayer": {"title": "Giant Slayer", "giver": "warrior", "desc": "Defeat 3 guardian bosses.", "type": "bosses", "target": "", "count": 3, "reward": {"skill_point": 2}},
}

const HINTS := {
	"meadows": ["Hold jump to leap higher; tap it for a short hop.", "Bridges that look broken may only need a running jump.", "Hit a glowing switch with your sword to wake it."],
	"ember": ["Lava burns but the Ember Charm helps. A bounce on a platform clears the river.", "Cracked walls hide treasure. Strike them to break through."],
	"observatory": ["Water slows your fall but not your thoughts. Swim up through the cracks.", "Turn the prisms (E) to steer the beam to the sun-seal."],
	"thornwild": ["Thorns bite hard. Learn their rhythm, then dash through the gap.", "Pressure plates open the root-gates. A pushable block works too."],
	"frostfall": ["Ice makes you slide. Plan your jump a little early.", "A frozen mechanism cannot hurt you. A Stasis Pulse (ability) stops them."],
	"clockwork": ["Stasis freezes platforms and crushers. Use it to cross the Abyss.", "Press the switches in the order of their numbers."],
	"eclipse": ["The architecture here is falling apart. Do not stand still.", "You are not alone in here. Trust the fragments."],
}


static func npc_line(id: String, i: int) -> String:
	var n: Dictionary = NPCS.get(id, {})
	if n.is_empty():
		return "..."
	if Game.completed or Game.bosses.size() >= 7:
		return str(n.get("after_boss", "..."))
	var lines: Array = n["lines"]
	return str(lines[i % lines.size()])
