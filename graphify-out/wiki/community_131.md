# Community 131: to_gradient_data()

**Members:** 9

## Nodes

- **apply_alpha_to_color()** (`apps_client_rust_src_render_generate_rs_apply_alpha_to_color`, Function, degree: 10)
- **apply_alpha_to_color_works()** (`apps_client_rust_src_render_generate_rs_apply_alpha_to_color_works`, Function, degree: 2)
- **combined_alpha()** (`apps_client_rust_src_render_generate_rs_combined_alpha`, Function, degree: 6)
- **emit_fill()** (`apps_client_rust_src_render_generate_rs_emit_fill`, Function, degree: 6)
- **emit_fill_for_oval()** (`apps_client_rust_src_render_generate_rs_emit_fill_for_oval`, Function, degree: 5)
- **emit_fill_for_rrect()** (`apps_client_rust_src_render_generate_rs_emit_fill_for_rrect`, Function, degree: 5)
- **emit_text_commands()** (`apps_client_rust_src_render_generate_rs_emit_text_commands`, Function, degree: 5)
- **first_visible_fill_color()** (`apps_client_rust_src_render_generate_rs_first_visible_fill_color`, Function, degree: 2)
- **to_gradient_data()** (`apps_client_rust_src_render_generate_rs_to_gradient_data`, Function, degree: 4)

## Relationships

- apps_client_rust_src_render_generate_rs_emit_text_commands → apps_client_rust_src_render_generate_rs_combined_alpha (calls)
- apps_client_rust_src_render_generate_rs_emit_text_commands → apps_client_rust_src_render_generate_rs_apply_alpha_to_color (calls)
- apps_client_rust_src_render_generate_rs_emit_text_commands → apps_client_rust_src_render_generate_rs_first_visible_fill_color (calls)
- apps_client_rust_src_render_generate_rs_emit_fill → apps_client_rust_src_render_generate_rs_emit_fill_for_oval (calls)
- apps_client_rust_src_render_generate_rs_emit_fill → apps_client_rust_src_render_generate_rs_combined_alpha (calls)
- apps_client_rust_src_render_generate_rs_emit_fill → apps_client_rust_src_render_generate_rs_apply_alpha_to_color (calls)
- apps_client_rust_src_render_generate_rs_emit_fill → apps_client_rust_src_render_generate_rs_emit_fill_for_rrect (calls)
- apps_client_rust_src_render_generate_rs_emit_fill_for_rrect → apps_client_rust_src_render_generate_rs_to_gradient_data (calls)
- apps_client_rust_src_render_generate_rs_emit_fill_for_rrect → apps_client_rust_src_render_generate_rs_combined_alpha (calls)
- apps_client_rust_src_render_generate_rs_emit_fill_for_rrect → apps_client_rust_src_render_generate_rs_apply_alpha_to_color (calls)
- apps_client_rust_src_render_generate_rs_emit_fill_for_oval → apps_client_rust_src_render_generate_rs_to_gradient_data (calls)
- apps_client_rust_src_render_generate_rs_emit_fill_for_oval → apps_client_rust_src_render_generate_rs_combined_alpha (calls)
- apps_client_rust_src_render_generate_rs_emit_fill_for_oval → apps_client_rust_src_render_generate_rs_apply_alpha_to_color (calls)
- apps_client_rust_src_render_generate_rs_to_gradient_data → apps_client_rust_src_render_generate_rs_apply_alpha_to_color (calls)
- apps_client_rust_src_render_generate_rs_apply_alpha_to_color_works → apps_client_rust_src_render_generate_rs_apply_alpha_to_color (calls)

