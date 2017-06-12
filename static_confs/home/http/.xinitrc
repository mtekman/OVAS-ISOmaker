setxkbmap -layout gb

pulseaudio -k           # kill daemon
pulseaudio --start      # start daemon


firefox "localhost:80" & metacity --replace & nautilus $HOME/Desktop & cairo-dock
