Application.ensure_all_started([:logger])
Logger.configure(level: :none)
ExUnit.start()
