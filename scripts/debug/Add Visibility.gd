extends StaticBody2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var texture = load("res://icon2.png");
	#var texture = ImageTexture.create_from_image(img);
	
	for child in self.get_children():
		var sprite = Sprite2D.new();
		sprite.texture = texture;
		child.add_child(sprite);
		sprite.scale = (child as CollisionShape2D).shape.get_rect().size / 128;
		
	pass # Replace with function body.
