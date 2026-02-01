#!/usr/bin/env zsh

# Copyright (c) 2026, Andrea Alberti (MIT license)

# ZLE Spinner Controller (single-process UI loop)
#
# Design:
# - Keep control inside a single ZLE widget.
# - Run the long command in a separate process.
# - Update the editor line (BUFFER/POSTDISPLAY) in a tight loop until the
#   command finishes.


_zsh_opencode_tab_spin_render() {
  emulate -L zsh
  local frame="$1"
  local text="$2"
  local render_mode="$3"

  if [[ -n $_spin_message ]]; then
    text="${frame} ${_spin_message}"
  else
    text="${frame}"
  fi

  case "$_spin_render_mode" in
    postdisplay)
      BUFFER=""
      CURSOR=0
      POSTDISPLAY="${text}"
      ;;
    buffer|*)
      POSTDISPLAY=""
      BUFFER="$text"
      CURSOR=${#BUFFER}
      ;;
  esac

  # Avoid prompt-framework specifics; just ask ZLE to redraw.
  zle -R
}

_zsh_opencode_tab_spin_clear_line() {
  emulate -L zsh

  POSTDISPLAY=""
  BUFFER=""
  CURSOR=0
  # It flushes any pending input and resets the editor state.
  zle -I
  # Ummediately redraws the prompt buffer cleanly, avoiding new line otherwise caused by `zle -I``
  zle redisplay
  # Avoid prompt-framework specifics; just ask ZLE to redraw.
  zle -R
}

