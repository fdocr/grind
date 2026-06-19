# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Concurrency env vars (set in Once Settings Environment):
#   WEB_CONCURRENCY     Puma worker processes (default 1). Use 2+ with preload_app!.
#   RAILS_MAX_THREADS   Threads per Puma worker (default 3).
#   SOLID_QUEUE_IN_PUMA Set to "false" to disable the Solid Queue Puma plugin.

max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 3))
threads max_threads, max_threads

workers_count = Integer(ENV.fetch("WEB_CONCURRENCY", 1))
if workers_count > 1
  workers workers_count
  preload_app!
end

port ENV.fetch("PORT", 3000)

plugin :tmp_restart

plugin :solid_queue unless ENV["SOLID_QUEUE_IN_PUMA"] == "false"

plugin :honeybadger

plugin :tailwindcss if ENV.fetch("RAILS_ENV", "development") == "development"

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
