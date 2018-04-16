;;; counsel-term.el --- Ivy-based term-mode utils

;; Copyright 2018 Benjamin Lindqvist

;; Author: Benjamin Lindqvist <benjamin.lindqvist@gmail.com>
;; Maintainer: Benjamin Lindqvist <benjamin.lindqvist@gmail.com>
;; URL: https://github.com/tautologyclub/counsel-term-history
;; Version: 0.01

;; This file is part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Some hacky but extremely convenient functions for making life inside
;; term-mode easier.  All of them make use of two things: first, the excellent
;; 'ivy-read' API and second, the fact that you can send raw control characters
;; such representing C-k, C-u, etc to your terminal using
;; 'term-send-raw-string'.
;;
;; A summary:

;; counsel-term-history -- A simple utility that completing-reads your
;; ~/.bash_history (or whatever other file you want, really) and sends the
;; selected candidate to the terminal.  To get going, bind 'counsel-term-history
;; to some nice stroke in your term-mode-map, C-r comes quite naturally to
;; mind.

;; counsel-term-cd -- Recursively find a directory, starting at $PWD, and cd to
;; it.

;; counsel-term-ff -- Find file with completion in current dir.  If it's a
;; directory, cd to it and call counsel-term-ff again.  If not, open it using
;; find-file.  The recursion is really badly implemented ATM using elisp sleep
;; which results in a flickering minibuffer.  Advice appreciated :
;; Note: This package has no association with counsel or ivy apart from using
;; the ivy api and kinda feeling lika a counsel package.  The author admits to
;; a slighy fanboy-ism towards their creator however -- support him on Patreon!
;; More instructions on his site, oremacs.com.

;;; Code:

