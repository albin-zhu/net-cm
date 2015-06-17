;;; net-cm.el --- 网易云音乐,支持用户登陆
;; Copyright (C) 2015  albin

;; Author: albin <albin@albins-mac.9you.com>
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:
(require 'json)
(require 'assoc)
(require 'url-http)
(require 'button)

(defcustom albin-music-player "mplayer"
  "Player for douban music."
  :type 'string
  :group 'net-cm)

(defconst net-cm-buffer-name "Emacs云音乐" "")
(defconst image-dirctory "~/Pictures/Emacs云音乐/" "")
(defconst batch-url "http://music.163.com/batch?%2Fapi%2Fdiscovery%2Fhotspot=%7B%22limit%22%3A12%7D" "获取歌单的api地址")
(defconst login-url "http://music.163.com/api/login/token/refresh" "登陆地址")
(defconst playlist-detail "http://music.163.com/api/playlist/detail?id=%d&updateTime=-1" "歌单详情")
(defconst serarch-songs "http://music.163.com/api/search/pc" "查找歌曲")
(defconst song-detail "http://music.163.com/api/song/detail/" "歌曲详情")
(defconst my-playlist "http://music.163.com/api/user/playlist/?offset=%d&limit=6&uid=28825388" "我的收藏") 
(defconst 歌曲 1 "")
(defconst 专辑 10 "")
(defconst 歌手 100 "")
(defconst 歌单 1000 "")
(defconst 用户 1002 "")
(defconst mv 1004 "")
(defconst 歌词 1006 "")
(defconst 主播电台 1009 "")
(defvar player-thread nil "")

(defvar preview-list-songs nil "")
(defvar current-playlist nil "")
(defvar current-playlist-id 0 "")
(defvar current-index 0 "")

(defun insert-artist(data)
  (let(
       (singers
	(cdr (assoc 'artists data))))
    (insert-string "(")
    (let ((num (length singers)))
      (dotimes (i num)
	(insert-string
	 (concat "" 
		 (cdr (assoc 'name (elt singers i)))))))
    (insert-string ")")))

(defun like-this-song()
  (interactive)
  (if current-playlist
      (progn
	(setq url-request-data  (format "trackId=%d&like=true&time=0" (cdr (assoc 'id(elt current-playlist current-index)))))
	(if (= (cdr (assoc 'code (json-loads (visit-163 "http://music.163.com/api/song/like" "POST")))) 502)
	    (progn
	      (setq url-request-data  (format "trackId=%d&like=false&time=0" 
					      (cdr (assoc 'id(elt current-playlist current-index)))))
	      (message "不在爱了")
	      (visit-163 "http://music.163.com/api/song/like" "POST")))
	(message "这首歌好听")
	)))

(defun fav-list()
  (interactive)
  (if current-playlist-id
      (progn
	(if (= (cdr (assoc 'code
			   (json-loads
			    (visit-163
			     (format 
			      "http://music.163.com/api/playlist/subscribe/?id=%d"
			      current-playlist-id))))) 501)
	    (progn
	      (setq url-request-data 
		    (format "trackId=%d&like=false&time=0" (cdr (assoc 'id(elt current-playlist current-index)))))
	      (message "不在爱了")
	      (visit-163 (format "http://music.163.com/api/playlist/unsubscribe/?id=%d" current-playlist-id))))
	(message (concat current-playlist-name "添加到收藏"))
	)))

(defun render-result(type keyword)
  (setq search-data (concat "hlpretag=%3Cspan%20class%3D%22s-fc2%22%3E&hlposttag=%3C%2Fspan%3E&s=" 
			    			   (url-hexify-string keyword)
						   "&offset=0&total=true&limit=100&type=1" ))
    (if (string-match net-cm-buffer-name (buffer-name)) 
	(progn
	  (setq url-request-data   search-data)
	  (defvar data (json-loads (visit-163 serarch-songs "POST")))
	  (setq current-playlist (cdr (assoc 'songs (cdr (assoc 'result data)))))
	  (insert (propertize
		   "==================================查询结果==================================================================\n\n" 'face '(:foreground "Green")))
	  (let ((i 0)
		(num (length current-playlist)))
	    (while (< i num)
	      (insert-text-button (format "%s\n" (cdr (assoc 'name (elt current-playlist i)))) 'action (lambda(x)(play-with-index (button-get x 'index))) 'index i)
	      (setq i (+ i 1))
	      )
	    ))))

(defun render ()
  (interactive)
  (with-current-buffer (get-buffer net-cm-buffer-name)
    (setq buffer-read-only nil)
    (erase-buffer)
    (insert-string "Emacs云音乐 - created by albin\n")
    (insert (propertize
	     "\n=====================================收藏歌单=======================================================" 'face '(:foreground "Green")))

    (setq num-of-fav-playlists (length my-favourite-playlist))
    (setq i 0)
    (while (< i num-of-fav-playlists)
      (if (zerop (mod i 3))
	  (insert "\n"))
      (setq playlist (elt my-favourite-playlist i))
      (if (= (cdr (assoc 'id playlist)) current-playlist-id)
	  (insert (propertize  (cdr (assoc 'name playlist)) 'face '(:foreground "Green")))
	(insert-button (format "%s" (cdr (assoc 'name playlist))) 'action (lambda (x) (get-playlist-songs (button-get x 'id))) 'id  playlist))
      (insert "\t\t")
      (setq i (+ i 1)))
    (insert (propertize
	     "\n====================================================================================================" 'face '(:foreground "Green")))
    
    (insert (propertize
	     "\n\n=====================================推荐歌单=======================================================" 'face '(:foreground "Green")))
    
    (setq num-of-recommend-playlists (length recommend-playlist))
    (setq i 0)
    (while (< i num-of-recommend-playlists)
      (if (zerop (mod i 3))
	  (insert "\n"))
      (setq playlist (elt recommend-playlist i))
      (if (= (cdr (assoc 'id playlist)) current-playlist-id)
	  (insert  (propertize (format "(%d) %s" (cdr (assoc 'playcount playlist))  (cdr (assoc 'name playlist))) 'face '(:foreground "Green")))
	(insert-button (format "(%d) %s" (cdr (assoc 'playcount playlist)) (cdr (assoc 'name playlist)))  'action (lambda (x) (get-playlist-songs (button-get x 'id))) 'id playlist))
      (insert "\t\t")
      (setq i (+ i 1)))
    (insert (propertize
	     "\n====================================================================================================\n\n" 'face '(:foreground "Green")))
    
    (goto-char (point-min))
    (insert (propertize
	     "==================================播放列表==================================================================\n\n" 'face '(:foreground "Green")))
    (let ((i 0)
	  (num (length current-playlist)))
      (while (< i num)
	(if (= i current-index)
	    (insert (propertize (format "%s" (cdr (assoc 'name (elt current-playlist i)))) ' face '(:foreground "Green")))
	  (insert-text-button (format "%s" (cdr (assoc 'name (elt current-playlist i)))) 'action (lambda(x)(play-with-index (button-get x 'index))) 'index i))
	(insert-artist (elt current-playlist i))
	(insert-string "\n")
	(setq i (+ i 1))))

    (insert 
     (propertize
      "\n====================================================================================================\n\n"
      'face '(:foreground "Green")))
    
    (goto-char (point-max))
    (let ((song (elt current-playlist current-index)))
      (let (
	   (num-of-songs (length current-playlist))
	   (name (cdr (assoc 'name song)))
	   (pic-url (cdr (assoc 'picUrl (cdr (assoc 'album song)))))
	   (id (cdr (assoc' id song))))
	(insert-string "当前正在播放:")
	(insert (propertize (format "%s" name) ' face '(:foreground "Green")))
	(insert-artist song)
	(insert-string "\n")
	(insert-image-async pic-url (current-buffer) (point-max) id)
	)
      )
    (set buffer-read-only t)))

(defun search-by-singer(s)
  (interactive "s歌手:")

  )

(defun search-by-song(s)
  (interactive "s歌名:")
  (render-result 100 s)
)

(defun search-by-album(a)
  (interactive "s专辑:")

)

(defun search-by-list(l)
  (interactive "s歌单:")
)

(defun search-by-radio(r)
  (interactive "s电台:")

)

(defun seek-forward ()
  (interactive)
  (process-send-string player-thread "seek 20\n"))

(defun seek-backward ()
  (interactive)
  (process-send-string player-thread "seek -20\n"))


(defun get-playlist-songs (list)
  (setq current-playlist-id  (cdr (assoc 'id list)))
  (setq current-playlist-name  (cdr (assoc 'name list)))
  (let ((data (json-loads (visit-163 (format playlist-detail current-playlist-id)))))
    (setq code (cdr (assoc 'code data)))
    (if (not (= code 200))
	(message "未能获取歌单详情")
      (setq current-playlist (cdr (assoc 'tracks (cdr (assoc 'result data)))))))
  (play-with-index 0)
)

;; user-server
(defun visit-163(url &optional method callback callback-args)
  (print url)
  (if method
      (setq url-request-method method)
  (setq url-request-method "GET"))

  (setq url-cookie-untrusted-urls '(".*"))
  (setq url-request-extra-headers
	'(
	  ("Host" . "music.163.com")
	  ("Content-Type" . "application/x-www-form-urlencoded")
	  ("Connection" . "keep-alive")
	  ("Cookie"."*****") ;; 自己的cookie
	  ("Accept" . "*/*")
	  ("User-Agent" . "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.76.4 (KHTML, like Gecko) Version/7.0.4 Safari/537.76.4")
	  ("Referer" . "http://music.163.com/")
	  ("Accept-Language" . "en-us")
	  ) )
  (if callback
      (url-retrieve url callback callback-args)
    (url-retrieve-synchronously url))
 )

(defun get-recommend ()
  (let ((data (json-loads(visit-163 batch-url))))
    (setq code (cdr (assoc 'code data)))
    (if (not (= code 200))
	(message "获取信息失败")
      (setq recommend-playlist (cdr (assoc 'data (cdr
						  (assoc '/api/discovery/hotspot data)))))))
  )

(defun get-my-favourite (offset) 
 (let ((data (json-loads(visit-163 (format my-playlist offset)))))
   (setq code (cdr (assoc 'code data)))
   (if (not (= code 200))
       (message "获取信息失败")
     (setq my-favourite-playlist (cdr (assoc 'playlist data))))
   (setq more-favoirite-p (string= (cdr (assoc 'more data)) "true"))
   )
  (get-recommend)
  )

(defun json-loads (buffer) 
  (setq buffer-file-coding-system 'no-conversion)
  (with-current-buffer buffer
    (goto-char (point-min))
    (if (not (search-forward "{"))
	(message "好像不是json数据")
      (setq json-start (line-beginning-position))
      (setq json-end (line-end-position))
      (json-read-from-string (decode-coding-string (buffer-substring-no-properties json-start json-end) 'utf-8)))
    )
)

;; 同名函数, 自动加载 
(defun net-cm () 
  (interactive)
  (cond
   ((buffer-live-p (get-buffer net-cm-buffer-name))
    (switch-to-buffer net-cm-buffer-name))
   (t
    (set-buffer (get-buffer-create net-cm-buffer-name))
    (net-cm-mode)))
  (switch-to-buffer net-cm-buffer-name)

  (get-my-favourite 0)
  (render)
  (setq buffer-read-only t)
)

(defvar map-keys nil
  "docstring")
(setq map-keys
      (let ((map (make-sparse-keymap)))
        (define-key map "s" 'search-by-song)
	(define-key map "n" 'next-song)
	(define-key map "p" 'prev-song)
	(define-key map "g" 'render)
	(define-key map "l" 'like-this-song)
	(define-key map "f" 'fav-list)
	(define-key map ">" 'seek-forward)
	(define-key map "<" 'seek-backward)
	map))

(defun net-cm-mode()
  "控制这个buffer"
  (kill-all-local-variables)
  (use-local-map map-keys)
  (setq major-mode 'net-cm-mode)
  (setq mode-name "Emacs-云音乐")
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (setq buffer-undo-list t)
  (run-hooks 'net-music-mode-hook)
)

(defun douban-music-send-url (url &optional url-args callback callback-args)
  "Fetch data from douban music server."
  (let ((url-request-method "GET"))
    (if url-args
        (setq url-request-data (mapconcat #'(lambda (arg)
                                              (concat (url-hexify-string (car arg))
                                                      "="
                                                      (url-hexify-string (cdr arg))))
                                          url-args "&")))
    (if callback
        (url-retrieve url callback callback-args)
      (url-retrieve-synchronously url))))

(defun insert-image-async (url insert-buffer insert-point image-id)
  "Insert image file async"
  (douban-music-send-url
   url
   nil
   #'(lambda (status &rest args)
       (let ((insert-buffer (nth 0 args))
             (insert-point (nth 1 args))
             (image-file  (format "%s%d.jpg" image-dirctory (nth 2 args))))
         (setq buffer-file-coding-system 'no-conversion)
         (goto-char (point-min))
         (let ((end (search-forward "\n\n" nil t)))
           (when end
             (delete-region (point-min) end)
             (write-region (point-min) (point-max) image-file nil 0)))
         (kill-buffer)
         (with-current-buffer insert-buffer
           (save-excursion
             (let ((buffer-read-only nil))
               (condition-case err
                   (let ((img (progn
                                (clear-image-cache image-file)
                                (create-image image-file nil nil :relief 2 :ascent 'center :width 80))))
                     (goto-char insert-point)
                     (insert-image img)
                     img)
                 (error
                  (when (file-exists-p image-file)
                    (delete-file image-file))
                  nil)))))))
   (list insert-buffer insert-point image-id )))

(defun play-or-pause()
  (interactive)
  (if (string-match play-status "playing")
      (progn
	(setq play-status "pause")
	(process-send-string player-thread "pause\n"))
    (progn
      (setq play-status "playing")
      (process-send-string player-thread "play\n")))
)

(defun kill-player ()
  (interactive)
  (when (and player-thread 
	     (process-live-p player-thread))
    (delete-process player-thread)
    (setq player-thread nil))
)

(defun get-mp3-url(index)
  (print current-playlist)
  (if current-playlist
      (cdr (assoc 'mp3Url (elt current-playlist index)))
    (message "没有播放的曲目")
    )
  )

(defun play-with-index(index)
  (interactive "nIndex:")
  (kill-player)
  (setq current-index index)
  (setq mp3-url (get-mp3-url index))
  (message mp3-url)
  (setq player-thread (start-process "albin-music-proc" nil albin-music-player mp3-url))
  (set-process-sentinel player-thread 'after-song)
  (setq play-status "playing")
  (render)
)

(defun after-song(player index)
  (when (string-match  "\\(finished\\|Exiting\\)" index)
    (next-song))
  )

(defun next-song ()
  (interactive)
  (if (>= current-index (- (length current-playlist) 1))
      (play-with-index 0)
    (play-with-index (+ current-index 1)))
)

(defun prev-song()
  (interactive)
  (if (< current-index 1)
      (play-with-index (- (length current-playlist) 1))
    (play-with-index (- current-index 1)))
)
   
(provide 'net-cm-mode)
;;; net-cm.el ends here
