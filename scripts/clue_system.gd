class_name ClueSystem
extends RefCounted
## Seeded evidence placement.
## - Same run seed + same night + same set of already-found clues => same layout.
## - Every unfound CORE clue whose night has come is always placed (carry-over), so a
##   missed clue can never make the mystery unsolvable.
## - Optional clues (misleading / corroborating) are drawn randomly each night.
## - Spot choice, type compatibility and reveal time (discovery order) are randomized.


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## spots: Array of {id, cam, kind, pos, yaw, wall_normal}
## returns Array of {id, spot (Dictionary), reveal_hour (float)}
static func plan(run_seed: int, night: int, found: Array, spots: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("greyfang:%d:%d" % [run_seed, night])
	var ids: Array = StoryData.CLUES.keys()
	ids.sort()
	var core := []
	var opt := []
	for id in ids:
		var c: Dictionary = StoryData.CLUES[id]
		if c.type == "memory" or found.has(id) or int(c.night) > night:
			continue
		if c.core:
			core.append(id)
		else:
			opt.append(id)
	_shuffle(core, rng)
	_shuffle(opt, rng)
	# prefer optional clues that belong to this night, then older ones
	opt.sort_custom(func(a, b): return int(StoryData.CLUES[a].night) > int(StoryData.CLUES[b].night))
	var n_opt: int = min(opt.size(), 2 + rng.randi_range(0, 1) + (1 if night >= 4 else 0))
	var chosen: Array = core.duplicate()
	for i in n_opt:
		chosen.append(opt[i])
	_shuffle(chosen, rng)

	var pool: Array = spots.duplicate()
	_shuffle(pool, rng)
	var used_cams := {}
	var out := []
	for id in chosen:
		var c: Dictionary = StoryData.CLUES[id]
		var pick = null
		# pass 0: avoid stacking two clues on one camera; pass 1: allow it
		for pass_i in 2:
			for s in pool:
				if s.get("_used", false):
					continue
				if not c.place.has(s.kind):
					continue
				if pass_i == 0 and used_cams.get(s.cam, 0) >= 1:
					continue
				pick = s
				break
			if pick != null:
				break
		if pick == null:
			continue
		pick["_used"] = true
		used_cams[pick.cam] = used_cams.get(pick.cam, 0) + 1
		var reveal: float
		if c.core:
			reveal = rng.randf_range(0.0, 3.0)   # core evidence is always out by 03:00
		else:
			reveal = rng.randf_range(0.0, 4.5)
		out.append({"id": id, "spot": pick, "reveal_hour": reveal})
	for s in pool:
		s.erase("_used")
	return out


## Golden Grayson encounter schedule for a night (runtime RNG, not story-critical
## except night 5, where one memory encounter per missing fragment is guaranteed).
static func golden_schedule(night: int, found: Array, rng: RandomNumberGenerator) -> Array:
	var ev := []
	if night < 2:
		return ev
	var mem_avail := []
	for id in ["m_gold_1", "m_gold_2", "m_gold_3"]:
		if not found.has(id) and int(StoryData.CLUES[id].night) <= night:
			mem_avail.append(id)
	if night == 5:
		var t := rng.randf_range(1.5, 2.2)
		for id in mem_avail:
			ev.append({"hour": t, "kind": "memory", "memory": id})
			t += rng.randf_range(0.9, 1.3)
	else:
		var chance: float = {2: 0.35, 3: 0.55, 4: 0.65}.get(night, 0.4)
		if rng.randf() < chance:
			var mem: String = mem_avail[0] if mem_avail.size() > 0 and night >= 3 else ""
			ev.append({"hour": rng.randf_range(1.0, 4.5), "kind": "memory" if mem != "" else "sighting", "memory": mem})
	# harmless anomalies (stage glimpses / hallucinations)
	var n_anom := rng.randi_range(0, 1) + (1 if night >= 4 else 0)
	for i in n_anom:
		ev.append({"hour": rng.randf_range(0.5, 5.5), "kind": "anomaly", "memory": ""})
	return ev
