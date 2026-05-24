;; Vanilla sql.el ships no autoloaded auto-mode-alist entry for .sql, so
;; .sql files land in fundamental-mode unless we register sql-mode here.
(add-to-list 'auto-mode-alist '("\\.sql\\'" . sql-mode))

(with-eval-after-load 'sql
  ;; Default dialect: postgres is the closest match to BigQuery's GoogleSQL
  ;; for keyword highlighting. Switch per-buffer with `M-x sql-set-product'.
  (setq sql-product 'postgres))

;; The spacemacs LSP layer binds `SPC m = b' / `= r' on the lsp-mode
;; *minor-mode* keymap (see layers/+tools/lsp/funcs.el `spacemacs/lsp-bind-keys').
;; Minor-mode bindings beat major-mode bindings, so binding via
;; `set-leader-keys-for-major-mode' is shadowed. We must override on the
;; same minor-mode keymap. To avoid breaking format for python/ts/etc, we
;; dispatch on `major-mode': sql-mode -> sqlfmt; other modes -> original
;; lsp formatter.
(defun my/sql-or-lsp-format-buffer ()
  "Format buffer: `my/sqlfmt-buffer' in sql-mode, else `lsp-format-buffer'."
  (interactive)
  (if (derived-mode-p 'sql-mode)
      (call-interactively #'my/sqlfmt-buffer)
    (call-interactively #'lsp-format-buffer)))

(defun my/sql-or-lsp-format-region (beg end)
  "Format region: `my/sqlfmt-region' in sql-mode, else `lsp-format-region'."
  (interactive "r")
  (if (derived-mode-p 'sql-mode)
      (my/sqlfmt-region beg end)
    (lsp-format-region beg end)))

(defun my/sql-format-dwim ()
  "DWIM format in sql-mode (region if active else buffer); errors elsewhere.
Mirrors `my/sqlfmt-dwim'; bound on `= f' which LSP leaves unbound."
  (interactive)
  (if (derived-mode-p 'sql-mode)
      (call-interactively #'my/sqlfmt-dwim)
    (user-error "`= f' is only configured for sql-mode")))

;; `with-eval-after-load' runs after lsp-mode's `:config' block (where
;; `spacemacs/lsp-bind-keys' lives), so our bindings overwrite LSP's.
(with-eval-after-load 'lsp-mode
  (spacemacs/set-leader-keys-for-minor-mode 'lsp-mode
    "=b" #'my/sql-or-lsp-format-buffer
    "=r" #'my/sql-or-lsp-format-region
    "=f" #'my/sql-format-dwim))

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

;; ---------------------------------------------------------------------------
;; * BigQuery: run current .sql via shared.bq_client
;; ---------------------------------------------------------------------------
;; Run the SQL in the current buffer (or active region) against the
;; project's `shared.bq_client'. A synchronous dry-run estimates bytes
;; scanned and asks for confirmation; on yes, the real query runs
;; asynchronously via `uv run python', writes a CSV to
;; <project>/data/bq-results/, and shows a preview in a side buffer.
;;
;; Keybinding: SPC m B r  (B = BigQuery; capital avoids LSP's lowercase
;; `b' backend prefix). Region is run if active, else the whole buffer.

(defvar my/--sql-bq-script
  "import sys, os
from shared.core.config import get_shared_config
from google.cloud import bigquery

mode, sql_path = sys.argv[1], sys.argv[2]
csv_out = sys.argv[3] if len(sys.argv) > 3 else ''

with open(sql_path) as f:
    sql = f.read()

try:
    client = get_shared_config().bq_client
    if mode == 'dry':
        cfg = bigquery.QueryJobConfig(dry_run=True, use_query_cache=False)
        job = client.query(sql, job_config=cfg)
        print(f'DRY_RUN_BYTES={job.total_bytes_processed}')
    else:
        job = client.query(sql)
        df = job.to_dataframe()
        if csv_out:
            os.makedirs(os.path.dirname(csv_out), exist_ok=True)
            df.to_csv(csv_out, index=False)
        rows, cols = len(df), len(df.columns)
        print(f'ROWS={rows}')
        print(f'COLS={cols}')
        print(f'CSV={csv_out}')
        print('---')
        print(df.head(200).to_string())
        if rows > 200:
            print()
            print(f'... {rows - 200} more rows (full data in CSV)')
except Exception as e:
    print(f'BQ_ERROR: {type(e).__name__}: {e}', file=sys.stderr)
    sys.exit(1)
"
  "Python script invoked via `uv run python -c <script>` for BQ dry-run / run.")

(defun my/--sql-bq-format-bytes (bytes)
  "Humanize BYTES processed plus estimated $ cost (~$6.25/TB on-demand)."
  (let* ((cost (* (/ bytes 1.0e12) 6.25))
         (size (cond ((< bytes 1024) (format "%d B" bytes))
                     ((< bytes 1.0e6) (format "%.1f KB" (/ bytes 1024.0)))
                     ((< bytes 1.0e9) (format "%.1f MB" (/ bytes 1.0e6)))
                     ((< bytes 1.0e12) (format "%.2f GB" (/ bytes 1.0e9)))
                     (t (format "%.2f TB" (/ bytes 1.0e12))))))
    (format "%s (~$%.4f)" size cost)))

(defun my/--sql-bq-project-root ()
  "Return the project root for the current SQL file.
Prefers `my/--current-subproject-root' (knows about the
data-strategy-models monorepo layout); falls back to `default-directory'."
  (or (and (fboundp 'my/--current-subproject-root)
           (my/--current-subproject-root))
      default-directory))

(defun my/--sql-bq-csv-path (project-root sql-buffer-name)
  "Return CSV output path under PROJECT-ROOT for SQL-BUFFER-NAME, ensuring dir."
  (let* ((base (file-name-base sql-buffer-name))
         (ts (format-time-string "%Y%m%d-%H%M%S"))
         (dir (expand-file-name "data/bq-results/" project-root))
         (fname (format "%s-%s.csv" base ts)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    (expand-file-name fname dir)))

(defun my/--sql-bq-write-temp (sql-text)
  "Write SQL-TEXT to a fresh temp .sql file and return its path."
  (let ((tmp (make-temp-file "bq-sql-" nil ".sql")))
    (with-temp-file tmp
      (insert sql-text))
    tmp))

(defun my/--sql-bq-dry-run (sql-file project-root)
  "Run dry-run synchronously. Return total_bytes_processed (int).
Signals a `user-error' on failure."
  (let ((default-directory project-root))
    (with-temp-buffer
      (let ((exit (call-process "uv" nil '(t t) nil
                                "run" "python" "-c"
                                my/--sql-bq-script
                                "dry" sql-file)))
        (goto-char (point-min))
        (cond
         ((not (zerop exit))
          (user-error "BQ dry-run failed (exit %d):\n%s"
                      exit (string-trim (buffer-string))))
         ((re-search-forward "^DRY_RUN_BYTES=\\([0-9]+\\)" nil t)
          (string-to-number (match-string 1)))
         (t
          (user-error "BQ dry-run produced unexpected output:\n%s"
                      (string-trim (buffer-string)))))))))

(defun my/--sql-bq-finalize (out-buf csv-path)
  "Prepend a clickable [Open CSV] button to OUT-BUF if CSV-PATH exists."
  (when (and (buffer-live-p out-buf) csv-path (file-readable-p csv-path))
    (with-current-buffer out-buf
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (point-min))
          (let ((start (point)))
            (insert "[ Open CSV ]\n\n")
            (make-text-button start (- (point) 2)
                              'action (lambda (_) (find-file csv-path))
                              'face 'link
                              'follow-link t
                              'help-echo (format "Open %s" csv-path))))))))

(defun my/--sql-bq-sentinel (proc _event)
  "Process sentinel: announce completion and clean up the temp .sql file."
  (when (memq (process-status proc) '(exit signal))
    (let ((buf (process-buffer proc))
          (exit-code (process-exit-status proc))
          (sql-tmp (process-get proc 'my-sql-tmp))
          (csv (process-get proc 'my-csv-path)))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (goto-char (point-max))
            (insert (format "\n--- Done (exit %d, %s) ---\n"
                            exit-code (format-time-string "%H:%M:%S")))))
        (when (zerop exit-code)
          (my/--sql-bq-finalize buf csv)))
      (when (and sql-tmp (file-exists-p sql-tmp))
        (ignore-errors (delete-file sql-tmp))))))

(defun my/--sql-bq-run-async (sql-file project-root sql-buffer-name csv-path)
  "Spawn the BQ run script async; output appended to a side buffer."
  (let* ((default-directory project-root)
         (out-name (format "*bq-result: %s*" sql-buffer-name))
         (out-buf (get-buffer-create out-name)))
    (with-current-buffer out-buf
      (let ((inhibit-read-only t))
        (special-mode)
        (erase-buffer)
        (insert (format "Running query at %s ...\n\n"
                        (format-time-string "%H:%M:%S")))))
    (display-buffer-in-side-window
     out-buf '((side . right) (slot . 0) (window-width . 0.45)))
    (let ((proc (make-process
                 :name (format "bq-%s" sql-buffer-name)
                 :buffer out-buf
                 :command (list "uv" "run" "python" "-c"
                                my/--sql-bq-script
                                "run" sql-file csv-path)
                 :sentinel #'my/--sql-bq-sentinel
                 :connection-type 'pipe)))
      (process-put proc 'my-sql-tmp sql-file)
      (process-put proc 'my-csv-path csv-path)
      proc)))

(defun my/sql-bq-run ()
  "Run the current SQL (region if active, else whole buffer) via BigQuery.
Dry-runs first to estimate cost; on confirmation runs the real query
asynchronously and shows results in a side buffer."
  (interactive)
  (unless (derived-mode-p 'sql-mode)
    (user-error "Not in a sql-mode buffer"))
  (let* ((sql (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (buffer-substring-no-properties (point-min) (point-max))))
         (sql-buf-name (or (and buffer-file-name
                                (file-name-nondirectory buffer-file-name))
                           (buffer-name)))
         (project-root (my/--sql-bq-project-root))
         (sql-tmp (my/--sql-bq-write-temp sql))
         (bytes (progn
                  (message "BQ: estimating cost...")
                  (my/--sql-bq-dry-run sql-tmp project-root)))
         (cost-str (my/--sql-bq-format-bytes bytes)))
    (if (yes-or-no-p (format "This query will scan %s. Run? " cost-str))
        (let ((csv (my/--sql-bq-csv-path project-root sql-buf-name)))
          (my/--sql-bq-run-async sql-tmp project-root sql-buf-name csv)
          (message "BQ: running query (%s)..." cost-str))
      (delete-file sql-tmp)
      (message "BQ: cancelled"))))

(with-eval-after-load 'sql
  (when (fboundp 'spacemacs/declare-prefix-for-mode)
    (spacemacs/declare-prefix-for-mode 'sql-mode "mB" "BigQuery"))
  (spacemacs/set-leader-keys-for-major-mode 'sql-mode
    "Br" #'my/sql-bq-run))

(provide 'config-sql)
