# План разгрузки `scenes/battle_table.gd`

Документ фиксирует **практическую последовательность** переноса существующих функций из `battle_table.gd` в специализированные модули.

Цель: оставить в `battle_table.gd` только lifecycle сцены и вызовы фасадов, чтобы переход от тестового боя к real run-time данным прошел без переписывания UI.

## Шаг 1. Перенести bootstrap и загрузку runtime-данных боя

**Новый файл:** `content/combat/presentation/battle_scene_bootstrap.gd`.

**Перенести функции:**
- `configure_from_battle_room`;
- `set_floor_textures`;
- `set_player_data`;
- `set_monsters`;
- `_ensure_battle_room_data`;
- `_initialize_battle_state`.

**Ответственность шага:**
- отделить создание/инициализацию `BattleRoom` от рендера;
- сделать единый вход для real game данных (run-state игрока, encounter runtime, фон комнаты).

## Шаг 2. Перенести отрисовку сцены боя и визуальные обновления

**Новый файл:** `content/combat/presentation/battle_scene_view_renderer.gd`.

**Перенести функции:**
- `_apply_room_data`, `_apply_floor_textures`, `_apply_player_sprite`, `_apply_monster_sprites`;
- `_apply_ability_frames`, `_apply_monster_ability_frames`, `_register_monster_ability_frame`;
- `_apply_player_artifacts`, `_spawn_artifact_icon`, `_clear_generated_artifact_icons`;
- `_apply_ability_icon`, `_apply_dice_places`, `_get_dice_place_nodes`;
- `_duplicate_sprite_template`, `_duplicate_frame_template`, `_clear_generated_nodes`;
- `_apply_health_bar`, `_resolve_health_bar`, `_update_health_bar_transform`, `_animate_health_bar`, `_update_health_bars`;
- `_apply_health_text`, `_apply_monster_health_text`;
- `_set_status_template_visible`, `_get_status_template`, `_clear_runtime_status_visuals`, `_apply_statuses_to_sprite`, `_refresh_status_visuals`;
- `_apply_texture_to_mesh`, `_build_centered_offsets`, `_set_mesh_tint`.

**Ответственность шага:**
- изолировать чистый presentation-слой;
- убрать из `battle_table` тяжелую поддержку HP/status/artifact UI.

## Шаг 3. Перенести player-input и работу со слотами способностей

**Новый файл:** `content/combat/presentation/player_ability_input_controller.gd`.

**Перенести функции:**
- `_refresh_player_ability_snap_state`, `_is_player_ability_frame_at_base`;
- `_register_player_ability_frame`, `_register_player_ability_slots`;
- `_find_player_ability_frame_at_screen_point`, `_select_player_ability`, `_cancel_selected_ability`, `_update_selected_ability_follow`;
- `_is_ability_state_ready`, `_collect_ready_dice_for_frame`;
- `_update_player_ability_visuals`, `_get_active_drag_dice`, `_should_highlight_slot_for_dice`;
- `_dice_matches_slot`, `_get_slot_target_position`.

**Ответственность шага:**
- отделить UX-логику игрока от battle lifecycle;
- упростить замену input flow (например, gamepad/мобильный тап).

## Шаг 4. Перенести таргетинг и hit-testing в отдельный сервис

**Новый файл:** `content/combat/presentation/battle_targeting_service.gd`.

**Перенести функции:**
- `_resolve_target_descriptor_at_screen_point`;
- `_resolve_activation_target_origin`;
- `_project_mouse_to_horizontal_plane`;
- `_screen_point_hits_mesh`;
- `_has_player_dice_at_screen_point`;
- `_project_mesh_screen_rect`.

**Ответственность шага:**
- централизовать правила выбора целей для игрока/монстров;
- сделать тестируемыми screen/world преобразования.

## Шаг 5. Перенести turn loop и броски кубов в runtime orchestrator

**Новый файл:** `content/combat/runtime/battle_turn_orchestrator.gd`.

**Перенести функции:**
- `_start_current_turn`;
- `_throw_current_turn_dice`;
- `_build_dice_throw_request`;
- `_clear_board_dice`;
- `_get_turn_dice`;
- `_are_current_monster_turn_dice_stopped`;
- `_advance_to_next_turn`;
- `_run_current_monster_turn`;
- `_on_end_turn_button_pressed`.

**Ответственность шага:**
- убрать управление turn lifecycle из scene-скрипта;
- переиспользовать runtime-цикл в других battle presentation слоях.

## Шаг 6. Перенести execution способности и post-battle награды

**Новые файлы:**
- `content/combat/runtime/battle_action_orchestrator.gd`;
- `content/combat/reward/post_battle_reward_flow.gd`.

**Перенести функции (action orchestration):**
- `_activate_selected_ability`;
- `_play_ability_use_visual`;
- `_build_dice_assignments_for_frame`;
- `_find_monster_ability_frame_state`;
- `_execute_monster_ability`;
- `_apply_combatant_views_after_ability_resolution`.

**Перенести функции (reward flow):**
- `_handle_post_battle_reward_dice`;
- `_try_resolve_post_battle_reward_dice_result`;
- `_find_post_battle_reward_die`;
- `_show_ability_reward_options`;
- `_build_ability_reward_options`;
- `_load_player_reward_abilities`;
- `_collect_owned_ability_ids`;
- `_roll_reward_rarity`;
- `_pick_ability_by_rarity_with_fallback`;
- `_compute_reward_card_spacing_x`;
- `_render_ability_reward_cards`;
- `_apply_reward_card_visual`;
- `_clear_ability_reward_cards`;
- `_resolve_ability_reward_click`;
- `_select_ability_reward`.

**Ответственность шага:**
- разделить боевое действие и наградной post-battle flow;
- исключить рост `battle_table.gd` при добавлении новых reward-механик.

---

## Итоговое состояние после шага 6

`scenes/battle_table.gd` содержит:
- ссылки на ноды сцены;
- маршрутизацию input/сигналов в контроллеры;
- обновление UI-надписей (`_update_turn_ui`, `_on_event_button_pressed`);
- вызовы сервисов bootstrap/render/input/targeting/turn/action/reward.

Таким образом экран боя остается стабильным при переходе от test room к real game runtime-данным.
