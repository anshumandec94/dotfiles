;; Vanilla sql.el ships no autoloaded auto-mode-alist entry for .sql, so
;; .sql files land in fundamental-mode unless we register sql-mode here.
(add-to-list 'auto-mode-alist '("\\.sql\\'" . sql-mode))

(with-eval-after-load 'sql
  ;; Default dialect: postgres is the closest match to BigQuery's GoogleSQL
  ;; for keyword highlighting. Switch per-buffer with `M-x sql-set-product'.
  (setq sql-product 'postgres))

;; The spacemacs LSP layer makes SPC m = a prefix with sub-keys (= b for
;; lsp-format-buffer, = r for lsp-format-region, etc). `sql-ls' doesn't
;; implement documentFormattingProvider so those error out. Override the
;; sub-keys with our sqlfmt equivalents whenever lsp-mode activates in a
;; sql-mode buffer. Appended (`t') so we run after lsp's own hook.
(with-eval-after-load 'lsp-mode
  (add-hook 'lsp-mode-hook
            (lambda ()
              (when (derived-mode-p 'sql-mode)
                (spacemacs/set-leader-keys-for-major-mode 'sql-mode
                  "=b" 'my/sqlfmt-buffer
                  "=r" 'my/sqlfmt-region
                  "=f" 'my/sqlfmt-dwim)))
            t))

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
