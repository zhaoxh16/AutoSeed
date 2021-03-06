#!/bin/bash
# FileName: get_desc/info.sh
#
# Author: rachpt@126.com
# Version: 3.0v
# Date: 2019-01-24
#
#-------------------------------------#
# 复制 nfo 文件内容至简介，如果没有 nfo 文件，
# 则采用 mediainfo 生成主文件的编码信息至临时文件。
# 自动判断 是否有 nfo 文件，以及 nfo 文件是否下载完成。
#-------------------------------------#

# 使用 ffmpeg 获取视频缩略图
gen_screenshots() {
  local step total file screen_file size ratio row column
  screen_file="${ROOT_PATH}/tmp/autoseed-$(date '+%s%N').jpg"
  file="$max_size_file"
  size=500  # 单个缩略图宽 500 pix
  row=4     # 行数
  column=3  # 列数
  ratio="$($mediainfo "$file" --Output="Video;%FrameRate%")"
  total="$($mediainfo "$file" --Output="Video;%FrameCount%")"
  # 首末去掉 1500 帧，等分
  step=$(echo "($total - 3000)/(($row * $column) * $ratio)"|bc)
  for ((i=1;i<=(row * column);i++)); do
    # 多线程
    ( $ffmpeg -ss "$(echo "(1500/$ratio)+($step * $i)"|bc)" -i "$file" -vframes 1 \
    -vf "scale=$size:-1" "${ROOT_PATH}/tmp/thumbnail-$(printf "%03d" $i).jpg" -y 2>/dev/null ) &
  done
  wait # 等待所有 截图完成
  $ffmpeg -i "${ROOT_PATH}/tmp/thumbnail-%03d.jpg" -filter_complex \
    "tile=3x4:nb_frames=0:padding=5:margin=5:color=random" "$screen_file" -y 2>/dev/null
  \rm -f "${ROOT_PATH}/tmp"/thumbnail-[0-9]*.jpg # 通配符，不能使用引号

  # 图片上传
  unset sm_url byr_url
  sm_url="$(http --verify=no --timeout=25 --ignore-stdin -bf POST \
    "$upload_poster_api" smfile@"$screen_file" "$user_agent"|grep -Eo "\"url\":\"[^\"]+\""| \
    awk -F "\"" '{print $4}'|sed 's/\\//g')"
  # 备用图床
  [[ ! $sm_url ]] && sm_url="$(http --pretty=format --verify=no --timeout=25 -bf \
     --ignore-stdin POST "$upload_poster_api_2" image@"$screen_file" "$user_agent"| \
     grep -Eo "\"link\":\"[^\"]+\""|awk -F "\"" '{print $4}'|sed 's/\\//g')"
  [[ $enable_byrbt == yes ]] && byr_url="$(http --verify=no --ignore-stdin \
    --timeout=25 -bf POST "$upload_poster_api_byrbt" upload@"$screen_file" "$user_agent" \
    "$cookie_byrbt"|grep -Eio "https?://[^\'\"]+"|sed "s/http:/https:/g")"
  sleep 0.5 && \rm -f "$screen_file"
}

#-------------------------------------#
# 读取主文件以获得info，提前生成简介将失效
generate_info_local() {
  # 种子文件绝对路径
  local main_file_dir="${one_TR_Dir}/${one_TR_Name}"
  debug_func "info:file-dir[$main_file_dir]"  #----debug---
  # 使用 mediainfo 生成种子中体积最大文件的 iNFO
  max_size_file="$(\find "$main_file_dir" -type f -exec stat -c "%s %n" {} \;| \
      sort -nr|head -1|sed -E 's/^[0-9 ]+//')"
  debug_func "info:max-file[$max_size_file]"  #----debug---
  # 本地简介大小为零
  if [ ! -s "$source_desc" ]; then
    local info_generated="$($mediainfo "$max_size_file"| \
      sed '/Unique/d;/Encoding settings/d;/Complete name/d;/Writing library/d;/Writing application/d')"
  else
    local info_generated="$(\cat "$source_desc")"
  fi
  # 缩略图
  gen_screenshots
  # 存档
  if [[ $byr_url || $sm_url ]]; then
    echo -e "$info_generated\n\n[b]以下是[url=https://github.com/rachpt/AutoSeed]AutoSeed[/url]自动完成的截图，不喜勿看。[/b]\n"${max_size_file##*/}"\n[img]$sm_url[/img]" > "$source_desc"
    debug_func "info:screens-gened[$sm_url]"  #----debug---
    # byrbt bbcode to html
    [[ $enable_byrbt == yes && $byr_url ]] && {
    echo "$info_generated"|sed 's/ /\&nbsp; /g;s!$!&<br />!g' > "$source_html" 
    echo "<br /><br /><stong>以下是<a href=\"https://github.com/rachpt/AutoSeed\">AutoSeed</a>自动完成的截图，不喜勿看。</strong><br />${max_size_file##*/}<br />" >> "$source_html" # 追加至末尾
    echo "<img src=\"$byr_url\" style=\"width: 900px;\" /> <br />" >> "$source_html" # 追加至末尾
    debug_func "info:screens-byrbt[$byr_url]"  #----debug---
    }
  else
    # byrbt bbcode to html
    [ "$enable_byrbt" = 'yes' ] && [ -s "$source_desc" ] && \
      sed 's/ /\&nbsp; /g;s!$!&<br />!g' "$source_desc" > "$source_html" 
  fi
}

# 首先判断是否有 nfo 文件，以及nfo是否下载完成
read_info_file() {
  if [ ! "$one_TR_Dir" ]; then
      debug_func "info:one_TR_Dir.0[$one_TR_Dir]"  #----debug---
      one_TR_Dir="$(find "$default_FILE_PATH" -name \
          "$one_TR_Name" 2> /dev/null|head -1)"
      one_TR_Dir="${one_TR_Dir%/*}"
  fi
  debug_func "info:one_TR_Dir[$one_TR_Dir]"  #----debug---

  if [ "$one_TR_Dir" ]; then
    local nfo_file_size nfo_file_path nfo_file_downloaded   
    nfo_file_size=$("$tr_show" "$torrent_Path"| \
      grep -Eio '\.nfo \([0-9\. ]+[kb]+\)'|grep -Eo '[0-9]+\.?[0-9]*')
    if [[ $nfo_file_size ]]; then
      nfo_file_path="$(find "${one_TR_Dir}/${one_TR_Name}" -iname '*.nfo'|head -1)"
      nfo_file_downloaded=$(stat --format=%s "$nfo_file_path")
      if [[ $nfo_file_downloaded ]]; then
        local judge_download_nfo judge_nfo_file charset
        judge_download_nfo=$((nfo_file_downloaded/100))
        judge_nfo_file=$(echo "$nfo_file_size * 10"|bc|awk -F '.' '{print $1}')
        if [ "$judge_download_nfo" -eq  "$judge_nfo_file" ]; then
          charset="$(file -i "$nfo_file_path"|sed 's/.*charset=//')" 
          [[ ! $charset ]] && charset='iso-8859-1'
          iconv -f "$charset" -t UTF-8 -c "$nfo_file_path"| \
            sed -E "/^ú+$/d" > "$source_desc"
          debug_func 'info:get-nfo-file'  #----debug---
        fi
        unset charset 
      fi
    else
      debug_func 'info:use-main-file!'  #----debug---
    fi
    # gen from main file and gen screens
    generate_info_local
  fi
  debug_func 'info:exit'  #----debug---
  unset sm_url byr_url info_generated
}

#-------------------------------------#
