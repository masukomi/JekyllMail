#!/bin/sh

# CHANGE ME TO MEET THE NEEDS OF YOUR SERVER CONFIGURATION

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
GEM_PATH=$GEM_PATH:/home/my_username/.gems
PATH=$PATH:/home/my_username/.gems/bin
cd /home/my_username/jekyll/
bundle exec rake generate
