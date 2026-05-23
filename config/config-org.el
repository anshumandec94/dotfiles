;;; config-org.el --- Org-mode configuration for GTD and literate programming
;;; Commentary:
;; Complete org-mode setup with GTD workflow, capture templates, and babel

;;; Code:


(setq org-confirm-babel-evaluate nil)
(add-hook 'org-mode-hook 'visual-line-mode)

(setq org-directory "~/org/")


;; Defining files for org-agenda to scan for tasks and events
(setq org-agenda-files (list (concat org-directory "inbox.org")
                             (concat org-directory "projects.org")))

;; Setting up archive location
(setq org-archive-location (concat org-directory "archive.org::* From %s"))

;; File path variables
(setq org-inbox-file (concat org-directory "inbox.org")
      org-projects-file (concat org-directory "projects.org")
      org-notes-file (concat org-directory "notes.org"))

;; Babel Configuration
(with-eval-after-load 'org
  (setq org-babel-python-command "uv run python")

  ;; Ensure proper output capture
  (setq org-babel-default-header-args:python
        '((:results . "output drawer")
          (:session . "main")
          (:exports . "both")
          (:cache . "no")))
  ;; Add a hook to refresh inline images after executing a source block

  (defun my/org-babel-refresh-inline-images ()
    "Refresh inline images after executing a source block."
    (when org-inline-image-overlays
      (org-display-inline-images)))

  (add-hook 'org-babel-after-execute-hook #'my/org-babel-refresh-inline-images)
  )

