extends SceneTree
## Run: Godot --headless --path . --script res://tests/round_loop_test.gd

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var run_state = game.get_node("UI/DayHUD")
	var shop = game.get_node("UI/UpgradeStore")
	var boat = game.get_node("Paat")
	var fish = game.get_node("FishSchool")
	var typing = game.get_node("UI/FishingMinigame")
	check(shop.visible and not run_state.is_fishing(), "Run starts at dock")
	check(run_state.quota == 50 and shop.coins == 37, "Initial quota and gold")
	var initial_x: float = boat.boat_x
	Input.action_press("ui_left")
	boat._process(1.0)
	Input.action_release("ui_left")
	check(boat.boat_x == initial_x, "Dock blocks movement")
	shop.purchase(shop.ITEMS[1])
	check(shop.coins == 22 and boat.speed == 52.0, "Dock purchase applies equipment")
	run_state.start_round()
	check(run_state.is_fishing() and not shop.visible, "Depart starts fishing")
	check(fish.school.size() == fish.fish_count, "Lake population ready")
	var coins_before: int = shop.coins
	# Catch through the actual boat -> fish school -> run path.
	boat.target_fish = fish.school[0]["sprite"]
	boat._on_fish_caught()
	check(run_state.catch_value == 25 and run_state.bucket_count == 1, "Catch goes into round bucket")
	check(shop.coins == coins_before, "Catch does not immediately award spendable gold")
	run_state.go_to_dock()
	check(run_state.is_fishing() and boat.boat_x < boat.max_x, "Under-quota return rejected with pushback")
	check(run_state.message_label.text.contains("Not enough fish"), "Kraken explains rejection")
	# Old gold cannot satisfy a quota; only the round catch does.
	shop.award_coins(100)
	run_state.go_to_dock()
	check(run_state.is_fishing(), "Old gold does not count toward quota")
	run_state.record_catch(30)
	run_state.go_to_dock()
	check(shop.visible and run_state.rounds_survived == 1, "Quota return completes round")
	check(shop.coins == coins_before + 155, "Sale awards full catch including surplus")
	check(run_state.catch_value == 0 and run_state.bucket_count == 0, "Selling empties bucket")
	check(run_state.quota == 75 and run_state.time_remaining == 125.0, "Next round scales quota and time")
	var sold_coins: int = shop.coins
	run_state.complete_round()
	check(shop.coins == sold_coins, "Repeated transition cannot sell twice")
	run_state.start_round()
	check(fish.school.size() == fish.fish_count and boat.speed == 52.0, "Fish replenish and upgrades persist")
	run_state.record_catch(75)
	boat.start_cast()
	run_state.time_remaining = 0.01
	run_state._process(0.02)
	check(shop.visible and run_state.rounds_survived == 2, "Qualified timeout automatically sells")
	check(not boat.cast_tween.is_running() and boat.state == boat.State.IDLE, "Transition cancels active cast")
	run_state.start_round()
	typing.start_game(fish.school[0]["sprite"])
	boat.state = boat.State.MINIGAME
	run_state.time_remaining = 1.0
	run_state._process(0.5)
	check(run_state.time_remaining == 0.5, "Round clock runs during typing")
	run_state._process(0.6)
	check(run_state.phase == run_state.Phase.GAME_OVER and not shop.visible, "Below-quota timeout ends run")
	check(not typing.active and not typing.visible, "Loss cancels typing challenge")
	var losing_value: int = run_state.catch_value
	run_state.record_catch(999)
	check(run_state.catch_value == losing_value, "Late catch cannot alter game-over result")
	run_state.restart_run()
	await process_frame
	await process_frame
	game = current_scene
	run_state = game.get_node("UI/DayHUD")
	shop = game.get_node("UI/UpgradeStore")
	boat = game.get_node("Paat")
	check(shop.visible and run_state.rounds_survived == 0 and run_state.quota == 50, "Retry resets round progression")
	check(shop.coins == 37 and boat.speed == 40.0 and shop.levels["Quick Reel"] == 0, "Retry resets gold and upgrades")
	print("Round loop failures: ", failures)
	quit(0 if failures == 0 else 1)
