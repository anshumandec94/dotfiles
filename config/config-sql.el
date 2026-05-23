;; Vanilla sql.el ships no autoloaded auto-mode-alist entry for .sql, so
;; .sql files land in fundamental-mode unless we register sql-mode here.
(add-to-list 'auto-mode-alist '("\\.sql\\'" . sql-mode))

(with-eval-after-load 'sql
  ;; Default dialect: postgres is the closest match to BigQuery's GoogleSQL
  ;; for keyword highlighting. Switch per-buffer with `M-x sql-set-product'.
  (setq sql-product 'postgres)

  ;; Set up keybindings for SQL mode.
  ;; `=' alone calls `my/sqlfmt-dwim' which already handles region-if-active
  ;; else whole buffer, so we don't need separate `==' / `=r' bindings.
  ;; (Mixing them errors with "Key sequence = = starts with non-prefix key
  ;; =" because `=' is a leaf binding and can't also act as a prefix.)
  (spacemacs/set-leader-keys-for-major-mode 'sql-mode
    "=" 'my/sqlfmt-dwim))

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
