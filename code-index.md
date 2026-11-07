# ดัชนีฟังก์ชันของทุกสคริปต์

| ไฟล์ | ฟังก์ชัน |
| --- | --- |
| adventure_backdrop.gd | _ready, _refresh_region, _process, _notification, _current_wave, _draw, _draw_gradient, _draw_stars, _draw_arcane_ring, _draw_forest, _draw_floating_castle, _draw_castle, _draw_crystal_cave, _draw_dragon_cavern, _draw_astral_ruins, _draw_vignette |
| arena.gd | _ready, _process, _notification, _draw, _draw_sky, _draw_ridge, _draw_sigil, _draw_brazier, _draw_embers, _draw_vignette |
| atom.gd | _ready, set_symbol, _draw, _gui_input, flash, shake |
| attack_styles.gd | profile, label |
| audio.gd | _ready, _ensure_buses, set_music_volume, set_sfx_volume, _apply_bus, save_settings, load_settings, play, play_music, stop_music, _osc, _render, _to_stream, _buffer, _hz, _build_sfx, _sfx_click, _sfx_pickup, _sfx_buy, _sfx_bond, _sfx_reject, _sfx_hit, _sfx_crit, _sfx_victory, _sfx_defeat, _build_tracks, _track_home, _track_shop, _track_battle, _input |
| battle.gd | _ready, _start_wave, _build_trait_bar, _announce_synergies, _spawn_players, _make_fighter, _make_chip, _refresh_chip_tooltip, _spawn_monster, _update_monster_label, _effect_badge, _sources_tip, _refresh_status, _status_snapshot, _unhandled_input, _above, _alive_players, _alive_in_row, _on_tick, _should_animate, _resolve_round, _build_round_queue, _turn_order_less, _effective_speed_tier, _position_rank, _turn_control, _fighter_portrait, _play_turn_beat, _combat_speed, _wait_combat, _refresh_turn_queue_ui, _pick_monster_target, _apply_base_heal, _apply_boss_skill, _try_cast_unit_ability, _announce_unit_ability, _skill_feedback, _reveal_fighter, _fighter_point, _weakest_ally, _highest_atk_ally, _longest_cooldown_ally, _give_shield, _heal_fighter, _set_guard, _cleanse, _set_timed_source, _stack_source, _set_dot, _source_total, _tick_unit_effects, _tick_source_dictionary, _attack, _record_damage, _damage_monster, _tick_down_statuses, _resolve_deaths, _finish, _report_leader, _build_result_report, _on_next_wave_pressed, _shop_destination, _on_shop_pressed, _show_reward, _log, _defeat_reason, _gain_energy, _refresh_actions, _spend, _on_catalyse_pressed, _on_heal_pressed, _on_burst_pressed, _on_speed_pressed, _apply_speed, _on_battle_coach_skip |
| battle_status.gd | _ready, show_state |
| board.gd | _draw, _draw_sell_wedge, _notification |
| bond_anim.gd | _ready, play, skip, _on_done, _exit_tree, _draw, _draw_ionic, _draw_covalent, _draw_metallic, _draw_charge, _unhandled_input, _draw_lesson, ionic_endpoints |
| boss_rewards.gd | bonus, trait_bonus, roll |
| campaign.gd | is_boss, enemy, migrate_stage |
| combat_timing.gd |  |
| compound_art.gd | setup, _process, play_pose, set_attack_phase, _update_pose_frame, _poly, _orb, _draw, _draw_sprite |
| enemy_attacks.gd | profile |
| event.gd | _ready, _clear_cards, _render, _render_routes, _render_story, _choose, _render_boss, _render_combat, _add_action, _read_click, _read_next, _skip, _on_continue_pressed, _launch_battle, _navigate, _event_texture, _narrative_texture, _unhandled_key_input |
| event_icon.gd | _ready, _block, _draw |
| event_scene_art.gd | _ready, block, _draw |
| events.gd | is_trigger_wave, is_choice_wave, pick_choice_cards, pick_forced_event, apply |
| expedition.gd | _catalog, fresh, sanitize, choice, ensure, select, available, blocked_reason, choices, eligible, build_plan, future_text, grant_buff, resolve, enemy, battle_reward, advance, enter, retreat, followup |
| forest_events.gd |  |
| fx.gd | skill_link, float_text, burst, punch, centre_of, strike_streak |
| fx_burst.gd | setup, _process, _draw |
| fx_combat_motion.gd | setup, _process, _pixel, _draw, _draw_ultimate |
| fx_floating_label.gd | setup |
| fx_skill.gd | setup, _process, _draw |
| fx_strike.gd | setup, _process, _draw |
| game_state.gd | _pick_save_path, pin_recipe, _ready, add_gold, spend_gold, lose_gold, add_to_roster, set_row, formulas_in_row, interest_earned, roll_shop, _opening_offer, _random_offer, set_tutorial_done, set_battle_tutorial_done, mark_discovered, set_board_items, clear_roster, reset_progress, complete_run, end_run_in_defeat, save_game, load_game, _sanitize_board_items, _sanitize_discovered, _sanitize_roster, roll_next_monster, consume_from_roster, sell_compound, is_final_wave, is_boss_wave, clear_run_rewards, grant_boss_reward, choose_boss_reward, trait_bonus, encounter_enemy, field_limit, slot_price, buy_field_slot, fielded_formulas, fielded_roster |
| home.gd | _ready, _refresh_continue, _animate_in, _on_new_pressed, _on_continue_pressed, _on_settings_pressed, _on_quit_pressed |
| home_background.gd | _ready, _process, _centre_fade, _draw |
| hp_vessel.gd | _ready, _process, _draw, _draw_pill, _draw_pill_outline |
| main.gd | _rebuild_shop, _on_reroll_pressed, _build_shop_button, _chip_line, _paint_shop_button, _paint_button_tier, _style_button_tiers, _ready, _unhandled_input, _shop_cost, _on_shop_button_pressed, _on_atom_drag_started, _on_atom_drag_ended, _resolve_cluster, _get_cluster, _bond_cluster, _spawn_molecule, _on_molecule_drag_started, _on_molecule_drag_ended, _reject_cluster, _reveal_recipe, _recipe_placeholder, _tier2_placeholder, _reveal_tier2, _refresh_recipe_title, _clamp_point, _clamp_to_board, _on_clear_pressed, _on_battle_button_pressed, _on_gold_changed, _refresh_gold, _refresh_battle_button, _on_roster_changed, _refresh_team_title, _refresh_synergy_panel, _open_trait, _resume_reward, _muted_label, show_status, _refresh_next_monster, _refresh_slot_button, _on_buy_slot_pressed, _zone_at, _zone_container, _place_in_zone, _repack_row, _gather_tiles_into_zone, _settle_into_row, _apply_zone_drop, _make_atom_tile, _make_molecule_tile, _connect_board_persistence, _on_board_children_changed, _queue_persist, _persist_board, _restore_board, _seed_opening_board, _refresh_board_hint, _celebrate_recipe, _why_no_reaction, _intent, _why_blocked, _part_name, _refresh_preview, _unlight, _clear_preview, _process, _set_drag_visuals, _toggle_book, _close_book, _toggle_shop, _close_shop, _refresh_recipe_strip, _refund_for, _on_atom_sell_requested, _in_sell_zone, _try_sell_drop, _on_molecule_sell_requested, _offer_sale, _on_sell_confirmed, _on_sell_canceled, _inspect_atom |
| molecule.gd | setup, pop_in, flash, shake, _gui_input |
| monster_art.gd | _ready, _process, hit, _px, _draw |
| playtest.gd | _ready, begin, event_selected, skipped, battle_finished, _save, _publish |
| preparation_plan.gd | recipe_for, requirements, synergy_change |
| preparation_ui.gd | setup, _label, _button, _make_details, _sell_selected, show_unit, close_details, _refresh_details, _plan_selected, pin, _wire_book, refresh, preview_drop, clear_drop_preview, _process |
| recipes.gd | find_tier2, is_tier2_product, stack_hp_multiplier, stack_atk_multiplier, make_key, is_metal, bond_type, bond_lesson, is_noble, valence_of, shell_is_full, atoms_of, match_cluster, _match_whole, nearest_reaction, _tally, find_recipe, cost_of, beats, traits_of, traits_of_recipe, find_by_formula, counter_of, sell_value, reason_beats |
| region_banner.gd | _ready, _process, _refresh |
| regional_events.gd |  |
| reward_panel.gd | _ready |
| risk_nodes.gd |  |
| run_flow.gd | begin, condition, record, heal, hurt, recover, needs_heal, buy_heal, skip |
| run_risk.gd | sanitize, add, value, finish_battle, summary |
| settings_panel.gd | _ready, open, close, _on_menu_pressed, _unhandled_input, _on_music_changed, _on_sfx_changed, _refresh_labels, _on_reset_pressed, _disarm_reset |
| trait_details.gd | setup, _ready |
| traits.gd | speed_tier, boss_skill, boss_skill_text, trait_counts, active_tiers, tier_for_count, value, next_threshold, thresholds_text, label_of, color_of, active_text, _entry_traits |
| transition.gd | _ready, change_scene, fade_out_and_quit |
| tutorial.gd | _ready, _process, _atoms_on_board, _derive_step, _refresh, _on_skip, finish, _draw, _dragging |
| ui_adaptive.gd | _input, _ready, _added, _process, refresh_scene, _event, _main, _nav, _battle, _fit_popups |
| ui_polish.gd | _ready, _style_tree, _queue_style, _style, _tap_info, highlight, _button_motion |
| ui_tokens.gd |  |
| unit_abilities.gd | combat_stats, skill_of, role_label, row_label, stat_multiplier, stat_text, tooltip |
| unit_condition_bar.gd | _ready, _process, _draw |
| worlds.gd | region_index_for_wave, region_for_wave, wave_in_region, journey_label |
