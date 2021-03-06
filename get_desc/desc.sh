#!/bin/bash
# FileName: get_desc/desc.sh
#
# Author: rachpt@126.com
# Version: 3.0v
# Date: 2019-01-11
#
#-------------------------------------#
# 调函数，生成简介
# 提前生成简介，post，重编辑会用到该文件
#-------------------------------------#
# 最后发布前会再次重命名为简单的名字减少莫名其妙的bug。
# dot_name即点分隔名，用作 0day 名，以及构成保存简介文件名。
dot_name="$(echo "$org_tr_name"|sed 's/[^ -z]//g')"    # 删除所有汉字
debug_func "desc:dot-name.0[$dot_name]"     #----debug---
# name 包含10个以上英文字符，则使用其作为0day名，否则使用部分主文件名
if [[ $(echo "$dot_name"|sed 's/[\. 0-9]//g'|awk '{print length($0)}') -lt 10 ]]; then
  #---special for non-standard 0day-name---#
  dot_name="$("$tr_show" "$torrent_Path"|grep -A10 'FILES'| \
    grep -Ei '[\.0-9]+[ ]*(GB|MB)'|grep -Eio "[-\.\'a-z0-9\!@_ ]+"|tail -2| \
    head -1|sed -r 's/^[\. ]+//;s/\.[a-z4 ]{2,5}$//i'| \
    sed -r 's/\.sample//i;s/[ ]+/./g')" && \
    debug_func "desc:dot-name.2[$dot_name]"  #----debug---
else
  # remove suffix name
  dot_name="$(echo "$dot_name"|sed -E 's/[ ]+/./g;s/\.{2,}/./g;s/\.[a-z4]{2,4}$//i;;s/^\.//')"
  debug_func "desc:dot-name.1[$dot_name]"    #----debug---
fi

source_desc="${ROOT_PATH}/tmp/${org_tr_name}_desc.txt"
# byrbt, html format
[ "$enable_byrbt" = 'yes' ] && \
  source_html="${ROOT_PATH}/tmp/${org_tr_name}_html.txt"
# tjupt, deal with images
[ "$enable_tjupt" = 'yes' ] && \
  source_desc2tjupt="${ROOT_PATH}/tmp/${org_tr_name}_desc2tjupt.txt"

#---to log and edit.sh---#
if [ -z "$source_site_URL" ]; then
    debug_func 'desc:get-soure'       #----debug---
    get_source_site                   # get_desc/detail_page.sh
else
    debug_func 'desc:get-source[0]'   #----debug---
    set_source_site_cookie            # get_desc/detail_page.sh
fi

#---if not exist desc file---#
if [ ! -s "$source_desc" ]; then
    debug_func 'desc:no-source-info'  #----debug---
    # 自定义发布规则
    my_dupe_rules                     # get_desc/customize.sh
    # 尝试搜索原种简介，以获取 iNFO 以及 screens
    form_source_site_get_Desc         # get_desc/detail_page.sh
    # generate info? 
    if [ ! -s "$source_desc" ]; then
        [[ $completion -eq 100 ]] && {
        # import functions
        debug_func 'desc:info'        #----debug---
        source "$ROOT_PATH/get_desc/info.sh"
        read_info_file; }             # get_desc/info.sh
    fi
    if [ -s "$source_desc" ]; then
        # import functions to generate desc
        debug_func 'desc:match'       #----debug---
        source "$ROOT_PATH/get_desc/match.sh"
        match_douban_imdb "$dot_name"
        match_douban_imdb "$org_tr_name"
        debug_func 'desc:generate'    #----debug---
        source "$ROOT_PATH/get_desc/generate.sh"
        generate_main_func            # get_desc/generate.sh
        #---screens---#
        if [[ $enable_byrbt = yes || $enable_tjupt = yes ]]; then
            debug_func 'desc:screens' #----debug---
            source "$ROOT_PATH/get_desc/screens.sh"
            deal_with_images          # get_desc/screens.sh
        debug_func 'desc:out'         #----debug---
        fi
    fi
else
    # 保险起见，检查已经生成的简介
    if [[ $enable_byrbt = yes && $(grep -Eo "src=[\"\']http[^\'\"]+" \
      "$source_html"|sed "/bt\.byr\.cn/d") ]]; then
        source "$ROOT_PATH/get_desc/screens.sh"
        deal_with_images              # get_desc/screens.sh
        debug_func 'desc-byr-pic-pass2'  #----debug---
    fi
fi
#-------------------------------------#

