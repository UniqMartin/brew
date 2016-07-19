#: @hide_from_man_page
#:  * `tap-status`:
#:    List the status of all tapped Git repositories.

_git_executable="$("$HOMEBREW_LIBRARY/Homebrew/shims/scm/git" --homebrew=print-path)"
git() { "$_git_executable" "$@"; }

tap-label() {
  local repo_dir="$1"
  local repo_label

  if [[ "$repo_dir" = "$HOMEBREW_REPOSITORY" ]]
  then
    repo_label="[brew]"
  else
    repo_label="${repo_dir#"$HOMEBREW_LIBRARY/Taps/"}"
    repo_label="${repo_label/\/homebrew-//}"
  fi
  echo "$repo_label"
}

tap-remote-url() {
  local origin_url
  local repo_remote="$1"

  origin_url="$(git remote get-url "$repo_remote" 2> /dev/null)"
  if [[ $? -eq 0 && -n "$origin_url" ]]
  then
    echo "$origin_url"
    return
  fi

  origin_url="$(git remote show -n "$repo_remote" | grep -E '^\s+Fetch URL: ')"
  if [[ $? -eq 0 && -n "$origin_url" ]]
  then
    echo "${origin_url#*Fetch URL: }"
    return
  fi

  echo "(none)"
}

tap-branch() {
  local b
  local b_head
  local count
  local p
  local upstream="@{upstream}"

  if [[ -L ".git/HEAD" ]]
  then
    b="$(git symbolic-ref HEAD 2> /dev/null)"
  else
    b_head="$(<".git/HEAD")"
    b="${b_head#ref: }"
    if [[ "$b_head" = "$b" ]]
    then
      b="$(git describe --contains --all HEAD 2> /dev/null)" \
        || b="$(git rev-parse --short HEAD 2> /dev/null)"
      b="($b)"
    fi
  fi
  b="${b#refs/heads/}"

  count="$(git rev-list --count --left-right "$upstream...HEAD" 2> /dev/null)"
  case "$count" in
    "")
      p=""
      ;;
    $'0\t0')
      p="="
      ;;
    $'0\t'*)
      p=">"
      ;;
    *$'\t0')
      p="<"
      ;;
    *)
      p="<>"
      ;;
  esac

  echo "$b$p"
}

tap-commit() {
  git rev-parse --short HEAD 2> /dev/null
}

tap-state() {
  local i=" "
  local s="\$"
  local u="%"
  local w=" "

  git diff --no-ext-diff --quiet || w="*"
  git diff --no-ext-diff --cached --quiet || i="+"
  git rev-parse --verify --quiet refs/stash > /dev/null || s=" "
  git ls-files --others --exclude-standard --directory --no-empty-directory \
    --error-unmatch -- ':/' > /dev/null 2> /dev/null || u=" "

  echo "[$w$i$s$u]"
}

tap-all-branches() {
  local color_green=$'\e[32m'
  local color_magenta=$'\e[35m'
  local color_reset=$'\e[0m'
  local color_yellow=$'\e[1;33m'
  local branch
  local branch_skip
  local branch_track
  local commit
  local info
  local repo_label_max="$1"
  local output='%(objectname:short)%09%(refname:short)%09%(upstream:trackshort)'

  branch_skip="$(git symbolic-ref HEAD 2> /dev/null)"
  branch_skip="${branch_skip#refs/heads/}"

  while IFS=$'\t' read -r -a info ; do
    commit="${info[0]}"
    branch="${info[1]}"
    [[ "$branch" != "$branch_skip" ]] || continue

    branch_track="${info[2]}"
    printf "%s%-*s%s %s%s%s        %s%s%s\n" \
      "$color_yellow" "$repo_label_max" "|" "$color_reset" \
      "$color_green" "$commit" "$color_reset" \
      "$color_magenta" "$branch$branch_track" "$color_reset"
  done \
    < <(git for-each-ref --format "$output" refs/heads/)
}

parse-arguments() {
  local arg

  for arg in "$@"
  do
    case "$arg" in
      -\?|-h|--help|--usage)
        brew help tap-status
        exit $?
        ;;
      --verbose)
        HOMEBREW_VERBOSE=1
        ;;
      --debug)
        HOMEBREW_DEBUG=1
        ;;
      --brewery=*)
        HOMEBREW_REPOSITORY="${arg#--brewery=}"
        HOMEBREW_LIBRARY="$HOMEBREW_REPOSITORY/Library"
        ;;
      --*)
        # Ignore other long options.
        ;;
      -*)
        [[ "$arg" = *v* ]] && HOMEBREW_VERBOSE=1
        [[ "$arg" = *d* ]] && HOMEBREW_DEBUG=1
        # Ignore other short options.
        ;;
      *)
        odie <<-EOS
This command accepts no named arguments.
EOS
        ;;
    esac
  done

  if [[ -n "$HOMEBREW_DEBUG" ]]
  then
    set -x
  fi
}

homebrew-tap-status() {
  local color_green=$'\e[1;32m'
  local color_magenta=$'\e[1;35m'
  local color_reset=$'\e[0m'
  local color_yellow=$'\e[1;33m'
  local repo_branch
  local repo_commit
  local repo_dir
  local repo_label
  local repo_label_max=0
  local repo_origin_url
  local repo_state

  parse-arguments "$@"

  for repo_dir in "$HOMEBREW_REPOSITORY" "$HOMEBREW_LIBRARY"/Taps/*/*
  do
    [[ -d "$repo_dir/.git" ]] || continue
    repo_label="$(tap-label "$repo_dir")"
    [[ "${#repo_label}" -le "$repo_label_max" ]] \
      || repo_label_max="${#repo_label}"
  done

  for repo_dir in "$HOMEBREW_REPOSITORY" "$HOMEBREW_LIBRARY"/Taps/*/*
  do
    [[ -d "$repo_dir/.git" ]] || continue
    cd "$repo_dir" || continue
    [[ -z "$HOMEBREW_VERBOSE" || "$repo_dir" = "$HOMEBREW_REPOSITORY" ]] \
      || echo

    repo_commit="$(tap-commit)"
    repo_state="$(tap-state)"
    repo_branch="$(tap-branch)"
    repo_label="$(tap-label "$repo_dir")"
    repo_origin_url="$(tap-remote-url origin)"
    printf "%s%-*s%s %s%s%s %s%s%s %s%-16s%s - %s\n" \
      "$color_yellow" "$repo_label_max" "$repo_label" "$color_reset" \
      "$color_green" "$repo_commit" "$color_reset" \
      "$color_magenta" "$repo_state" "$color_reset" \
      "$color_magenta" "$repo_branch" "$color_reset" \
      "$repo_origin_url"
    [[ -z "$HOMEBREW_VERBOSE" ]] \
      || tap-all-branches "$repo_label_max"
  done

  safe_cd "$HOMEBREW_REPOSITORY"
}
