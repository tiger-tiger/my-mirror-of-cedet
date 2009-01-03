;;; srecode-template-mode.el --- Major mode for writing screcode macros

;; This file is not part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This software is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;; 

(require 'srecode-template)
(require 'semantic)
(require 'wisent)

;;; Code:
(defvar srecode-template-mode-syntax-table
  (let ((table (make-syntax-table (standard-syntax-table))))
    (modify-syntax-entry ?\; ". 12"  table) ;; SEMI, Comment start ;;
    (modify-syntax-entry ?\n ">"     table) ;; Comment end
    (modify-syntax-entry ?$  "."     table) ;; Comment end
    (modify-syntax-entry ?\" "\""    table) ;; String
    (modify-syntax-entry ?\- "_"     table) ;; Symbol
    (modify-syntax-entry ?\: "_"     table) ;; Symbol
    (modify-syntax-entry ?\\ "\\"    table) ;; Quote
    (modify-syntax-entry ?\` "'"     table) ;; Prefix ` (backquote)
    (modify-syntax-entry ?\' "'"     table) ;; Prefix ' (quote)
    (modify-syntax-entry ?\, "'"     table) ;; Prefix , (comma)
    
    table)
  "Syntax table used in semantic recoder macro buffers.")

(defface srecode-separator-face
  '((t (:weight bold :strike-through t)))
  "Face used for decorating separators in srecode template mode."
  :group 'srecode)

(defvar srecode-font-lock-keywords
  '(
    ;; Template
    ("^\\(template\\)\\s-+\\(\\w*\\)\\(\\( \\(:\\w+\\)\\|\\)+\\)$"
     (1 font-lock-keyword-face)
     (2 font-lock-function-name-face)
     (3 font-lock-builtin-face ))
    ("^\\(sectiondictionary\\)\\s-+\""
     (1 font-lock-keyword-face))
    ("^\\(bind\\)\\s-+\""
     (1 font-lock-keyword-face))
    ;; Variable type setting
    ("^\\(set\\)\\s-+\\(\\w+\\)\\s-+"
     (1 font-lock-keyword-face)
     (2 font-lock-variable-name-face))
    ("^\\(show\\)\\s-+\\(\\w+\\)\\s-*$"
     (1 font-lock-keyword-face)
     (2 font-lock-variable-name-face))
    ("\\<\\(macro\\)\\s-+\""
     (1 font-lock-keyword-face))
    ;; Context type setting
    ("^\\(context\\)\\s-+\\(\\w+\\)"
     (1 font-lock-keyword-face)
     (2 font-lock-builtin-face))
    ;; Prompting setting
    ("^\\(prompt\\)\\s-+\\(\\w+\\)"
     (1 font-lock-keyword-face)
     (2 font-lock-variable-name-face))
    ("\\(default\\(macro\\)?\\)\\s-+\\(\\(\\w\\|\\s_\\)+\\)"
     (1 font-lock-keyword-face)
     (3 font-lock-type-face))
    ("\\<\\(default\\(macro\\)?\\)\\>" (1 font-lock-keyword-face))
    ("\\<\\(read\\)\\s-+\\(\\(\\w\\|\\s_\\)+\\)"
     (1 font-lock-keyword-face)
     (2 font-lock-type-face))

    ;; Macro separators
    ("^----\n" 0 'srecode-separator-face)

    ;; Macro Matching
    (srecode-template-mode-macro-escape-match 1 font-lock-string-face)
    ((lambda (limit)
       (srecode-template-mode-font-lock-macro-helper
	limit "\\(\\??\\w+\\)[^ \t\n{}$#@&*()]*"))
     1 font-lock-variable-name-face)
    ((lambda (limit)
       (srecode-template-mode-font-lock-macro-helper
	limit "\\([#/]\\w+\\)[^ \t\n{}$#@&*()]*"))
     1 font-lock-keyword-face)
    ((lambda (limit)
       (srecode-template-mode-font-lock-macro-helper
	limit "\\([<>]\\w*\\):\\(\\w+\\):\\(\\w+\\)"))
     (1 font-lock-keyword-face)
     (2 font-lock-builtin-face)
     (3 font-lock-type-face))
    ((lambda (limit)
       (srecode-template-mode-font-lock-macro-helper
	limit "\\([<>]\\w*\\):\\(\\w+\\)"))
     (1 font-lock-keyword-face)
     (2 font-lock-type-face))
    ((lambda (limit)
       (srecode-template-mode-font-lock-macro-helper
	limit "!\\([^{}$]*\\)"))
     1 font-lock-comment-face)

    )
  "Keywords for use with srecode macros and font-lock.")

(defun srecode-template-mode-font-lock-macro-helper (limit expression)
  "Match against escape characters.
Don't scan past LIMIT.  Match with EXPRESSION."
  (let* ((done nil)
	 (md nil)
	 (tags (semantic-fetch-available-tags))
	 (est (semantic-find-first-tag-by-name "escape_start" tags))
	 (eet (semantic-find-first-tag-by-name "escape_end" tags))
	 (es (regexp-quote (if est (car (semantic-tag-variable-default est)) "{{")))
	 (ee (regexp-quote (if eet (car (semantic-tag-variable-default eet)) "}}")))
	 (regex (concat es expression ee))
	 )
    (while (not done)
      (save-match-data
	(if (re-search-forward regex limit t)
	    (when (equal (car (srecode-calculate-context)) "code")
	      (setq md (match-data)
		    done t))
	  (setq done t))))
    (set-match-data md)
    ;; (when md (message "Found a match!"))
    (when md t)))

(defun srecode-template-mode-macro-escape-match (limit)
  "Match against escape characters.
Don't scan past LIMIT."
  (let* ((done nil)
	 (md nil)
	 (tags (semantic-fetch-available-tags))
	 (est (semantic-find-first-tag-by-name "escape_start" tags))
	 (eet (semantic-find-first-tag-by-name "escape_end" tags))
	 (es (regexp-quote (if est (car (semantic-tag-variable-default est)) "{{")))
	 (ee (regexp-quote (if eet (car (semantic-tag-variable-default eet)) "}}")))
	 (regex (concat "\\(" es "\\|" ee "\\)"))
	 )
    (while (not done)
      (save-match-data
	(if (re-search-forward regex limit t)
	    (when (equal (car (srecode-calculate-context)) "code")
	      (setq md (match-data)
		    done t))
	  (setq done t))))
    (set-match-data md)
    ;;(when md (message "Found a match!"))
    (when md t)))

(defvar srecode-font-lock-macro-keywords nil
  "Dynamically generated `font-lock' keywords for srecode templates.
Once the escape_start, and escape_end sequences are known, then
we can tell font lock about them.")

(defvar srecode-template-mode-map
  (let ((km (make-sparse-keymap)))
    (define-key km "\C-c\C-c" 'srecode-compile-templates)
    (define-key km "\C-c\C-m" 'srecode-macro-help)
    km)
  "Keymap used in srecode mode.")

;;;###autoload
(defun srecode-template-mode ()
  "Major-mode for writing srecode macros."
  (interactive)
  (kill-all-local-variables)
  (setq major-mode 'srecode-template-mode
        mode-name "SRecoder"
	comment-start ";;"
	comment-end "")
  (set (make-local-variable 'parse-sexp-ignore-comments) t)
  (set (make-local-variable 'comment-start-skip)
       "\\(\\(^\\|[^\\\\\n]\\)\\(\\\\\\\\\\)*\\);+ *")
  (set-syntax-table srecode-template-mode-syntax-table)
  (use-local-map srecode-template-mode-map)
  (set (make-local-variable 'font-lock-defaults)
       '(srecode-font-lock-keywords
         nil  ;; perform string/comment fontification
         nil  ;; keywords are case sensitive.
         ;; This puts _ & - as a word constituant,
         ;; simplifying our keywords significantly
         ((?_ . "w") (?- . "w"))))
  (run-hooks 'srecode-template-mode-hook)
  )

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.srt$" . srecode-template-mode))

;;; Template Commands
;;
(defun srecode-macro-help ()
  "Provide help for working with macros in a tempalte."
  (interactive)
  (let* ((root 'srecode-template-inserter)
	 (myname (symbol-name root))
	 (chl (aref (class-v root) class-children))
	 (es (semantic-find-first-tag-by-name "escape_start" (current-buffer)))
	 (ee (semantic-find-first-tag-by-name "escape_end" (current-buffer)))
	 (ess (if es (car (semantic-tag-get-attribute es :default-value))
		"{{"))
	 (ees (if ee (car (semantic-tag-get-attribute ee :default-value))
		"}}"))
	 )
    (with-output-to-temp-buffer "*SRecode Macros*"
      (princ "Description of known SRecode Template Macros.")
      (terpri)
      (terpri)
      (while chl
	(let* ((C (car chl))
	       (name (symbol-name C))
	       (key (when (slot-exists-p C 'key)
		      (oref C key)))
	       (showexample t)
	       )
	  (setq chl (cdr chl))
	  (setq chl (append (aref (class-v C) class-children) chl))

	  (catch 'skip
	    (when (eq C 'srecode-template-inserter-section-end)
	      (throw 'skip nil))

	    (when (class-abstract-p C)
	      (throw 'skip nil))

	    (princ "`")
	    (princ name)
	    (princ "'")
	    (when (slot-exists-p C 'key)
	      (when key
		(princ " - Character Key: ")
		(if (stringp key)
		    (progn
		      (setq showexample nil)
		      (cond ((string= key "\n")
			     (princ "\"\\n\"")
			     )
			    (t
			     (prin1 key)
			     )))
		  (prin1 (format "%c" key))
		  )))
	    (terpri)
	    (princ (documentation-property C 'variable-documentation))
	    (terpri)
	    (when showexample
	      (princ "Example:")
	      (terpri)
	      (srecode-inserter-prin-example C ess ees)
	      )

	    (terpri)

	    ) ;; catch
	  );; let*
	))))


;;; Utils
;;
(defun srecode-tmeplate-get-mode ()
  "Get the supported major mode for this template file."
  (let ((m (semantic-find-first-tag-by-name "mode" (current-buffer))))
    (when m (read (semantic-tag-variable-default m)))))


;;; MMM-Mode support ??
(condition-case foo
    (require 'mmm-mode)
  (error (message "SRecoder Template Mode: No multi-mode not support.")))

(defun srecode-template-add-submode ()
  "Add a submode to the current template file using mmm-mode.
If mmm-mode isn't available, then do nothing."
  (if (not (featurep 'mmm-mode))
      nil  ;; Nothing to do.
    ;; Else, set up mmm-mode in this buffer.
    (let ((submode (semantic-find-tags-by-name "mode")))
      (if (not submode)
	  nil  ;; Nothing to do.
	;; Well, we have a mode, lets try turning on mmm-mode.

	;; (mmm-mode-on)
    
	

	))))


(provide 'srecode-template-mode)

;;; srecode-template-mode.el ends here
