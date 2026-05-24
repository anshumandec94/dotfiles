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

;; Bump read-process-output-max to 1 MB (default in Emacs 30 is 64 KB).
;; 1 MB is the commonly-recommended sweet spot; very large values (4+ MB)
;; have been reported to backfire on macOS, causing choppier streaming.
(setq read-process-output-max (* 1024 1024))

;; If we previously installed the periodic-redisplay timer (from an older
;; version of this file), cancel it. It tended to race with vterm's own
;; redraw and made streaming output choppier rather than smoother. The
;; right fix is `vterm-timer-delay nil' (set in config-cursor.el), which
;; bypasses vterm's broken timer-redraw path entirely.
(when (and (boundp 'my/process-redisplay-timer)
           my/process-redisplay-timer
           (memq my/process-redisplay-timer timer-list))
  (cancel-timer my/process-redisplay-timer)
  (setq my/process-redisplay-timer nil))

(provide 'config-perf)
;;; config-perf.el ends here
