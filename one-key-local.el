;;; one-key-local.el --- create menu of one-key.el for any major-mode or minor-mode

;; Copyright (C) 2013  Hiroaki Otsu

;; Author: Hiroaki Otsu <ootsuhiroaki@gmail.com>
;; Keywords: one-key
;; URL: https://github.com/aki2o/one-key-local
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; 
;; This extension provides making menu of one-key.el for any major-mode or minor-mode
;; About one-key.el, see <http://www.emacswiki.org/emacs/OneKey>.

;;; Dependency:
;; 
;; - Following have been installed, one-key.el.

;;; Installation:
;;
;; Put this to your load-path.
;; And put the following lines in your .emacs or site-start.el file.
;; 
;; (require 'one-key-local)

;;; Configuration:
;;
;; You can create One-Key menu by the following way.
;; 
;; - If the mode has hook, e.g. dired-mode.
;;   (one-key-local-create-menu :hook 'dired-mode-hook :key nil :bind "?")
;; 
;; - If the mode has not hook but it is function, e.g. moccur-mode.
;;   (one-key-local-create-menu :mode 'moccur-mode :key nil :bind "?")
;; 
;; About the detailed usage of one-key-local-create-menu, eval following sexp.
;; (describe-function 'one-key-local-create-menu)

;;; Customization:
;; 
;; Nothing.

;;; API:
;; 
;; [EVAL] (autodoc-document-lisp-buffer :type 'macro :prefix "one-key-local-[^-]" :docstring t)
;; `one-key-local-create-menu'
;; Create One-Key Menu.
;; 
;;  *** END auto-documentation
;; 
;; [EVAL] (autodoc-update-all)
;; 
;; [Note] Functions and variables other than listed above, Those specifications may be changed without notice.

;;; Tested On:
;; 
;; - Emacs ... GNU Emacs 23.3.1 (i386-mingw-nt5.1.2600) of 2011-08-15 on GNUPACK
;; - one-key.el ... Version 0.7.1


;; Enjoy!


(eval-when-compile (require 'cl))
(require 'one-key)
(require 'advice)

(defmacro* one-key-local-create-menu (&key hook mode map key bind)
  "Create One-Key Menu.

HOOK is quoted hook symbol of the target mode.
MODE is quoted mode symbol of the target mode.
Given HOOK or MODE is required.

MAP is quoted keymap symbol of the target mode.
If nil, the following values is used.
If HOOK given, replaced value \"hook\" to \"map\". For exsample, HOOK is 'hoge-mode-hook, then MAP is 'hoge-mode-map.
If MODE given, added \"-map\" value. For exsample, MODE is 'hoge-mode, then MAP is 'hoge-mode-map.

KEY is string as prefix keystroke of displayed keymap in created menu on the target mode.
This string passed kbd function, so (kbd \"KEY\").
If nil, all other keymap of global map displayed in created menu.

BIND is string as keystroke to start display created menu.

Example: (one-key-local-create-menu :hook dired-mode-hook :key nil :bind \"?\")
         (one-key-local-create-menu :mode moccur-mode :key nil :bind \"?\")
         (one-key-local-create-menu :mode moccur-grep-mode :map moccur-mode-map :key nil :bind \"?\")
         (one-key-local-create-menu :hook nxml-mode-hook :key \"C-c\" :bind \"C-c ?\")
"
  (let* ((mapnm (gensym)))
    `(progn
       (defvar ,mapnm (when (and (boundp ,map)
                                 (keymapp (symbol-value ,map)))
                        (symbol-name ,map)))
       (cond ((and ,hook
                   (symbolp ,hook))
              (add-hook ,hook (lambda () (one-key-local--create-menu-sentinel ,key ,bind ,mapnm)) t)
              t)
             ((and ,mode
                   (symbolp ,mode)
                   (functionp ,mode))
              (ad-add-advice ,mode
                             (ad-make-advice 'one-key-local-define-help nil t
                                             '(advice lambda ()
                                                      (one-key-local--create-menu-sentinel ,key ,bind ,mapnm)))
                             'after
                             'last)
              (ad-activate ,mode nil)
              t)
             (t
              (message "[OneKeyLocal] Failed create menu"))))))

(defun one-key-local--create-menu-sentinel (key bindkey mapnm &optional modestr)
  (condition-case e
      (let* ((orgmodenm (symbol-name major-mode))
             (modemapnm (or mapnm
                            (concat orgmodenm "-map")))
             (bindkbd (when bindkey
                        (read-kbd-macro bindkey)))
             (cmdnm (one-key-local--get-function-name key modestr))
             (cmdsym (intern-soft cmdnm)))
        (cond ((not cmdsym)
               (let* ((keymaps (one-key-local--read-keymaps (or key modemapnm)))
                      (funcdesc (one-key-local--get-function-description key modestr))
                      (prefixalist (one-key-local--get-prefix-commands keymaps))
                      (reread))
                 (loop for alist in prefixalist
                       for modenm = (car alist)
                       for keystrlist = (cdr alist)
                       do (loop for keystr in keystrlist
                                if (and (stringp keystr)
                                        (not (string= keystr "")))
                                do (progn
                                     (when key
                                       (setq keystr (concat key " " keystr)))
                                     (one-key-local--create-menu-sentinel keystr nil mapnm modenm)
                                     (setq reread t))))
                 (when reread
                   (setq keymaps (one-key-local--read-keymaps (or key modemapnm))))
                 (with-temp-buffer
                   (goto-char (point-min))
                   (one-key-local--insert-template orgmodenm key keymaps cmdnm funcdesc)
                   (emacs-lisp-mode)
                   (indent-region (point-min) (point-max))
                   (eval-buffer))
                 (when bindkbd
                   (local-set-key bindkbd (intern cmdnm)))))
              (bindkbd
               (local-set-key bindkbd cmdsym))))
    (error (message "[OneKeyLocal] %s" (error-message-string e)))))

(defun one-key-local--get-function-name (key &optional modestr)
  (let* ((modenm (replace-regexp-in-string "-mode" "" (or modestr
                                                          (symbol-name major-mode))))
         (title (cond (key (concat modenm "-" (replace-regexp-in-string " " "-" key)))
                      (t   modenm))))
    (concat "one-key-menu-" title)))

(defun one-key-local--get-function-description (key &optional modestr)
  (let* ((ret (capitalize (replace-regexp-in-string "-" " " (or modestr
                                                                (symbol-name major-mode))))))
    (when key
      (setq ret (concat "'" key "' on " ret)))
    ret))

(defun one-key-local--get-prefix-commands (keymaps)
  (with-temp-buffer
    (loop with indent-tabs-mode = t
          with keystrlist
          for kmapinfo in keymaps
          for modenm = (let* ((s (car kmapinfo)))
                         (cond ((stringp s) s)
                               ((symbolp s) (symbol-name s))))
          for kmap = (cdr kmapinfo)
          if (keymapp kmap)
          collect (cons modenm (loop initially (let* ((spoint (point)))
                                                 (insert (substitute-command-keys "\\<kmap>\\{kmap}"))
                                                 (goto-char spoint)
                                                 (forward-line 3)
                                                 (delete-region spoint (point)))
                                     for elem = (split-string (buffer-substring (point-at-bol) (point-at-eol)) "\t+")
                                     for keystr = (replace-regexp-in-string "\\\"" "\\\\\"" (replace-regexp-in-string "\\\\" "\\\\\\\\" (pop elem)))
                                     for keycmd = (pop elem)
                                     while (not (eobp))
                                     do (delete-region (point-at-bol) (point-at-eol))
                                     do (delete-char 1)
                                     if (and (stringp keystr)
                                             (not (string= keystr ""))
                                             (stringp keycmd)
                                             (not (string= keycmd ""))
                                             (or (string-match " " keystr)
                                                 (string-match " " keycmd)))
                                     collect (let* ((e (split-string keystr))
                                                    (keystr (cond ((string-match " " keystr) (pop e))
                                                                  (t                         keystr))))
                                               (when (not (member keystr keystrlist))
                                                 (push keystr keystrlist)
                                                 keystr)))))))

(defun one-key-local--insert-template (orgmodenm key keymaps cmdnm funcdesc)
  (insert (format "(defvar %s-alist nil\n\"The `one-key' menu alist for %s.\")\n\n" cmdnm funcdesc)
          (format "(setq %s-alist\n'(\n" cmdnm))
  (loop with indent-tabs-mode = t
        with keystrlist
        for kmapinfo in keymaps
        for modenm = (let* ((s (car kmapinfo)))
                       (cond ((stringp s) s)
                             ((symbolp s) (symbol-name s))))
        for kmap = (cdr kmapinfo)
        if (keymapp kmap)
        do (loop initially (let* ((spoint (point)))
                             (insert (substitute-command-keys "\\<kmap>\\{kmap}"))
                             (goto-char spoint)
                             (forward-line 3)
                             (delete-region spoint (point)))
                 for elem = (split-string (buffer-substring (point-at-bol) (point-at-eol)) "\t+")
                 for keystr = (replace-regexp-in-string "\\\"" "\\\\\"" (replace-regexp-in-string "\\\\" "\\\\\\\\" (pop elem)))
                 for keycmd = (pop elem)
                 for keydesc = ""
                 for allkeystr = (cond (key (concat key " " keystr))
                                       (t   keystr))
                 while (not (eobp))
                 do (delete-region (point-at-bol) (point-at-eol))
                 do (delete-char 1)
                 if (and (stringp keystr)
                         (not (string= keystr ""))
                         (stringp keycmd)
                         (not (string= keycmd "")))
                 do (progn
                      (setq keydesc (replace-regexp-in-string "-" " " keycmd))
                      (when (and (string-match " " keystr)
                                 (not (string-match " \\.\\. " keystr)))
                        (let* ((e (split-string keystr)))
                          (setq keystr (pop e))
                          (setq keycmd (one-key-local--get-function-name allkeystr modenm))
                          (setq keydesc (one-key-local--get-function-description allkeystr modenm))))
                      (when (not (member keystr keystrlist))
                        (when (string-match " " keycmd)
                          (setq keycmd (one-key-local--get-function-name allkeystr modenm))
                          (setq keydesc (one-key-local--get-function-description allkeystr modenm)))
                        (cond ((intern-soft keycmd)
                               (insert (format "((\"%s\" . \"%s\") . %s)\n" keystr keydesc keycmd)))
                              (t
                               (message "[OneKeyLocal] Not yet create menu '%s' on %s" allkeystr orgmodenm)))
                        (push keystr keystrlist)))))
  (insert "))\n\n")
  (insert (format "(defun %s ()\n\"The `one-key' menu for %s\"\n(interactive)\n(one-key-menu \"%s\" %s-alist))\n"
                  cmdnm funcdesc funcdesc cmdnm)))

(defun one-key-local--read-keymaps (keystroke)
  (let ((v (intern-soft keystroke)))
    (if (and (boundp v)
             (keymapp (symbol-value v)))
        (list (cons (symbol-name major-mode) (symbol-value v)))
      (append (loop for kmap in (minor-mode-key-binding (read-kbd-macro keystroke))
                    collect kmap)
              (list (cons (symbol-name major-mode) (local-key-binding (read-kbd-macro keystroke))))))))


(provide 'one-key-local)
;;; one-key-local.el ends here
