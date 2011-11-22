if ENV["RAILS_ENV"] == "production"
  config = {
    working_directory: "/RAILS_ROOT/#{ENV["RAILS_DEVEL_NAME"] == "product" ? ENV["RAILS_ENV"] : (ENV["RAILS_DEVEL_NAME"] || "unknown")}/current",
    worker_processes: 3,
    preload_app: true,
  }
else
  config = {
    working_directory: "/RAILS_ROOT/#{ENV["RAILS_DEVEL_NAME"] || "unknown"}",
    worker_processes: 1,
    preload_app: false,
  }
end

working_directory config[:working_directory]
worker_processes config[:worker_processes]

timeout 30
listen      File.join(config[:working_directory], 'tmp/sockets/unicorn.sock')
pid         File.join(config[:working_directory], 'tmp/pids/unicorn.pid')
stderr_path File.join(config[:working_directory], 'log/unicorn.log')
stdout_path File.join(config[:working_directory], 'log/unicorn.log')

preload_app config[:preload_app]

GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly=)

before_fork do |server,worker|
  ActiveRecord::Base.connection.disconnect! if defined?(ActiveRecord::Base)

  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :WINCH : :TTOU
      Process.kill sig, File.read(old_pid).to_i
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server,worker|
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
end
