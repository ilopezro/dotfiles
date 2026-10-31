# Records docs/dot-health.gif for the README. Run `make demo`, not vhs directly:
# it records a real `dot health` run into docs/.dot-health.rec first (`script -r`),
# and this tape plays it back in real time (`script -p`), spinner included. Running
# the checks live inside VHS hangs on the login-items check, which needs Automation
# permission that VHS's headless terminal does not have.

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

Hide
Type `dot() { script -q -p .dot-health.rec; }; clear`
Enter
Show

Type "dot health"
Sleep 500ms
Enter
# The run takes as long as it took when recorded, so wait for its last line rather
# than guessing a duration, then hold the finished report before the GIF loops.
Wait+Screen@180s /checks (passed|failed)/
Sleep 6s
