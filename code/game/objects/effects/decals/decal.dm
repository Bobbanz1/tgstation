/obj/effect/decal
	name = "decal"
	plane = FLOOR_PLANE
	anchored = TRUE
	resistance_flags = FIRE_PROOF | UNACIDABLE | ACID_PROOF
	///Boolean on whether this decal can be placed inside of groundless turfs/walls. If FALSE, will runtime and delete if it happens.
	var/turf_loc_check = TRUE

/obj/effect/decal/Initialize(mapload)
	. = ..()
	if(turf_loc_check && NeverShouldHaveComeHere(loc))
#ifdef UNIT_TESTS
		stack_trace("[name] spawned in a bad turf ([loc]) at [AREACOORD(src)] in \the [get_area(src)]. Please remove it or set turf_loc_check to FALSE on the decal if intended.")
#else
		return INITIALIZE_HINT_QDEL
#endif
	var/static/list/loc_connections = list(
		COMSIG_TURF_CHANGE = PROC_REF(on_decal_move),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/effect/decal/blob_act(obj/structure/blob/B)
	if(B && B.loc == loc)
		qdel(src)

/obj/effect/decal/proc/NeverShouldHaveComeHere(turf/T)
	return isclosedturf(T) || (isgroundlessturf(T) && !SSmapping.get_turf_below(T))

/obj/effect/decal/ex_act(severity, target)
	qdel(src)
	return TRUE

/obj/effect/decal/fire_act(exposed_temperature, exposed_volume)
	if(!(resistance_flags & FIRE_PROOF)) //non fire proof decal or being burned by lava
		qdel(src)

/obj/effect/decal/proc/on_decal_move(turf/changed, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(src, PROC_REF(sanity_check_self))

/obj/effect/decal/proc/sanity_check_self(turf/changed)
	if(changed == loc && NeverShouldHaveComeHere(changed))
		qdel(src)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/effect/turf_decal
	icon = 'icons/turf/decals.dmi'
	icon_state = "warningline"
	plane = FLOOR_PLANE
	layer = TURF_DECAL_LAYER
	anchored = TRUE
	/// Does this decal change colors on holidays
	var/use_holiday_colors = FALSE
	/// The pattern used when recoloring the decal
	var/pattern = PATTERN_DEFAULT

// This is with the intent of optimizing mapload
// See spawners for more details since we use the same pattern
// Basically rather then creating and deleting ourselves, why not just do the bare minimum?
/obj/effect/turf_decal/Initialize(mapload)
	SHOULD_CALL_PARENT(FALSE)
	if(flags_1 & INITIALIZED_1)
		stack_trace("Warning: [src]([type]) initialized multiple times!")
	flags_1 |= INITIALIZED_1

	// If the tile uses holiday colors, apply them here
	if(use_holiday_colors)
		var/current_holiday_color = request_holiday_colors(src, pattern)
		if(current_holiday_color)
			color = current_holiday_color
			alpha = DECAL_ALPHA

	var/turf/T = loc
	if(!istype(T)) //you know this will happen somehow
		CRASH("Turf decal initialized in an object/nullspace")
	T.AddElement(/datum/element/decal, icon, icon_state, dir, null, layer, alpha, color, null, FALSE, null)
	return INITIALIZE_HINT_QDEL

/obj/effect/turf_decal/Destroy(force)
	SHOULD_CALL_PARENT(FALSE)
#ifdef UNIT_TESTS
// If we don't do this, turf decals will end up stacking up on a tile, and break the overlay limit
// I hate it too bestie
	if(GLOB.running_create_and_destroy)
		var/turf/T = loc
		T.RemoveElement(/datum/element/decal, icon, icon_state, dir, null, layer, alpha, color, null, FALSE, null)
#endif
	// Intentionally used over moveToNullspace(), which calls doMove(), which fires
	// off an enormous amount of procs, signals, etc, that this temporary effect object
	// never needs or affects.
	loc = null
	return QDEL_HINT_QUEUE
