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
          (:cache . "no"))))

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
    "," 'org-edit-src-exit))



(provide 'config-org)