;; Now define templates with backquote and comma
(setq org-capture-templates
      `(("t" "Todo" entry
         (file+headline ,org-inbox-file "Tasks")
         "* TODO %?\n:PROPERTIES:\n:CREATED: %T\n:END:\n\n"
         :empty-lines 1)

        ("d" "Deadline Task" entry
         (file+headline ,org-inbox-file "Tasks")
         "* TODO %?\n  DEADLINE: %^t\n:PROPERTIES:\n:CREATED: %T\n:END:\n\n"
         :empty-lines 1)

        ("p" "Project" entry
         (file ,org-projects-file)
         "* %? [#C] :PROJECT:\n:PROPERTIES:\n:CREATED: %T\n:END:\n\n** Tasks\n\n** Notes\n"
         :empty-lines-after 1)

        ("n" "Note" entry
         (file+headline ,org-inbox-file "Notes")
         "* %? :NOTE:\n:PROPERTIES:\n:CREATED: %T\n:END:\n\n"
         :empty-lines 1
         :hook (lambda () (org-set-tags-command)))))

(require 'org-cliplink)

(setq org-agenda-sorting-strategy
      '((agenda time-up priority-down)
        (todo priority-down)
        (tags priority-down)
        (search priority-down)))
(setq org-tag-alist '((:startgrouptag)
                      ("AREA")
                      (:grouptags)
                      ("@work" . ?w)
                      ("@school" . ?s)
                      ("@personal" . ?p)
                      (:endgrouptag)

                      (:startgrouptag)
                      ("CONTEXT")
                      (:grouptags)
                      ("meeting" . ?m)
                      ("idea" . ?i)
                      ("reference" . ?r)
                      (:endgrouptag)

                      ("PROJECT" . ?P)
                      ("urgent" . ?u)
                      ("waiting" . ?W)))

(setq org-use-tag-inheritance t)
(setq org-tags-exclude-from-inheritance '("PROJECT"))
(setq org-agenda-show-inherited-tags t)

(setq org-refile-targets '((org-agenda-files :tag . "PROJECT")
                           (org-agenda-files :maxlevel . 3)))
(setq org-refile-use-outline-path 'file)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-allow-creating-parent-nodes 'confirm)


(setq org-agenda-custom-commands
      '(("n" "Agenda and all TODOs"
         ((agenda "")
          (alltodo "")))

        ;; Area overview views
        ("w" "Work Overview"
         ((tags "PROJECT+@work"
                ((org-agenda-overriding-header "Work Projects")))
          (tags-todo "@work-PROJECT"
                     ((org-agenda-overriding-header "Work Tasks")))
          (tags "@work-PROJECT-TODO=\"TODO\"-TODO=\"DONE\""
                ((org-agenda-overriding-header "Work Notes & Ideas")))))

        ("s" "School Overview"
         ((tags "PROJECT+@school"
                ((org-agenda-overriding-header "School Projects")))
          (tags-todo "@school-PROJECT"
                     ((org-agenda-overriding-header "School Tasks")))
          (tags "@school-PROJECT-TODO=\"TODO\"-TODO=\"DONE\""
                ((org-agenda-overriding-header "School Notes & Ideas")))))

        ("p" "Personal Overview"
         ((tags "PROJECT+@personal"
                ((org-agenda-overriding-header "Personal Projects")))
          (tags-todo "@personal-PROJECT"
                     ((org-agenda-overriding-header "Personal Tasks")))
          (tags "@personal-PROJECT-TODO=\"TODO\"-TODO=\"DONE\""
                ((org-agenda-overriding-header "Personal Notes & Ideas")))))

        ;; Context views
        ("m" "All Meetings" tags "meeting"
         ((org-agenda-overriding-header "Meeting Notes")))
        ("i" "All Ideas" tags "idea"
         ((org-agenda-overriding-header "Ideas & Brainstorms")))
        ("r" "All References" tags "reference"
         ((org-agenda-overriding-header "Reference Materials")))

        ;; Inbox review
        ("I" "Inbox Review"
         ((tags "LEVEL=2+CATEGORY=\"inbox\""
                ((org-agenda-overriding-header "Items to Review & Refile")))))

        ;; Weekly review (keeping your existing one)
        ("W" "Weekly Review"
         ((agenda "" ((org-agenda-span 7)
                      (org-agenda-start-day "-7d")))
          (todo "TODO")
          (todo "WAITING")
          (todo "DONE")))))


(with-eval-after-load 'org-src
  ;;Configure org-src editing
  (setq org-src-window-setup 'current-window)
  (setq org-src-fontify-natively t)
  (setq org-src-preserve-indentation t)
  (setq org-src-tab-acts-natively t))


(with-eval-after-load 'org
  (spacemacs/set-leader-keys
    "oc" 'org-capture
    "oa" 'org-agenda
    "or" 'org-refile
    "ol" 'org-store-link)
  (spacemacs/set-leader-keys-for-major-mode 'org-mode
    "oi" 'org-cliplink
    "'"  'org-edit-special
    "," 'org-edit-src-exit
    ;; Create notebook and helper functions
    "nn" 'my/create-tmp-notebook
    "nh" 'my/goto-helper-functions
    ;; Block management
    "ba" 'my/add-src-block-above
    "bb" 'my/add-src-block-below
    "bd" 'my/delete-src-block
    "be" 'my/execute-and-next
    "bp" 'my/add-plot-block-below
    "bc" 'my/duplicate-src-block
    ;; Session management
    "ss" 'my/org-start-python-session
    "sb" 'org-babel-switch-to-session
    "sr" 'my/org-send-region-to-session
    )

  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python .t))))


;; Source block management functions
(defun my/add-src-block-above ()
  "Add source block above current position."
  (interactive)
  (let ((lang (or (car (org-babel-get-src-block-info)) "python")))
    (if (org-babel-get-src-block-info)
        (goto-char (org-babel-where-is-src-block-head))
      (beginning-of-line))
    (open-line 2)
    (insert (format "#+BEGIN_SRC %s\n\n#+END_SRC" lang))
    (forward-line -1)))

(defun my/add-src-block-below ()
  "Add source block below current position."
  (interactive)
  (let ((lang (or (car (org-babel-get-src-block-info)) "python")))
    (if (org-babel-get-src-block-info)
        (org-babel-goto-src-block-result)
      (end-of-line))
    (open-line 3)
    (forward-line 1)
    (insert (format "#+BEGIN_SRC %s\n\n#+END_SRC" lang))
    (forward-line -1)))

(defun my/delete-src-block ()
  "Delete current source block and its results."
  (interactive)
  (when (org-babel-get-src-block-info)
    (org-babel-remove-result)
    (let* ((info (org-babel-get-src-block-info))
           (start (org-babel-where-is-src-block-head))
           (body (org-element-property :end (org-element-at-point))))
      (goto-char start)
      (delete-region start body))))

(defun my/execute-and-next ()
  "Execute current block and move to next."
  (interactive)
  (org-babel-execute-src-block)
  (org-babel-next-src-block))

(defun my/add-plot-block-below ()
  "Add a plotting src block below current position."
  (interactive)
  (let ((lang (or (car (org-babel-get-src-block-info)) "python")))
    (if (org-babel-get-src-block-info)
        (org-babel-goto-src-block-result)
      (end-of-line))
    (open-line 3)
    (forward-line 1)
    (insert (format "#+BEGIN_SRC %s :results file drawer\n\n#+END_SRC" lang))
    (forward-line -1)))

(defun my/duplicate-src-block ()
  "Duplicate the current src block and insert it below."
  (interactive)
  (when (org-babel-get-src-block-info)
    (let* ((element (org-element-at-point))
           (start (org-element-property :begin element))
           (end (org-element-property :end element))
           (block-text (buffer-substring-no-properties start end)))
      (goto-char end)
      (open-line 1)
      (insert block-text)
      ;; position cursor inside new block
      (search-backward "#+BEGIN_SRC")
      (forward-line 1))))

(defun my/org-start-python-session ()
  "Start Python session from current org buffer and switch to it."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (org-babel-next-src-block)
    (let* ((session-name (cdr (assq :session
                                    (nth 2 (org-babel-get-src-block-info)))))
           (session-buffer (org-babel-initiate-session session-name)))
      (pop-to-buffer session-buffer))))

(defun my/org-send-region-to-session (start end)
  "Send selected region to the active Python session."
  (interactive "r")
  (let* ((session-name (save-excursion
                         (goto-char (point-min))
                         (org-babel-next-src-block)
                         (cdr (assq :session
                                    (nth 2 (org-babel-get-src-block-info))))))
         (session-buffer (org-babel-initiate-session session-name))
         (process (get-buffer-process session-buffer)))
    (if process
        (python-shell-send-string
         (buffer-substring-no-properties start end)
         process)
      (user-error "No active process found in session buffer %s" session-buffer))))
(provide 'config-org)