_zsh_opencode_tab_run_with_spinner() {
  emulate -L zsh
  setopt localoptions localtraps no_notify

  if [[ -z ${ZLE-} && -z ${WIDGET-} ]]; then
    return 1
  fi

  # Store the buffer (user command line)
  local cmdline="$BUFFER"

  # Return immediately if the buffer was empty
  [[ -n $cmdline ]] || return 0
  
  local _spin_interval _spin_render_mode _spin_message _spin_type
  local -i _spin_print_output
  local -a _spin_frames

  _spin_interval=${SPIN_INTERVAL:-0.1}
  _spin_render_mode=${SPIN_RENDER_MODE:-postdisplay}   # buffer|postdisplay
  _spin_message=${SPIN_MESSAGE:-AI thinking...}
  _spin_type=${SPIN_TYPE:-growVertical}
  _spin_print_output=${SPIN_PRINT_OUTPUT:-1}           # 0/1
  
  # Set the type of frames and interval based on 
  # frames imported from `revolver` (https://github.com/molovo/revolver)
  local -a _spin_frames
  () {
    local -A _revolver_spinners

    _revolver_spinners[dots]='0.08 ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏'
    _revolver_spinners[dots2]='0.08 ⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷'
    _revolver_spinners[dots3]='0.08 ⠋ ⠙ ⠚ ⠞ ⠖ ⠦ ⠴ ⠲ ⠳ ⠓'
    _revolver_spinners[dots4]='0.08 ⠄ ⠆ ⠇ ⠋ ⠙ ⠸ ⠰ ⠠ ⠰ ⠸ ⠙ ⠋ ⠇ ⠆'
    _revolver_spinners[dots5]='0.08 ⠋ ⠙ ⠚ ⠒ ⠂ ⠂ ⠒ ⠲ ⠴ ⠦ ⠖ ⠒ ⠐ ⠐ ⠒ ⠓ ⠋'
    _revolver_spinners[dots6]='0.08 ⠁ ⠉ ⠙ ⠚ ⠒ ⠂ ⠂ ⠒ ⠲ ⠴ ⠤ ⠄ ⠄ ⠤ ⠴ ⠲ ⠒ ⠂ ⠂ ⠒ ⠚ ⠙ ⠉ ⠁'
    _revolver_spinners[dots7]='0.08 ⠈ ⠉ ⠋ ⠓ ⠒ ⠐ ⠐ ⠒ ⠖ ⠦ ⠤ ⠠ ⠠ ⠤ ⠦ ⠖ ⠒ ⠐ ⠐ ⠒ ⠓ ⠋ ⠉ ⠈'
    _revolver_spinners[dots8]='0.08 ⠁ ⠁ ⠉ ⠙ ⠚ ⠒ ⠂ ⠂ ⠒ ⠲ ⠴ ⠤ ⠄ ⠄ ⠤ ⠠ ⠠ ⠤ ⠦ ⠖ ⠒ ⠐ ⠐ ⠒ ⠓ ⠋ ⠉ ⠈ ⠈'
    _revolver_spinners[dots9]='0.08 ⢹ ⢺ ⢼ ⣸ ⣇ ⡧ ⡗ ⡏'
    _revolver_spinners[dots10]='0.08 ⢄ ⢂ ⢁ ⡁ ⡈ ⡐ ⡠'
    _revolver_spinners[dots11]='0.1 ⠁ ⠂ ⠄ ⡀ ⢀ ⠠ ⠐ ⠈'
    _revolver_spinners[dots12]='0.08 "⢀⠀" "⡀⠀" "⠄⠀" "⢂⠀" "⡂⠀" "⠅⠀" "⢃⠀" "⡃⠀" "⠍⠀" "⢋⠀" "⡋⠀" "⠍⠁" "⢋⠁" "⡋⠁" "⠍⠉" "⠋⠉" "⠋⠉" "⠉⠙" "⠉⠙" "⠉⠩" "⠈⢙" "⠈⡙" "⢈⠩" "⡀⢙" "⠄⡙" "⢂⠩" "⡂⢘" "⠅⡘" "⢃⠨" "⡃⢐" "⠍⡐" "⢋⠠" "⡋⢀" "⠍⡁" "⢋⠁" "⡋⠁" "⠍⠉" "⠋⠉" "⠋⠉" "⠉⠙" "⠉⠙" "⠉⠩" "⠈⢙" "⠈⡙" "⠈⠩" "⠀⢙" "⠀⡙" "⠀⠩" "⠀⢘" "⠀⡘" "⠀⠨" "⠀⢐" "⠀⡐" "⠀⠠" "⠀⢀" "⠀⡀"'
    _revolver_spinners[line]='0.13 - \\ | /'
    _revolver_spinners[line2]='0.1 ⠂ - – — – -'
    _revolver_spinners[pipe]='0.1 ┤ ┘ ┴ └ ├ ┌ ┬ ┐'
    _revolver_spinners[simpleDots]='0.4 ".  " ".. " "..." "   "'
    _revolver_spinners[simpleDotsScrolling]='0.2 ".  " ".. " "..." " .." "  ." "   "'
    _revolver_spinners[star]='0.07 ✶ ✸ ✹ ✺ ✹ ✷'
    _revolver_spinners[star2]='0.08 + x *'
    _revolver_spinners[flip]="0.07 _ _ _ - \` \` ' ´ - _ _ _"
    _revolver_spinners[hamburger]='0.1 ☱ ☲ ☴'
    _revolver_spinners[growVertical]='0.12 ▁ ▃ ▄ ▅ ▆ ▇ ▆ ▅ ▄ ▃'
    _revolver_spinners[growHorizontal]='0.12 ▏ ▎ ▍ ▌ ▋ ▊ ▉ ▊ ▋ ▌ ▍ ▎'
    _revolver_spinners[balloon]='0.14 " " "." "o" "O" "@" "*" " "'
    _revolver_spinners[balloon2]='0.12 . o O ° O o .'
    _revolver_spinners[noise]='0.14 ▓ ▒ ░'
    _revolver_spinners[bounce]='0.1 ⠁ ⠂ ⠄ ⠂'
    _revolver_spinners[boxBounce]='0.12 ▖ ▘ ▝ ▗'
    _revolver_spinners[boxBounce2]='0.1 ▌ ▀ ▐ ▄'
    _revolver_spinners[triangle]='0.05 ◢ ◣ ◤ ◥'
    _revolver_spinners[arc]='0.1 ◜ ◠ ◝ ◞ ◡ ◟'
    _revolver_spinners[circle]='0.12 ◡ ⊙ ◠'
    _revolver_spinners[squareCorners]='0.18 ◰ ◳ ◲ ◱'
    _revolver_spinners[circleQuarters]='0.12 ◴ ◷ ◶ ◵'
    _revolver_spinners[circleHalves]='0.05 ◐ ◓ ◑ ◒'
    _revolver_spinners[squish]='0.1 ╫ ╪'
    _revolver_spinners[toggle]='0.25 ⊶ ⊷'
    _revolver_spinners[toggle2]='0.08 ▫ ▪'
    _revolver_spinners[toggle3]='0.12 □ ■'
    _revolver_spinners[toggle4]='0.1 ■ □ ▪ ▫'
    _revolver_spinners[toggle5]='0.1 ▮ ▯'
    _revolver_spinners[toggle6]='0.3 ဝ ၀'
    _revolver_spinners[toggle7]='0.08 ⦾ ⦿'
    _revolver_spinners[toggle8]='0.1 ◍ ◌'
    _revolver_spinners[toggle9]='0.1 ◉ ◎'
    _revolver_spinners[toggle10]='0.1 ㊂ ㊀ ㊁'
    _revolver_spinners[toggle11]='0.05 ⧇ ⧆'
    _revolver_spinners[toggle12]='0.12 ☗ ☖'
    _revolver_spinners[toggle13]='0.08 = * -'
    _revolver_spinners[arrow]='0.1 ← ↖ ↑ ↗ → ↘ ↓ ↙'
    _revolver_spinners[arrow2]='0.12 ▹▹▹▹▹ ▸▹▹▹▹ ▹▸▹▹▹ ▹▹▸▹▹ ▹▹▹▸▹ ▹▹▹▹▸'
    _revolver_spinners[bouncingBar]='0.08 "[    ]" "[   =]" "[  ==]" "[ ===]" "[====]" "[=== ]" "[==  ]" "[=   ]"'
    _revolver_spinners[bouncingBall]='0.08 "( ●    )" "(  ●   )" "(   ●  )" "(    ● )" "(     ●)" "(    ● )" "(   ●  )" "(  ●   )" "( ●    )" "(●     )"'
    _revolver_spinners[pong]='0.08 "▐⠂       ▌" "▐⠈       ▌" "▐ ⠂      ▌" "▐ ⠠      ▌" "▐  ⡀     ▌" "▐  ⠠     ▌" "▐   ⠂    ▌" "▐   ⠈    ▌" "▐    ⠂   ▌" "▐    ⠠   ▌" "▐     ⡀  ▌" "▐     ⠠  ▌" "▐      ⠂ ▌" "▐      ⠈ ▌" "▐       ⠂▌" "▐       ⠠▌" "▐       ⡀▌" "▐      ⠠ ▌" "▐      ⠂ ▌" "▐     ⠈  ▌" "▐     ⠂  ▌" "▐    ⠠   ▌" "▐    ⡀   ▌" "▐   ⠠    ▌" "▐   ⠂    ▌" "▐  ⠈     ▌" "▐  ⠂     ▌" "▐ ⠠      ▌" "▐ ⡀      ▌" "▐⠠       ▌"'
    _revolver_spinners[shark]='0.12 "▐|\\____________▌" "▐_|\\___________▌" "▐__|\\__________▌" "▐___|\\_________▌" "▐____|\\________▌" "▐_____|\\_______▌" "▐______|\\______▌" "▐_______|\\_____▌" "▐________|\\____▌" "▐_________|\\___▌" "▐__________|\\__▌" "▐___________|\\_▌" "▐____________|\\▌" "▐____________/|▌" "▐___________/|_▌" "▐__________/|__▌" "▐_________/|___▌" "▐________/|____▌" "▐_______/|_____▌" "▐______/|______▌" "▐_____/|_______▌" "▐____/|________▌" "▐___/|_________▌" "▐__/|__________▌" "▐_/|___________▌" "▐/|____________▌"'

    if (( ! ${+_revolver_spinners[$_spin_type]} )); then
      _spin_type='bouncingBar'
    fi
    
    # The frames that, when animated, will make up
    # our spinning indicator
    local -a arr
    # (@z): does lexical splitting, but it does not remove the quote
    # (@Q): remove one level of quoting
    arr=(${(@Q)${(@z)_revolver_spinners[$_spin_type]}})
    # Get the interval between frames
    _spin_interval="${arr[1]}"
    # Get the frames
    _spin_frames=("${arr[@]:1:-1}")  # elements 2..last 
  }

  {
    # Use a FIFO to receive the background command's exit status.
    # To avoid confusion: the FIFO contains **just** the exit status, nothing else.
    local -i status_fd
    # Capture stdout/stderr to a temp file so it doesn't corrupt ZLE.
    local out status_fifo
    {
      out="$(mktemp -t zsh-opencode-tab.out.XXXXXX)"
      status_fifo="$(mktemp -t zsh-opencode-tab.status.XXXXXX)"
      
      # Convert the temp file to FIFO
      {
        command rm -f -- "$status_fifo" 2>/dev/null
        command mkfifo -- "$status_fifo"
      }
      # Open FIFO for reading, nonblocking
      # sysopen -r -o nonblock -u status_fd "$status_fifo"
      
      # Important: opening a FIFO read-only blocks until a writer connects.
      # Open it read-write so we never hang here (macOS/BSD semantics).
      # This FIFO is opened in blocking mode on purpose so that we can later
      # use read with timeout and we do not need to handle an extra sleep cmd.
      exec {status_fd}<>"$status_fifo"
    } always {
      local ret=$?

      # Only cleanup if error
      if (( ret != 0 )); then
        command rm -f -- "$out" "$status_fifo" 2>/dev/null
        return $ret
      fi
    }

    # Execute long_command in a background subshell, passing the buffer contents.
    # Disown the job to prevent job-control noise in the interactive shell.
    (
      emulate -L zsh
      setopt localoptions localtraps no_notify no_monitor

      # ^C was pressed
      TRAPINT() {
        print -r -- 130 >"$status_fifo" 2>/dev/null
        exit 130
      }
      # kill command was received
      TRAPTERM() {
        print -r -- 143 >"$status_fifo" 2>/dev/null
        exit 143
      }

      # Run the process
      ./long_command.sh "$cmdline"

      local -i child_rc=$?
      print -r -- $child_rc >"$status_fifo" 2>/dev/null
      exit $child_rc
    ) >"$out" 2>&1 &!
    local -i pid=$!

    local -i cancelled=0
    local -i cancel_t0=-1 # track the elapsed time since the first TRAPINT
    local -i cancel_sent_term=0
    local -i cancel_sent_kill=0
    # Relay Ctrl-C signals to the background process
    TRAPINT() {
      cancelled=1
      (( cancel_t0 == -1 )) && cancel_t0=$SECONDS
      # Interrupt the background process; a negative PID sends
      # SIGINT to the entire process group whose PGID = $pid.
      # If that doesn’t work, signal the one process.
      command kill -INT -$pid 2>/dev/null || command kill -INT $pid 2>/dev/null
    }

    # Default exit status
    local -i rc=0

    # Animate the spinner while waiting for the exit code over the FIFO.
    {
      # Hide cursor
      if (( ${+terminfo[civis]} )); then
        print -n -- $terminfo[civis]
      else
        print -n -- $'\e[?25l'
      fi

      # Clear what the user typed (per requirement)
      _zsh_opencode_tab_spin_clear_line

      local -i i=1
      local line=""
      while true; do
        _zsh_opencode_tab_spin_render "${_spin_frames[i]}" "${_spin_message}" "${_spin_render_mode}"

        if read -t "$_spin_interval" -u $status_fd line; then
          if [[ "$line" == <-> ]]; then
            # if line contains only digits
            rc=$line
          else
            # fallback case: if line contains something different
            # though, this should never happen..
            rc=1
          fi
          # exit the loop
          break
        fi

        # If user sent Ctrl-C but the process did not output any return code yet
        # after certain time, then escalate to kill -TERM and then kill -KILL
        if (( cancelled )); then
          # Failsafe: if the process is gone but we didn't get a status, stop.
          if ! kill -0 $pid 2>/dev/null; then
            rc=1
            break
          fi

          # If the worker ignores INT, escalate after a short grace period.
          if (( ! cancel_sent_term && (SECONDS - cancel_t0) >= 2 )); then
            kill -TERM -$pid 2>/dev/null || kill -TERM $pid 2>/dev/null
            cancel_sent_term=1
          fi
          if (( ! cancel_sent_kill && (SECONDS - cancel_t0) >= 4 )); then
            kill -KILL -$pid 2>/dev/null || kill -KILL $pid 2>/dev/null
            cancel_sent_kill=1
          fi
        fi

        i=$(( (i % ${#_spin_frames}) + 1 ))
      done
    } always {
      # Restore cursor
      if (( ${+terminfo[cnorm]} )); then
        print -n -- $terminfo[cnorm]
      else
        print -n -- $'\e[?25h'
      fi
    }
  
    # Reset the buffer clearing the spinner
    _zsh_opencode_tab_spin_clear_line
  } always {
    # Close FIFO fd and remove FIFO.
    exec {status_fd}<&- 2>/dev/null
    exec {status_fd}>&- 2>/dev/null
    command rm -f -- "$status_fifo" 2>/dev/null
  }

  if (( _spin_print_output )) || (( rc != 0 )) || (( cancelled )); then
    if (( cancelled )); then
      print -r -- "cancelled by the user"
    elif (( rc != 0 )); then
      print -r -- "zsh-opencode-tab: unexpected termination (exit code: $rc)"
    fi
    # If file exists
    if [[ -s $out ]]; then
      # Print the output from the background process;
      # this may also contain any error messages
      command cat -- "$out"
    fi
  fi

  # Remove the auxiliary file
  command rm -f -- "$out" 2>/dev/null
  return $rc
}
