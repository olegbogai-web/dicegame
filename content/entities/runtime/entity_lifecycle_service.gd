extends RefCounted
class_name EntityLifecycleService

signal entity_died(entity: Entity)
signal entity_revived(entity: Entity)
signal entity_hp_changed(entity: Entity, previous_hp: int, current_hp: int)


func apply_damage(entity: Entity, amount: int) -> int:
	if entity == null or amount <= 0:
		return 0
	return set_current_hp(entity, entity.current_hp - amount)


func heal(entity: Entity, amount: int) -> int:
	if entity == null or amount <= 0:
		return 0
	return set_current_hp(entity, entity.current_hp + amount)


func set_current_hp(entity: Entity, value: int) -> int:
	if entity == null:
		return 0

	var previous_hp := entity.current_hp
	var was_dead := entity.is_dead
	entity.set_current_hp(value)
	entity_hp_changed.emit(entity, previous_hp, entity.current_hp)

	if not was_dead and entity.is_dead:
		entity_died.emit(entity)
	elif was_dead and entity.is_alive():
		entity_revived.emit(entity)

	return entity.current_hp - previous_hp
