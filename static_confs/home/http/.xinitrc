setxkbmap -layout gb

pulseaudio -k           # kill daemon
pulseaudio --start      # start daemon


#firefox "localhost:80" & metacity --replace & nautilus $HOME/Desktop & cairo-dock
#firefox "localhost:80" & nautilus $HOME/Desktop & cairo-dock & blackbox

firefox "localhost:80" & nautilus $HOME/Desktop & xfwm4 & exec cairo-dock

