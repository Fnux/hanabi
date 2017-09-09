# Skip tests tagged with `@tag :pending`
ExUnit.configure(exclude: [todo: true])

# Start ExUnit :)
ExUnit.start()

# Load helpers
Code.require_file "hanabi/helper.exs", __DIR__
