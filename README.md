# Project Awake
A game project for a competition.

## Eye mechanic prototype
Press **Play** in the main menu to open the POV prototype. The screen is split
into left- and right-eye views, both starting closed. In either half, drag from
the upper half upward or the lower half downward to open that eye; drag in the
opposite direction to close it. The two eyes reveal adjacent parts of one
shared placeholder image, and each side develops a red tint as it dries.
Closing an eye clears its dryness immediately. Each eye exposes an `is_open()`
method and an `eye_open_state_changed` signal for gating gameplay interactions
while that eye is closed. Press **Escape** to return to the main menu.

The shared placeholder image is `background_placeholder.svg`. To use another
image, select the `Background` TextureRect in `Scene/main.tscn` and replace its
Texture in the Inspector.