(require 'ivy)
(require 'term)
(require 'cl)

;; switch between multi-term buffers using counsel
;-------------------------------------------------------------------------------
(defun counsel-term-switch ()
  (interactive)
  (let ((ivy-ignore-buffers nil))
    (add-hook 'ivy-ignore-buffers 'counsel-term--ignore-non-term-buffers)
    (ivy-switch-buffer)))

(defun counsel-term--ignore-non-term-buffers (bufname)
  "Return t if BUFNAME does not correspond to term-mode buffer."
  (let ((buf (get-buffer bufname)))
    (not (and buf (eq (buffer-local-value 'major-mode buf) 'term-mode)))))
;-------------------------------------------------------------------------------


;; switch between multi-term buffers using counsel
;-------------------------------------------------------------------------------
(defun counsel-term--ignore-non-term-buffers (bufname)
  "Return t if BUFNAME does not correspond to term-mode buffer."
  (let ((buf (get-buffer bufname)))
    (not (and buf (eq (buffer-local-value 'major-mode buf) 'term-mode)))))

(defun counsel-term-switch ()
  (interactive)
  (let ((ivy-ignore-buffers nil))
    (add-hook 'ivy-ignore-buffers 'counsel-term--ignore-non-term-buffers)
    (ivy-switch-buffer)))
;-------------------------------------------------------------------------------


;; Recursive dir-finder, subject to improvements of course :)
;-------------------------------------------------------------------------------
(defun counsel-term-cd-function (dirstring)
  "Use unix util find to recursively search for a subdir matching DIRSTRING."
  (if (< (length dirstring) 2)
      (counsel-more-chars 2)
    (counsel--async-command
     (concat "find -type d 2>/dev/null | grep " dirstring " || echo "))
    '("" "working...")))

(defun counsel-term-cd-action (cand)
  "Clear input, then cd to CAND using term."
  (interactive)
  (term-send-raw-string (concat "cd " cand "")))

(defun counsel-term-cd ()
  "Recursively find directories and cd to them from term."
  (interactive)
  (ivy-read "cd: " 'counsel-term-cd-function
            :dynamic-collection t
            :action 'counsel-term-cd-action
            :unwind #'counsel-delete-process
            :caller 'counsel-term-cd))
;-------------------------------------------------------------------------------


;; Pseudo-dired for people who kinda prefer the terminal
;-------------------------------------------------------------------------------
(defcustom counsel-term-ff-initial-input "^"
  "Initial input for counsel-term-ff."
  :type 'string
  :group 'counsel-term)

(custom-set-variables
 '(counsel-term-ff-initial-input ""))
(defun counsel-term-ff--action (cand)
  "If CAND is a dir, cd to it; else open it with 'find-file'."
  (with-ivy-window
    (if (string-match-p "/$" cand)
	(progn    ;; super ugly+bad, gotta be a better way
	  (let ((cur-dir default-directory))
	    (term-send-raw-string (concat " cd " cand ""))
	    (while (eq cur-dir default-directory)
	      (sit-for 0 1 t))
	    (counsel-term-ff)))
      (find-file cand))))

(defun counsel-term-ff--candidates ()
  "Moo say teh cow."
  (split-string
   (concat
    (shell-command-to-string "ls -d .?*/ 2> /dev/null")
    (shell-command-to-string "ls -d */ 2> /dev/null")
    (shell-command-to-string "ls -p | grep -v /"))
   "\n" t))

(defun counsel-term-ff ()
  "From term-mode, find file and open it in EMACS, or cd to it in term."
  (interactive)
  (let ((ivy-fixed-height-minibuffer t)
	(ivy-case-fold-search t))
    (ivy-read
     default-directory         (counsel-term-ff--candidates)
              :initial-input    counsel-term-ff-initial-input
              :action          'counsel-term-ff--action
              :caller          'counsel-term-ff)))

(defface counsel-term-ff-dir-face '((t :inherit 'font-lock-function-face))
  "Face for directories in counsel-term-ff."
  :group 'counsel-term)

(defun counsel-term-ff--transformer (str)
  "Change color if STR is a directory."
  (if (string-match-p "/$" str)
      (propertize str 'face 'counsel-term-ff-dir-face)
    str))
(ivy-set-display-transformer 'counsel-term-ff 'counsel-term-ff--transformer)
;-------------------------------------------------------------------------------


;; Grep your command line history
;-------------------------------------------------------------------------------
(defcustom counsel-th-history-file "~/.bash_history"
  "The location of your history file (tildes are fine)."
  :type 'string
  :group 'counsel-term)

(defcustom counsel-th-filter "^\\(cd\\|ll\\|ls\\|\\\.\\\.\\|pushd\\|popd\\)"
  "Regex filter for the uninteresting lines in the history file."
  :type 'string
  :group 'counsel-term)

(defcustom counsel-th-initial-input "^"
  "Initial input for counsel-term-history."
  :type 'string
  :group 'counsel-term)

(defun counsel-th--read-lines (file)
  "Make a reversed list of lines in FILE, applying regex counsel-th-filter."
  (with-temp-buffer
    (insert-file-contents file)
    (remove-if (lambda (x) (string-match counsel-th-filter x))
               (reverse (split-string (buffer-string) "\n" t)))))

(defun counsel-th--action (cand)
  "Send CAND to term prompt, without executing."
  (term-send-raw-string (concat "" cand)))

(defun counsel-term-history--initial-input-function ()
  "Check if term-prompt-regexp has been set and use it if so."
  (if (string= "" term-prompt-regexp)
      counsel-th-initial-input
    (concat counsel-th-initial-input (term-get-old-input-default))))

(defun counsel-term-history ()
  "You know, do stuff."
  (interactive)
  (ivy-read "History: "
            (counsel-th--read-lines (expand-file-name counsel-th-history-file))
            :initial-input      (counsel-term-history--initial-input-function)
            :action             'counsel-th--action
            ))
;-------------------------------------------------------------------------------


;; One-stroke 'cd ..', with redo
;-------------------------------------------------------------------------------
(defun term-downdir ()
  "Shut up."
  (interactive)
  (term-send-raw-string " pushd $PWD > /dev/null; cd .."))

(defun term-updir ()
  "Shut up."
  (interactive)
  (term-send-raw-string " popd > /dev/null 2>&1"))
;-------------------------------------------------------------------------------


(provide 'counsel-term)
;;; counsel-term.el ends here
