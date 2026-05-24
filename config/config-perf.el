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

(provide 'config-perf)
;;; config-perf.el ends here
