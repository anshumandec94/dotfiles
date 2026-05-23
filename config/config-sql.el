(with-eval-after-load 'sql
  ;; Set up keybindings for SQL mode
  (spacemacs/set-leader-keys-for-major-mode 'sql-mode
    "=" 'my/sqlfmt-dwim
    "==" 'my/sqlfmt-buffer
    "=r" 'my/sqlfmt-region))

;; Global keybinding (your colleague's approach)
(spacemacs/set-leader-keys "oS" 'my/sqlfmt-dwim)

;; Optional: Auto-format on save
(defun my/maybe-sqlfmt-buffer ()
  "Auto-format SQL buffer on save if sqlfmt is available."
  (when (and (derived-mode-p 'sql-mode)
             (executable-find "sqlfmt"))
    (my/sqlfmt-buffer)))

;; Uncomment to enable auto-format on save
;; (add-hook 'before-save-hook #'my/maybe-sqlfmt-buffer)

(provide 'config-sql)
