extends Button

@export var ENTER_TEXT: String = "ENTER ORCHESTRATION"
@export var EXIT_TEXT: String = "EXIT ORCHESTRATION"

func _ready() -> void:
	self.text = ENTER_TEXT
	self.pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	print(%LKGBridgeNode.is_inside_of_orchestration())
	if !%LKGBridgeNode.is_inside_of_orchestration():
		if %LKGBridgeNode.enter_orchestration():
			self.disabled = true
			var result = await %LKGBridgeNode.try_enter_orchestration
			self.disabled = false
			if result == true:
				self.text = EXIT_TEXT
			%RichTextLabel.text += "\n[color=green]ENTER[/color] to orchestration."
	else:
		if %LKGBridgeNode.exit_orchestration():
			self.disabled = true
			await %LKGBridgeNode.exited_orchestration
			self.text = ENTER_TEXT
			self.disabled = false
			%RichTextLabel.text += "\n[color=red]EXIT[/color] from orchestration."
