class_name AttackQuery
extends RefCounted
## Physics shape queries used by melee swings, explosions and other area effects.
## Call from _physics_process so the physics space is valid.

static func overlapping(from: Node2D, shape: Shape2D, xform: Transform2D, mask: int, exclude: Object = null) -> Array:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = xform
	params.collision_mask = mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var results: Array = from.get_world_2d().direct_space_state.intersect_shape(params, 32)
	var bodies: Array = []
	for result in results:
		var body: Object = result.collider
		if body == null or body == exclude or body in bodies:
			continue
		bodies.append(body)
	return bodies
