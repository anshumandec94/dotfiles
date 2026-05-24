;;; config-cursor.el --- Cursor Agent CLI integration for Spacemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Embeds the Cursor Agent CLI into Spacemacs via vterm.
;; Provides session management, context sending, magit-based
;; change review, and a dedicated layout for AI-assisted work.

;;; Code:

;; ---------------------------------------------------------------------------
;; * Customization
;; ---------------------------------------------------------------------------

(defgroup cursor-agent nil
  "Cursor Agent CLI integration for Spacemacs."
  :group 'tools
  :prefix "cursor-agent-")

(defcustom cursor-agent-program
  (or (executable-find "agent")
      (expand-file-name "~/.local/bin/agent"))
  "Path to the Cursor Agent CLI binary."
  :type 'string
  :group 'cursor-agent)

(defcustom cursor-agent-args '()
  "Extra arguments passed to the agent command."
  :type '(repeat string)
  :group 'cursor-agent)

(defcustom cursor-agent-buffer-name-format "*agent:%s*"
  "Format string for agent buffer names. %s is replaced with the project name."
  :type 'string
  :group 'cursor-agent)

(defcustom cursor-agent-window-height 0.35
  "Height of the agent window as a fraction of frame height."
  :type 'float
  :group 'cursor-agent)

(defcustom cursor-agent-window-position 'bottom
  "Where to display the agent window. Either `bottom' or `right'."
  :type '(choice (const :tag "Bottom" bottom)
                 (const :tag "Right" right))
  :group 'cursor-agent)

;; ---------------------------------------------------------------------------
;; * Internal helpers
;; ---------------------------------------------------------------------------

(defun cursor-agent--project-name ()
  "Return the current project name, or 'default'."
  (or (and (fboundp 'projectile-project-name)
           (projectile-project-name))
      "default"))

(defun cursor-agent--project-root ()
  "Return the current project root directory."
  (or (and (fboundp 'projectile-project-root)
           (projectile-project-root))
      default-directory))

(defun cursor-agent--buffer-name (&optional project)
  "Return the agent buffer name for PROJECT."
  (format cursor-agent-buffer-name-format
          (or project (cursor-agent--project-name))))

(defun cursor-agent--get-buffer (&optional project)
  "Return the agent buffer for PROJECT if it exists and has a live process."
  (let ((buf (get-buffer (cursor-agent--buffer-name project))))
    (when (and buf (buffer-live-p buf))
      buf)))

(defun cursor-agent--display-buffer (buf)
  "Display BUF in a window according to `cursor-agent-window-position'."
  (let ((window (display-buffer-in-side-window
                 buf
                 `((side . ,cursor-agent-window-position)
                   (slot . 0)
                   (window-height . ,cursor-agent-window-height)
                   (window-width . 0.40)))))
    (select-window window)
    window))

;; ---------------------------------------------------------------------------
;; * Session management
;; ---------------------------------------------------------------------------

;; Lower vterm's redraw timer so streaming agent output feels real-time
;; (default 0.1s, slight CPU cost but no real downside on modern hardware).
(with-eval-after-load 'vterm
  (setq vterm-timer-delay 0.01))

(defun cursor-agent-start ()
  "Start a new Cursor Agent session for the current project.
If a session already exists, switch to it."
  (interactive)
  (let ((buf (cursor-agent--get-buffer)))
    (if buf
        (cursor-agent--display-buffer buf)
      (let* ((default-directory (cursor-agent--project-root))
             (buf-name (cursor-agent--buffer-name))
             (cmd (string-join
                   (cons cursor-agent-program cursor-agent-args)
                   " ")))
        (require 'vterm)
        ;; Create the vterm buffer manually so we get exactly one window.
        ;; Calling `(vterm)' interactively pops the buffer to a window via
        ;; `pop-to-buffer-same-window'; combined with our own
        ;; `display-buffer-in-side-window' that produced the classic
        ;; "agent appears in two windows" duplication.
        ;; Use `setq-local' (not `let') for `vterm-shell' to avoid the
        ;; lexical-binding pitfall where dynamic vs lexical scoping
        ;; depends on whether vterm.el has been loaded yet.
        (let ((new-buf (generate-new-buffer buf-name)))
          (with-current-buffer new-buf
            (setq-local vterm-shell (format "/bin/zsh -c '%s'" cmd))
            (vterm-mode))
          (cursor-agent--display-buffer new-buf))))))

(defun cursor-agent-switch ()
  "Toggle visibility / focus of the Cursor Agent buffer for this project.
No session: start one. Session exists but not focused: focus it (display
in side window if hidden). Already in the agent buffer: hide the side
window (or `quit-window' if it's in a regular window)."
  (interactive)
  (let ((buf (cursor-agent--get-buffer)))
    (cond
     ((not buf)
      (cursor-agent-start))
     ((not (eq (current-buffer) buf))
      (cursor-agent--display-buffer buf))
     ((window-parameter (selected-window) 'window-side)
      (delete-window))
     (t
      (quit-window)))))

(defun cursor-agent-kill ()
  "Kill the current project's agent session."
  (interactive)
  (let ((buf (cursor-agent--get-buffer)))
    (when buf
      (let ((win (get-buffer-window buf)))
        (when win (delete-window win)))
      (kill-buffer buf)
      (message "Agent session killed."))))

(defun cursor-agent-restart ()
  "Restart the agent session for the current project."
  (interactive)
  (cursor-agent-kill)
  (cursor-agent-start))

;; ---------------------------------------------------------------------------
;; * Sending context to the agent
;; ---------------------------------------------------------------------------

(defun cursor-agent--send-string (str)
  "Send STR to the agent vterm buffer."
  (let ((buf (cursor-agent--get-buffer)))
    (unless buf
      (cursor-agent-start)
      (setq buf (cursor-agent--get-buffer)))
    (with-current-buffer buf
      (vterm-send-string str))))

(defun cursor-agent--send-string-and-return (str)
  "Send STR followed by RET to the agent."
  (cursor-agent--send-string str)
  (let ((buf (cursor-agent--get-buffer)))
    (when buf
      (with-current-buffer buf
        (vterm-send-return)))))

(defun cursor-agent-send-region (start end)
  "Send the selected region to the agent."
  (interactive "r")
  (let ((text (buffer-substring-no-properties start end)))
    (cursor-agent--send-string text))
  (deactivate-mark))

(defun cursor-agent-send-buffer ()
  "Send the current buffer's content to the agent as a message."
  (interactive)
  (cursor-agent--send-string (buffer-substring-no-properties (point-min) (point-max))))

(defun cursor-agent-send-message (msg)
  "Prompt for MSG and send it to the agent."
  (interactive "sAgent message: ")
  (cursor-agent--send-string-and-return msg))

(defun cursor-agent-send-file-context ()
  "Send the current file path as context, telling the agent to look at it."
  (interactive)
  (if buffer-file-name
      (let ((relative (file-relative-name buffer-file-name
                                          (cursor-agent--project-root))))
        (cursor-agent--send-string-and-return
         (format "Look at the file %s" relative)))
    (message "Buffer is not visiting a file.")))

;; ---------------------------------------------------------------------------
;; * Change review (magit integration)
;; ---------------------------------------------------------------------------

(defun cursor-agent-review-unstaged ()
  "Show unstaged changes via magit (what the agent modified)."
  (interactive)
  (magit-diff-unstaged))

(defun cursor-agent-review-staged ()
  "Show staged changes via magit."
  (interactive)
  (magit-diff-staged))

(defun cursor-agent-review-file ()
  "Show diff of the current file against HEAD."
  (interactive)
  (magit-diff-buffer-file))

(defun cursor-agent-magit-status ()
  "Open magit status for the current project."
  (interactive)
  (magit-status))

;; ---------------------------------------------------------------------------
;; * Layout
;; ---------------------------------------------------------------------------

(defun cursor-agent-layout ()
  "Set up a dedicated window layout for AI-assisted work.
Left: current code buffer. Bottom-right: agent. Top-right: magit."
  (interactive)
  (delete-other-windows)
  (let ((code-buf (current-buffer))
        (agent-buf (or (cursor-agent--get-buffer)
                       (progn (cursor-agent-start)
                              (cursor-agent--get-buffer)))))
    ;; Start with code on the left
    (switch-to-buffer code-buf)
    ;; Split right for magit
    (let ((right-win (split-window-right)))
      (select-window right-win)
      (magit-status-setup-buffer (cursor-agent--project-root))
      ;; Split the right pane: top magit, bottom agent
      (let ((agent-win (split-window-below)))
        (select-window agent-win)
        (switch-to-buffer agent-buf)))
    ;; Return focus to code
    (windmove-left)))

;; ---------------------------------------------------------------------------
;; * Auto-revert setup
;; ---------------------------------------------------------------------------

(defun cursor-agent-ensure-auto-revert ()
  "Ensure buffers auto-revert when the agent modifies files on disk."
  (setq auto-revert-interval 1)
  (setq auto-revert-check-vc-info t)
  (global-auto-revert-mode 1))

;; ---------------------------------------------------------------------------
;; * Keybindings (SPC $ a prefix)
;; ---------------------------------------------------------------------------

(defun cursor-agent-setup-keys ()
  "Bind Cursor Agent commands under SPC $ a."
  (spacemacs/declare-prefix "$" "AI")
  (spacemacs/declare-prefix "$a" "agent")
  (spacemacs/declare-prefix "$as" "session")
  (spacemacs/declare-prefix "$ar" "review")
  (spacemacs/declare-prefix "$ax" "context")

  (spacemacs/set-leader-keys
    ;; Quick toggle -- most used binding
    "$aa"  'cursor-agent-switch

    ;; Session management
    "$ass" 'cursor-agent-start
    "$ask" 'cursor-agent-kill
    "$asr" 'cursor-agent-restart

    ;; Sending context
    "$axr" 'cursor-agent-send-region
    "$axb" 'cursor-agent-send-buffer
    "$axf" 'cursor-agent-send-file-context
    "$axm" 'cursor-agent-send-message

    ;; Change review
    "$aru" 'cursor-agent-review-unstaged
    "$ars" 'cursor-agent-review-staged
    "$arf" 'cursor-agent-review-file
    "$arg" 'cursor-agent-magit-status

    ;; Layout
    "$al"  'cursor-agent-layout))

;; ---------------------------------------------------------------------------
;; * Initialize
;; ---------------------------------------------------------------------------

(cursor-agent-ensure-auto-revert)
(cursor-agent-setup-keys)

(provide 'config-cursor)
;;; config-cursor.el ends here
