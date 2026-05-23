;;; config-env.el --- Environment and PATH configuration

(add-to-list 'exec-path "/Library/TeX/texbin")
(setenv "PATH" (concat (getenv "PATH") ":/Library/TeX/texbin"))

;; Add other non-standard paths here as needed
;; e.g. pipx binaries if sqlfmt isn't found
;; (add-to-list 'exec-path (expand-file-name "~/.local/bin"))

(provide 'config-env)
