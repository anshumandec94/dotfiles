;;; config-perf.el --- Subprocess I/O performance tuning -*- lexical-binding: t; -*-

;;; Commentary:

;; Reduces latency between subprocess output and Emacs display. Affects
;; vterm (cursor-agent, terminals), copilot-chat, lsp servers, and any
;; other long-running subprocess.
;;
;; `process-adaptive-read-buffering' = t (the default) causes Emacs to
;; throttle reads from busy pipes; this is what causes vterm/copilot-chat
;; buffers to only refresh when you press a key.

;;; Code:

;; Disable adaptive read buffering -- biggest fix for the
;; "vterm/copilot-chat only refreshes when I press a key" symptom.
(setq process-adaptive-read-buffering nil)

;; Bump read-process-output-max to 4MB. Default in Emacs 30 is 64KB.
;; Larger buffer = fewer reads = lower per-flush overhead, especially
;; helpful for streaming AI agent output and LSP servers.
(setq read-process-output-max (* 4 1024 1024))

;; ---------------------------------------------------------------------------
;; Periodic redisplay tick for subprocess buffers
;; ---------------------------------------------------------------------------
;; Even with `process-adaptive-read-buffering' off, vterm and other
;; subprocess-driven buffers can lag visually because Emacs only
;; redisplays when an event fires (input, timer, command return). While
;; the user is idle (e.g. waiting for an LLM agent to finish thinking)
;; no event fires, so the buffer's *text* is updated by the process
;; filter but the *screen* stays stale until you press a key.
;;
;; A 0.5s background timer that calls `(redisplay)' whenever a visible
;; window holds a buffer with a live subprocess closes that gap with
;; negligible CPU cost. This applies to vterm, comint (copilot-chat),
;; and any other subprocess buffer that is currently on screen.

(defvar my/process-redisplay-timer nil
  "Periodic timer that keeps subprocess buffers visually fresh.")

(defun my/--any-visible-subprocess-buffer-p ()
  "Return non-nil if a visible window holds a buffer with a live subprocess."
  (catch 'found
    (walk-windows
     (lambda (win)
       (let ((proc (get-buffer-process (window-buffer win))))
         (when (and proc (process-live-p proc))
           (throw 'found t))))
     nil 'visible)
    nil))

(defun my/--process-redisplay-tick ()
  "Force a redisplay if any visible window is showing live subprocess output."
  (when (my/--any-visible-subprocess-buffer-p)
    (redisplay)))

;; Guard against duplicate timers when this file is reloaded.
(when (and my/process-redisplay-timer
           (memq my/process-redisplay-timer timer-list))
  (cancel-timer my/process-redisplay-timer))
(setq my/process-redisplay-timer
      (run-with-timer 0.5 0.5 #'my/--process-redisplay-tick))

(provide 'config-perf)
;;; config-perf.el ends here
