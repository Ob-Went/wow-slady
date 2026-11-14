local _, ns = ...

ns.CONFIG = {
	title = "Slady",
	color = "ffe0704d",
	sv = "SladyDB",
	data = { "trails" },
	defaults = { record = true },
	slash = { "/slady", "/trails" },
	slashKey = "SLADY",
	commands = { zapis = "record", record = "record" },
	locales = {
		pl = {
			record = "Zapisywanie śladów: %s",
			stats = "Odwiedzone miejsca: %d na %d mapach",
			help = {
				"Ślady zapisują się same, gdy chodzisz (bez lotów taksówką).",
				"/slady pokaz  - pokaż/ukryj ślady na mapie",
				"/slady zapis  - wstrzymaj/wznów zapisywanie",
				"/slady stat  - statystyki",
				"/slady wyczysc tak  - usuń ślady z obecnej strefy",
				"/slady reset tak  - usuń wszystkie ślady",
				"/slady jezyk en  - English",
			},
		},
		en = {
			record = "Recording trails: %s",
			stats = "Visited spots: %d on %d maps",
			help = {
				"Trails are recorded automatically as you move (flight paths are skipped).",
				"/slady show  - show/hide trails on the map",
				"/slady record  - pause/resume recording",
				"/slady stats  - statistics",
				"/slady clear yes  - delete trails in the current zone",
				"/slady reset yes  - delete all trails",
				"/slady lang pl  - Polski",
			},
		},
	},
}
