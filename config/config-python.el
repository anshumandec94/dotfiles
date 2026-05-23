;;; config-python.el -- Python configuration for Spacemacs with UV and LSP


;; Python interpreter setup
(setq python-shell-interpreter "uv"
      python-shell-interpreter-args "run python")

;; pytest config to use uv
(with-eval-after-load 'pytest
  (setq python-pytest-executable "uv run pytest"))

;; Hook to ensure that when we edit a Python source block in org-special-edit,
;; the buffer correctly sets up with LSP.
(with-eval-after-load 'lsp-mode
  ;; LSP Settings
  (setq lsp-completion-provider :capf
        lsp-auto-guess-root t)
  ;; Register custom 'ty' LSP client
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("uv" "run" "ty" "server"))
    :major-modes '(python-mode)
    :activation-fn (lsp-activate-on "python")
    :server-id 'ty
    :priority 10))

  (defun my/setup-org-src-lsp ()
    "Setup LSP for Python in org-src buffers."
    (when (and (bound-and-true-p org-src-mode)
               (derived-mode-p 'python-mode))
      ;; Set a temporary buffer file name if missing
      (unless buffer-file-name
        (setq buffer-file-name
              (expand-file-name (format "org-src-%s.py" (buffer-name))
                                default-directory)))
      ;;Configure LSP clients
      (setq-local lsp-disabled-clients '(pyright pylsp))
      (setq-local lsp-enabled-clients '(ty))
      ;; Start LSP
      (lsp-deferred)))
  ;; Add to org-src-mode hook
  (add-hook 'org-src-mode-hook #'my/setup-org-src-lsp)
  (add-hook 'python-mode-hook #'my/setup-org-src-lsp)
  )
;; Using Ruff Formatter

(defun my/python-format-with-ruff ()
  "Format the current Python buffer using 'uv run ruff format -'."
  (interactive)
  (when (derived-mode-p 'python-mode)
    ;; Skip formatting for org-src buffers or buffers without real files
    (unless (and buffer-file-name (string-match-p "org-src" (file-name-nondirectory buffer-file-name)))
      (when (buffer-file-name)
        (let ((shell-command-format-region-function
               (lambda (start end)
                 (list "uv" "run" "ruff" "format" "-"))))
          (call-interactively 'spacemacs/format-region)
          (message "Buffer formatted with Ruff.")))))
  )

(defun my/org-src-ruff-format-region-or-buffer ()
  "Format the active region or the whole buffer in an org-src Python buffer using 'uv run ruff format -'."
  (interactive)
  (unless (derived-mode-p 'python-mode)
    (user-error "Not in a Python buffer"))
  (let* ((start (if (use-region-p) (region-beginning) (point-min)))
         (end   (if (use-region-p) (region-end) (point-max)))
         (region-str (buffer-substring-no-properties start end))
         (formatted
          (with-temp-buffer
            (insert region-str)
            (let ((exit-code
                   (call-process-region (point-min) (point-max)
                                        "uv" t t nil
                                        "run" "ruff" "format" "-")))
              (if (zerop exit-code)
                  (buffer-string)
                (user-error "Ruff format failed"))))))
    (save-excursion
      (goto-char start)
      (delete-region start end)
      (insert formatted))
    (message "Formatted with Ruff.")))


(with-eval-after-load 'python
  ;; Bind our formatter to SPC m = (not = =, just =)
  (spacemacs/set-leader-keys-for-major-mode 'python-mode
    "rf" 'my/python-format-with-ruff
    "rb" 'my/org-src-ruff-format-region-or-buffer)
  ;; Add format-on-save
  (add-hook 'python-mode-hook
            (lambda ()
              (add-hook 'before-save-hook 'my/python-format-with-ruff nil t))))
(setq python-shell-completion-native-enable nil)

(provide 'config-python)
