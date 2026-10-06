# HUD rework report (ui-programmer)

Branch worktree-agent-a8e641b90cfd2ad61 (fast-forwarded to claude/ecstatic-gauss-f495v8 first: the worktree base lacked design/ and godot/).

## Delivered (design/ux/hud.md)
- Top bar: flat BAR, flag + nation (Cinzel) + date + gold/manpower/moves/diplomacy chips with signed triangle deltas (true minus), tooltips with breakdowns, tap = pinned popover; wars/infamy chips only when relevant; tap nation = realm sheet; collapse order from measured widths; portrait = flag + 4 chips + overflow.
- Dock/lens: flat 40 px icon buttons on a rail (3 px brass bar, heavier icon when active, Advice badge), 4 primary screens + More; SHORT = menu button; PORTRAIT = bottom bar. Lens: 4 pinned + More + legend.
- Alert ticker (alert_ticker.gd): priority chips (3 + "+n" desktop, 1 + pill elsewhere), classes war/revolt/offer/event/supply, shape code, state-based, tap = look at cause, inline offer answers, dismiss for turn, drawer with message feed. Toasts = one info row; end-of-turn lines = one Turn-report chip; all mirrored to hud.feed.
- End Turn plate: idle / hint / busy / waiting / hot-seat (Pass to Pn, End round) / game over; hot-seat strip; opaque curtain unchanged.
- Layouts: DESKTOP / PHONE_L / SHORT / PORTRAIT from logical viewport; hud.keepouts().

## API
- TBAdvisor.alerts() entries gain n, ps; new ids war_declared, attrition; helpers ticker(), class_of(), breakdown(), mp_cap/mp_gain/dp_cap/dp_gain.
- HUD signals goto_province, nation_pressed, offer_answered, event_requested; vars input_blocked_fn, mp_waiting_fn, confirm_mode, tts_mode, feed; set_text_scale(); report_line()/report_flush().
- main.gd: _update_ui_scale uses px-per-unit (_px_per_unit; env TB_UI_SCALE, TB_SAFE=l,t,r,b for tests); _flush_log feeds the Turn report.
- Harness: godot/tests/hud_shots.sh <outdir> [lang].

## Not done
- Settings UI (confirm mode, text scale, tts, handedness); Annals does not display hud.feed yet.
- revolt/supply glyphs fall back to TBGlyph circle until the foundation kit merges; own plate drawing used instead of TBFrame.plate/bar/seal.
- Text scale >125% only collapses (no second bar row).
