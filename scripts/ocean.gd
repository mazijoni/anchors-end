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

# Noise for randomness
var noise = FastNoiseLite.new()
var noise_offset1: float = 0.0
var noise_offset2: float = 0.0

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
	
	# Random starting offsets for each tile
	noise_offset1 = randf() * 100.0
	noise_offset2 = randf() * 100.0

func _process(delta):
	time += delta
	
	# Base sine wave motion
	var bob1_base = sin(time * bob_speed) * bob_height
	var bob2_base = sin(time * bob_speed + 1.5) * bob_height
	
	var tilt1_base = sin(time * tilt_speed) * tilt_amount
	var tilt2_base = sin(time * tilt_speed + 0.75) * tilt_amount
	
	# Add random noise to the motion
	var bob1_noise = noise.get_noise_1d(time + noise_offset1) * bob_height * randomness
	var bob2_noise = noise.get_noise_1d(time + noise_offset2) * bob_height * randomness
	
	var tilt1_noise = noise.get_noise_1d(time * 0.7 + noise_offset1) * tilt_amount * randomness
	var tilt2_noise = noise.get_noise_1d(time * 0.7 + noise_offset2) * tilt_amount * randomness
	
	# Combine base motion with random variation
	var bob1 = bob1_base + bob1_noise
	var bob2 = bob2_base + bob2_noise
	
	var tilt1 = tilt1_base + tilt1_noise
	var tilt2 = tilt2_base + tilt2_noise
	
	# Move both tiles backward (creating forward movement illusion)
	tile1.position.z -= scroll_speed * delta
	tile2.position.z -= scroll_speed * delta
	
	# Apply bobbing effect
	tile1.position.y = tile1_base_y + bob1
	tile2.position.y = tile2_base_y + bob2
	
	# Apply rotation (tilt around Z axis)
	tile1.rotation.z = tilt1
	tile2.rotation.z = tilt2
	
	# Check if tile1 has moved too far back
	if tile1.position.z < -tile_length:
		# Move it ahead of tile2
		tile1.position.z = tile2.position.z + tile_length
	
	# Check if tile2 has moved too far back
	if tile2.position.z < -tile_length:
		# Move it ahead of tile1
		tile2.position.z = tile1.position.z + tile_length
