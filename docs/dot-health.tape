# Records docs/dot-health.gif for the README. Run `make demo`, not vhs directly:
# it captures a real `dot health` run into docs/.dot-health.ansi first, and this
# tape replays that capture. Running the checks live inside VHS takes minutes and
# hangs on the login-items check, which needs Automation permission that VHS's
# headless terminal does not have.

Output "dot-health.gif"

# Tall enough that the full report fits on one screen; it would scroll otherwise.
Set Width 1000
Set Height 1980
Set FontSize 13
Set FontFamily "JetBrains Mono"
Set LineHeight 1.2
Set TypingSpeed 60ms
Set Theme "Catppuccin Mocha"
Set Padding 24
Set WindowBar Colorful
Set Margin 20
Set MarginFill "#b4befe"
Set BorderRadius 10
Set Shell "bash"

# Replays the capture line by line, pausing at each blank line between sections, so
# the report builds up the way a live run does instead of appearing all at once.
Hide
Type `dot() { while IFS= read -r l; do printf '%s\n' "$l"; if [ -z "$l" ]; then sleep 0.35; else sleep 0.05; fi; done < .dot-health.ansi; }; clear`
Enter
Show

Type "dot health"
Sleep 500ms
Enter
# Long enough for the replay (~9s) plus a pause on the finished report.
Sleep 16s
