title: Emacs网易云音乐
date: Wed Jun 17 16:19:23 2015
author: albin
tags:
- 笔记
- elisp
- emacs
categories:
- 笔记
---

#在Emacs播放音乐 #
 emacs可以调用mplayer来播放音乐,已经有很多实现的方式来实现emacs下听音的mode.时下最热门的音乐软件莫过于网易云音乐,今天就来实现一个简单的网易云音乐Emacs版本.
 ## 工具准备 ##
 * charles 查看网易云音乐的API
 * 网易云音乐客户端 没它也没法截包
 * emacs 咱就是在这里边整这个事的
 * mplayer 播放音乐
 
## 播放url ##
确定mplayer已经装好,在osx下
```shell
brew install mplayer
```
然后把路径添加下emacs的path下

### 调用mplayer###
```
start-process
启动一个新的子进程去跑一个软件或命令
``` lisp
(start-process "my-process" "foo" "sleep" "100")
	⇒ #<process my-process>)
(start-process "my-process" "foo" "ls" "-l" "/bin"
	⇒ #<process my-process<1>>
```

那么可以用它去启动mplayer
```lisp
;; 播放当前列表的第几首
(defun play-with-index(index)
  (interactive "nIndex:") ;; M-x 可以调用该函数, 并且可以传入一个整型
  (kill-player)  ;; 关闭之前播放的音乐
  (setq current-index index)
  (setq mp3-url (get-mp3-url index)) ;; 拿到播放地址 返回类似 http://xxx.xxx.xxx/xxx/xxx/xxx.mp3
  (message mp3-url) ;; minibuf 通知地址
  (setq player-thread (start-process "albin-music-proc" nil albin-music-player mp3-url))
  (set-process-sentinel player-thread 'after-song) ;; 设置状态监听
  (setq play-status "playing")
  (render))
```
### 监听mplayer的状态 ###
elisp的函数命名真的是很好玩,不像我们现在的风格,比如set-process-sentinel,翻译过来应该是设置进程哨兵.用一个哨兵去监听这个进程.上面提到的after-song
```lisp
(defun after-song(player status)
  (when (string-match  "\\(finished\\|Exiting\\)" status)
    (next-song))) ;; 播放下一首歌
```
### 播放\暂停\上下首###
```lisp
(defun next-song ()
  (interactive)
  (if (>= current-index (- (length current-playlist) 1))
      (play-with-index 0)
    (play-with-index (+ current-index 1))))

(defun prev-song()
  (interactive)
  (if (< current-index 1)
      (play-with-index (- (length current-playlist) 1))
    (play-with-index (- current-index 1))))

(defun play-or-pause()
  (interactive)
  (if (string-match play-status "playing")
  (progn
	(setq play-status "pause")
	(process-send-string player-thread "pause\n"))
    (progn
      (setq play-status "playing")
      (process-send-string player-thread "play\n"))))
```

# 网易云音乐 基础API #
以下是这次我要用到的一些基础api,登陆暂用不上.我是直接在每条request的header中写了cookie,这个cookie从web上,或者客户端里都能拿到的,最简单的是charles或者chrome的截包工具抓取一下就可以.
```lisp
(defconst batch-url "http://music.163.com/batch?%2Fapi%2Fdiscovery%2Fhotspot=%7B%22limit%22%3A12%7D" "批量api地址") ;;获取歌单
(defconst login-url "http://music.163.com/api/login/token/refresh" "登陆地址")
(defconst playlist-detail "http://music.163.com/api/playlist/detail?id=%d&updateTime=-1" "歌单详情")
(defconst serarch-songs "http://music.163.com/api/search/pc" "查找歌曲")
(defconst song-detail "http://music.163.com/api/song/detail/" "歌曲详情")
(defconst my-playlist "http://music.163.com/api/user/playlist/?offset=%d&limit=6&uid=28825388" "我的收藏")
```
```lisp
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
	  ("Cookie"."xxxxxxx") ;; 截取一下就ok
	  ("Accept" . "*/*")
	  ("User-Agent" . "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.76.4 (KHTML, like Gecko) Version/7.0.4 Safari/537.76.4")
	  ("Referer" . "http://music.163.com/")
	  ("Accept-Language" . "en-us")
	  ) )
  (if callback
      (url-retrieve url callback callback-args)
    (url-retrieve-synchronously url)))
```
 这些接口返回的数据全是json格式,我们可以用el-get-install json来安装json包
 ```lisp
(require 'json_
```
```lisp
 (defun json-loads (buffer) 
  (setq buffer-file-coding-system 'no-conversion) 
  (with-current-buffer buffer
    (goto-char (point-min)) 
    (if (not (search-forward "{"))
	(message "好像不是json数据") ;; 去掉header,url-retrieve会把header信息也写进buffer中
      (setq json-start (line-beginning-position))
      (setq json-end (line-end-position))
      (json-read-from-string (decode-coding-string (buffer-substring-no-properties json-start json-end) 'utf-8)))))
```
比如我们要调取网易推荐的歌单
```lisp
(defun get-recommend ()
  (let ((data (json-loads(visit-163 batch-url))))
    (setq code (cdr (assoc 'code data)))
    (if (not (= code 200)) ;; 判断code
	(message "获取信息失败")
      (setq recommend-playlist
	  (cdr
	  (assoc 'data
		  (cdr (assoc '/api/discovery/hotspot data))))))))
```
## 显示 ##
这个问题就仁者见仁了,比如我在写这一篇的时候觉得 <<我在人民广场吃着炸鸡>>挺好听的,按下键盘" C-c l "也就是 like-this-song.或者"C-c n"下一首.这些看习惯绑定.

# 效果图 #
![我在人民广场吃着炸鸡](/img/net-cm.png)
![这首歌好听](/img/net-cm-good.png)

# 另见 #
[albin.ga](http://albin.ga)
