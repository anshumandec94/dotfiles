# Known Issues

A running list of upstream / environmental issues we've hit while
configuring Spacemacs, with workaround status and how to recheck.

---

## Subprocess output freezes until keypress (NS Emacs on macOS)

**First seen:** 2026-05-23, while wiring up `cursor-agent` in vterm.

**Symptom:** In any buffer attached to a long-running subprocess
(vterm/cursor-agent, copilot-chat, comint REPLs, async shell), output
streams in chunky bursts that only appear after a key is pressed. The
process is genuinely running; only the *display* is stuck.

**Root cause:** Open Emacs bug in `ns_select` / `wait_reading_process_output`.
On macOS Apple Silicon, the integration between `NSApplication`'s run
loop and `pselect` on subprocess fds is fragile, so during idle the fd
poll doesn't reliably fire and process filters never get called.

- Bug threads (track these):
  - [bug#78946](https://mail.gnu.org/archive/html/bug-gnu-emacs/2025-07/msg00087.html) — `accept-process-output` not allowed in threads on macOS
  - [bug#75275](https://lists.libreplanet.org/archive/html/bug-gnu-emacs/2025-01/msg00097.html) — `make-thread` / `ns_select` analysis
- vterm community echo:
  - [emacs-libvterm #555](https://github.com/akermu/emacs-libvterm/issues/555) — vterm only redraws on input
  - [emacs-libvterm #605](https://github.com/akermu/emacs-libvterm/issues/605) — `vterm-timer-delay nil` workaround

**What we tried (in `config-perf.el` / `config-cursor.el`) and kept:**

- `(setq process-adaptive-read-buffering nil)` — well-documented, no
  downside; reduces but doesn't eliminate the lag.
- `(setq read-process-output-max (* 1024 1024))` — 1 MB; values >1 MB
  reportedly backfire on macOS.
- `(setq vterm-timer-delay nil)` — bypasses vterm's broken timer-redraw
  path. Helps in *some* idle scenarios but not the underlying NS bug.

**What we tried and rolled back:**

- Periodic `(redisplay)` timer — wrong fix, made vterm output choppier
  by racing with vterm's own redraw cycle.
- Aggressively low `vterm-timer-delay` (0.01s) — still in the timer
  path, same bug.
- `read-process-output-max` at 4 MB — too high on macOS.

**Workaround NOT yet applied (the next thing to try):**

A 0.1s timer that calls `(accept-process-output nil 0 10)` whenever a
visible window holds a buffer with a live subprocess. This forces the
fd poll that `ns_select` is failing to schedule. Same idea as the
rolled-back redisplay timer but using I/O instead of display, which is
the level the bug actually lives at.

**How to recheck "has the bug been fixed?":**

1. Look at bug#78946 status on `mail.gnu.org` / `debbugs.gnu.org`. If
   marked fixed, find the merge commit.
2. Verify your Emacs version includes the fix:
   ```sh
   emacs --version
   # then look at the commit log for ns.m / nsterm.m / process.c
   ```
3. Quick reproduction test (no setup needed):
   - Open GUI Emacs, `M-x shell` (or vterm).
   - Run `for i in $(seq 1 20); do echo $i; sleep 0.5; done`.
   - If numbers appear smoothly without any keypress, bug is fixed.
   - If they only appear after you press a key, bug is still there.

**Escape hatch if upstream takes forever:**

Switch to `emacs-mac` (Mitsuharu Yamamoto's port) or `emacs-plus`. They
have different NS event-loop integration and are widely reported to
handle subprocess streaming smoothly. Bigger commitment, may have
their own quirks with Spacemacs layers.
