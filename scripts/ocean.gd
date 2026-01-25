extends Node3D

# References to the two platform tiles
@export var tile1: MeshInstance3D
@export var tile2: MeshInstance3D

# Movement speed
@export var scroll_speed: float = 5.0

# The length of each tile (adjust based on your mesh size)
@export var tile_length: float = 10.0

# Water bobbing effect
@export var bob_height: float = 0.2  # How high the bob goes
@export var bob_speed: float = 2.0   # How fast it bobs

# Rotation effect
@export var tilt_amount: float = 0.05  # How much to tilt (in radians)
@export var tilt_speed: float = 1.5    # Speed of tilting

# Randomness
@export var randomness: float = 0.3  # How much random variation to add

# Time tracker for sine wave
var time: float = 0.0

# Base Y positions
var tile1_base_y: float = 0.0
var tile2_base_y: float = 0.0

# Noise for randomness (shared between both tiles)
var noise = FastNoiseLite.new()
var noise_offset: float = 0.0

func _ready():
	# Position the tiles in a line
	# Assuming tiles move along the Z axis
	tile1.position = Vector3(0, 0, 0)
	tile2.position = Vector3(0, 0, tile_length)
	
	# Store base Y positions
	tile1_base_y = tile1.position.y
	tile2_base_y = tile2.position.y
	
	# Setup noise for randomness
	noise.seed = randi()
	noise.frequency = 0.5
	
	# Single shared noise offset
	noise_offset = randf() * 100.0

func _process(delta):
	time += delta
	
	# Base sine wave motion (SHARED)
	var bob_base = sin(time * bob_speed) * bob_height
	var tilt_base = sin(time * tilt_speed) * tilt_amount
	
	# Add random noise to the motion (SHARED)
	var bob_noise = noise.get_noise_1d(time + noise_offset) * bob_height * randomness
	var tilt_noise = noise.get_noise_1d(time * 0.7 + noise_offset) * tilt_amount * randomness
	
	# Combine base motion with random variation (SHARED)
	var bob = bob_base + bob_noise
	var tilt = tilt_base + tilt_noise
	
	# Move both tiles backward (creating forward movement illusion)
	tile1.position.z -= scroll_speed * delta
	tile2.position.z -= scroll_speed * delta
	
	# Apply SAME bobbing effect to both tiles
	tile1.position.y = tile1_base_y + bob
	tile2.position.y = tile2_base_y + bob
	
	# Apply SAME rotation (tilt around Z axis) to both tiles
	tile1.rotation.z = tilt
	tile2.rotation.z = tilt
	
	# Check if tile1 has moved too far back
	if tile1.position.z < -tile_length:
		# Move it ahead of tile2
		tile1.position.z = tile2.position.z + tile_length
	
	# Check if tile2 has moved too far back
	if tile2.position.z < -tile_length:
		# Move it ahead of tile1
		tile2.position.z = tile1.position.z + tile_length
