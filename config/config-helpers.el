;; Random string generator for session IDs
(defun my/random-string (length)
  "Generate random alphanumeric string of LENGTH."
  (let ((chars "abcdefghijklmnopqrstuvwxyz0123456789"))
    (apply #'string
           (cl-loop repeat length
                    collect (aref chars (random (length chars)))))))



(defcustom my/notebook-monorepo-root
  "/Users/anara0823/Projects/data-strategy-models/"
  "Root directory of the monorepo containing notebook sub-projects."
  :type 'directory
  :group 'convenience)

(defcustom my/notebook-monorepo-projects-subdir
  "projects/"
  "Subdirectory under the monorepo root that contains sub-projects."
  :type 'string
  :group 'convenience)

(defun my/--current-subproject-root ()
  "Return the sub-project root for the current buffer, or nil.
First trusts projectile if its root is a real sub-project under
`<monorepo>/<projects-subdir>/'. Otherwise infers from
`default-directory'. All paths are normalized via `file-truename' so
symlinks (e.g. /Users vs /private/Users) don't break the match."
  (let* ((monorepo-root (file-name-as-directory
                         (file-truename
                          (expand-file-name my/notebook-monorepo-root))))
         (projects-dir (file-name-as-directory
                        (file-truename
                         (expand-file-name
                          my/notebook-monorepo-projects-subdir
                          monorepo-root))))
         (proj-root (when (fboundp 'projectile-project-root)
                      (ignore-errors (projectile-project-root))))
         (proj-root (when proj-root
                      (file-name-as-directory
                       (file-truename (expand-file-name proj-root)))))
         (cwd (file-name-as-directory
               (file-truename (expand-file-name default-directory)))))
    (cond
     ;; Projectile already points at a real sub-project (not the monorepo).
     ((and proj-root
           (string-prefix-p projects-dir proj-root)
           (not (string= proj-root projects-dir))
           (not (string= proj-root monorepo-root)))
      proj-root)
     ;; Infer from cwd: take the first path component after projects/.
     ((string-prefix-p projects-dir cwd)
      (let* ((rel (substring cwd (length projects-dir)))
             (first-component (car (split-string rel "/" t))))
        (when first-component
          (file-name-as-directory
           (expand-file-name first-component projects-dir))))))))

(defun my/create-tmp-notebook (name)
  "Create a new Python notebook in the current sub-project's notebooks/ dir.
Sub-project is inferred from the current buffer's path inside
`<monorepo-root>/<projects-subdir>/<sub-project>/'. Auto-creates a
.projectile marker at the sub-project root and the notebooks/ subdir
if either is missing."
  (interactive "sNotebook name: ")
  (let* ((subroot
          (or (my/--current-subproject-root)
              (user-error
               (concat "Cannot determine sub-project. "
                       "buffer-file=%s, default-directory=%s, "
                       "projectile-root=%s, monorepo=%s%s")
               (or buffer-file-name "<none>")
               default-directory
               (or (and (fboundp 'projectile-project-root)
                        (ignore-errors (projectile-project-root)))
                   "<unset>")
               my/notebook-monorepo-root
               my/notebook-monorepo-projects-subdir)))
         (projectile-marker (expand-file-name ".projectile" subroot))
         (notebooks-dir (file-name-as-directory
                         (expand-file-name "notebooks" subroot)))
         (date-prefix (format-time-string "%Y%m%d"))
         (filename (expand-file-name (format "%s_%s.org" date-prefix name)
                                     notebooks-dir)))
    (unless (file-exists-p projectile-marker)
      (write-region "" nil projectile-marker)
      (message "Created .projectile at %s" subroot))
    (unless (file-exists-p notebooks-dir)
      (make-directory notebooks-dir t))
    (find-file filename)
    (when (= (buffer-size) 0)
      (org-mode)
      (unless yas-minor-mode
        (yas-global-mode 1))
      (insert "babel")
      (yas-expand))))

(defun my/goto-helper-functions ()
  "Jump to the helper-functions named block in current buffer."
  (interactive)
  (org-babel-goto-named-src-block "helper-functions"))

(spacemacs/set-leader-keys "onn" 'my/create-tmp-notebook)


(defun my/create-projectile-file ()
  "Create a .projectile file in the current dired directory."
  (interactive)
  (if (eq major-mode 'dired-mode)
      (let* ((dir (dired-current-directory))
             (projectile-file (expand-file-name ".projectile" dir)))
        (if (file-exists-p projectile-file)
            (message ".projectile already exists in %s" dir)
          (progn
            (write-region "" nil projectile-file)
            (message "Created .projectile in %s" dir)
            ;; Refresh dired to show the new file
            (revert-buffer))))
    (user-error "This command only works in dired buffers")))

(defun my/create-projectile-file-anywhere ()
  "Create a .projectile file in a chosen directory."
  (interactive)
  (let* ((default-dir (if (eq major-mode 'dired-mode)
                          (dired-current-directory)
                        default-directory))
         (chosen-dir (read-directory-name "Create .projectile in: " default-dir))
         (projectile-file (expand-file-name ".projectile" chosen-dir)))
    (if (file-exists-p projectile-file)
        (message ".projectile already exists in %s" chosen-dir)
      (progn
        (write-region "" nil projectile-file)
        (message "Created .projectile in %s" chosen-dir)
        ;; if in dired and it's the same directory, refresh
        (when (and (eq major-mode 'dired-mode)
                   (string = (dired-current-directory) chosen-dir))
          (revert-buffer))))))
(spacemacs/set-leader-keys "fp" 'my/create-projectile-file-anywhere)
(defun my/sqlfmt-region (start end)
  "Format SQL region using sqlfmt."
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (list nil nil)))
  (unless (and start end)
    (user-error "No region selected"))

  (let* ((sqlfmt-cmd (or (executable-find "sqlfmt")
                         (executable-find "shandy-sqlfmt")
                         (user-error "sqlfmt not found in PATH")))
         (temp-file (make-temp-file "sqlfmt" nil ".sql"))
         (original-content (buffer-substring-no-properties start end)))

    (unwind-protect
        (progn
          ;; Write region to temp file
          (write-region start end temp-file)

          ;; Run sqlfmt
          (let ((exit-code (call-process sqlfmt-cmd nil nil nil
                                         temp-file
                                         "--line-length" "100"
                                         "--quiet")))
            (if (zerop exit-code)
                (progn
                  ;; Replace region with formatted content
                  (delete-region start end)
                  (insert-file-contents temp-file))
              (user-error "sqlfmt failed with exit code %d" exit-code))))

      ;; Cleanup: always delete temp file
      (when (file-exists-p temp-file)
        (delete-file temp-file)))))

(defun my/sqlfmt-buffer ()
  "Format entire SQL buffer using sqlfmt."
  (interactive)
  (save-excursion
    (my/sqlfmt-region (point-min) (point-max))))

(defun my/sqlfmt-dwim ()
  "Format SQL region if active, otherwise format entire buffer."
  (interactive)
  (if (use-region-p)
      (my/sqlfmt-region (region-beginning) (region-end))
    (my/sqlfmt-buffer)))

(with-eval-after-load 'dired
  (spacemacs/set-leader-keys-for-major-mode 'dired-mode
    "p" 'my/create-projectile-file)
  )
(provide 'config-helpers)
