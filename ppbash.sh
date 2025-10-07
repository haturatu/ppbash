#!/bin/bash
#----------------------------------------------
# OREORE PASSEORD MANAGER
#----------------------------------------------
# 関数名のdotfolderにパスワードを保存する
#
# 基本的には`_genpass`を呼び出すだけ
# `_genpass`に渡す引数は以下の通り
# 1. ハッシュコマンド
# 2. エンコードコマンド
# 3. パスワード長
# 4. フレーズ
#
# ファイルはバイナリで保存されるので
# 平文のパスワードは残らない
# (ただし、シェルの履歴には残る)
# (ファイル名は平文で保存される)
#
# 自動補完対応なので
# 関数 <tab> 
# でファイル名が補完されパスワード確認が楽になる
#
# カスタマイズするとしたら
# `_genpass`に渡す引数
# または
# 関数名を追加する
# `_register_func_dir`で関数名を登録しているので
# grepで関数名を抽出している部分を
# 書き換えると良い
#
# .bashrcに以下を追加して使う
# source /path/to/ppbash.sh
# ----------------------------------------------

unset PASS_DIRS

_usage() {
  local pass_func="$1"
  local phrase="$2"
  local filename="$3"

  if [[ -z "$filename" ]]; then
    echo "Usage: $pass_func <filename> <phrase>"
    echo
    echo "説明:"
    echo "  $pass_func は指定した <phrase> からパスワードを生成し、"
    echo "  ~/.${pass_func}/ に <filename> という名前で暗号化して保存します。"
    echo
    echo "引数:"
    echo "  <filename> : 保存・読み出しに使う識別名（ファイル名）"
    echo "  <phrase>   : 元となるフレーズ（空白を含む場合は引用符で囲む）"
    echo
    echo "使用例:"
    echo "  $pass_func mymail 'Like a rolling stone'"
    echo
    echo "再利用:"
    echo "  既に保存済みの <filename> を指定すると、そのパスワードを再表示します。"
    echo
    echo "補完:"
    echo "  ${pass_func} <Tab> で保存済みのファイル名が補完されます。"
    echo
    echo "関連コマンド:"
    echo "  ppmenu  : 登録済みのパスワードディレクトリを一覧表示します。"
    echo
    return 1
  fi

  return 0
}

_init_pass_dir() {
  local dir=$1
  if [[ ! -d $dir ]]; then
    mkdir -p $dir
  fi
}

_pass_list() {
  local dir="$1"
  local passfiles=()

  if [[ -d "$dir" ]]; then
    passfiles=("$dir"/*)
    printf "%s " "${passfiles[@]##*/}"
  fi
}

_register_func_dir() {
  while read -r fn _; do
    local dir="$HOME/.$fn"
    PASS_DIRS+=("$dir")

    complete -W "$(_pass_list "$dir")" "$fn"
  done < <(declare -F | awk '{print $3}' | grep '^pb')
}

_genpass() {
  local hash_cmd="$1"
  local encode_cmd="$2"
  local length="$3"
  local phrase="$4"
  local filepath="$dir/$filename"

  if [[ -f "$filepath" ]]; then
    if [[ -n "$phrase" ]]; then
      printf "%s\n" "duplicate file found, using existing value:"
    fi

    "$encode_cmd" < "$filepath" | head -c "${length}" | tr -d "\n"
    echo
    return 0
  else
    if [[ -z "$phrase" ]]; then
      echo "file not found"
      return 1
    fi
  fi

  printf "%s" "$phrase" | "$hash_cmd" | awk '{print $1}' | xxd -r -p > "$filepath"

  "$encode_cmd" < "$filepath" | head -c "${length}" | tr -d "\n"
  printf "\n"
  printf "%s\n" "Generated and saved to $filepath"
}

# 20文字のbase91エンコード
pb20gbase91() {
  local pass_func="$FUNCNAME"
  local dir="$HOME/.$pass_func"
  local filename="$1"
  local phrase="$2"

  _usage $pass_func "$phrase" "$filename" || return 1
  _init_pass_dir "$dir"

  _genpass "sha256sum" "base91" "20" "$phrase" || return 1

  _register_func_dir "$pass_func"
}

# 60文字のbase64エンコード
pb60gbase64() {
  local pass_func="$FUNCNAME"
  local dir="$HOME/.$pass_func"
  local filename="$1"
  local phrase="$2"

  _usage $pass_func "$phrase" "$filename" || return 1
  _init_pass_dir "$dir"

  _genpass "sha512sum" "base64" "60" "$phrase" || return 1

  _register_func_dir "$pass_func"
}

_register_func_dir

ppmenu() {
  for dir in "${PASS_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      tree "$dir"
    else
      echo "Directory $dir does not exist."
    fi
  done
}


