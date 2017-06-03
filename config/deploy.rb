# config valid only for current version of Capistrano
lock "3.8.1"

set :application, "conoha_ddns"
set :repo_url, "https://github.com/esetomo/conoha_ddns.git"

append :linked_dirs, 'tmp'
append :linked_files, '.env'
set :passenger_restart_with_touch, true

