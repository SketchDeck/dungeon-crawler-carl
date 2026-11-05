class_name HitQuery
extends RefCounted
## Instant hitbox queries. Attacks check overlap on their active frame instead of
## keeping Area2D nodes alive, which keeps hit timing deterministic.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMIES := 4
## Non-enemy things player attacks can strike (switches, breakables).
const LAYER_HITTABLE := 8


static func box(ctx: Node2D, center: Vector2, size: Vector2, mask: int) -> Array[Node]:
	var shape := RectangleShape2D.new()
	shape.size = size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collision_mask = mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var found: Array[Node] = []
	for result: Dictionary in ctx.get_world_2d().direct_space_state.intersect_shape(params, 32):
		var collider: Object = result["collider"]
		if collider is Node and not found.has(collider):
			found.append(collider)
	return found
