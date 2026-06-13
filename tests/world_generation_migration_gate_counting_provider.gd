extends "res://scripts/chunk_provider.gd"

var private_legacy_call_count: int = 0


func _generate_legacy_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	private_legacy_call_count += 1
	return super._generate_legacy_chunk_generation_result(chunk_coord)
