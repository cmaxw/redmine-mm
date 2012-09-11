set :application, "redmine"
set :repository,  "redmine@ppm.monarchmedia.com:/home/redmine/git/redmine.git"
set :scm, :git
set :git_enable_submodules, 1

# Will checkout a copy locally from :repository and upload as a tar.gz file
set :deploy_via, :copy
set :git_shallow_clone, 1 

set :branch, "monarch-media/master"
set :user, "redmine"
set :keep_releases, 5

default_run_options[:pty] = true

task :production do
  set :main_server, "ppm.monarchmedia.com"
  role :app, main_server
  role :web, main_server
  role :db,  main_server, :primary => true
  set(:deploy_to) { "/srv/redmine" }
end

# TODO: setup staging on new server
task :staging do
  set :main_server, "ppm.monarchmedia.com"
  role :app, main_server
  role :web, main_server
  role :db,  main_server, :primary => true
  set(:deploy_to) { "/src/redmine-staging" }
  set(:branch) { "monarch-media/staging" }
end

namespace :deploy do
  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

namespace :copy do
  desc "copy configurations to current"
  task :configurations, :roles => [:app] do
    %w[database.yml].each do |f|
      run "ln -nsf #{shared_path}/config/#{f} #{release_path}/config/#{f}"
    end
  end

  desc "link shared file storage to current"
  task :file_storage, :roles => [:app] do
    run "rm #{release_path}/files/delete.me"
    run "rmdir #{release_path}/files"
    run "ln -nsf #{shared_path}/files #{release_path}/files"
  end
end

after "deploy:finalize_update", "copy:configurations", "copy:file_storage", "deploy:cleanup"

# Only supports MySQL.
desc "Download production data into development database"
task :fetch_remote_db, :roles => :db, :only => { :primary => true } do
  require 'yaml'

  filename = "dump.#{Time.now.strftime '%Y-%m-%d_%H:%M:%S'}.sql"

  on_rollback do 
    delete "/tmp/#{filename}" 
    delete "/tmp/#{filename}.gz" 
  end

  cmd = "mysqldump -u #{database[:production][:username]} -h #{database[:production][:host]} --password=#{database[:production][:password]} #{database[:production][:database]} > /tmp/#{filename}"
  puts "Dumping remote database"
  run(cmd) do |channel, stream, data|
    puts data
  end
  
  # compress the file on the server
  puts "Compressing remote data"
  run "gzip -9 /tmp/#{filename}"
  puts "Fetching remote data"
  get "/tmp/#{filename}.gz", "dump.sql.gz"
  puts "Remote data is now in dump.sql.gz"
  
end
