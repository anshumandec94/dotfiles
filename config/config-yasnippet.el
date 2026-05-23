;;; config-yasnippet.el --- Custom snippet configuration

(with-eval-after-load 'yasnippet
  (let ((custom-snippet-dir (expand-file-name "snippets" user-emacs-directory)))
    (add-to-list 'yas-snippet-dirs custom-snippet-dir t)
    (yas-reload-all))

  ;; Enable yasnippet globally so it works everywhere
  (yas-global-mode 1))

(provide 'config-yasnippet)
