#:  * `commands` [`--quiet`] [`--include-aliases`]:
#:    Show a list of built-in and external commands.
#:
#:    If `--quiet` is passed or output doesn't go to a terminal, print a simple
#:    list instead of grouping output by category and including group headers.
#:
#:    With `--include-aliases`, aliases of internal commands will be included.

module Homebrew
  def commands
    include_aliases = ARGV.include?("--include-aliases")

    if ARGV.include?("--quiet") || !$stdout.tty?
      cmds = Command.commands
      cmds += Command.aliases.values if include_aliases
      puts_columns cmds.sort.map(&:name)
    else
      # Collect commands grouped by category.
      cmds = []
      cmds << ["Built-in commands", Command.internal_commands]
      cmds << ["Built-in aliases", Command.aliases.values] if include_aliases
      if ARGV.homebrew_developer?
        cmds << [
          "Built-in developer commands",
          Command.internal_developer_commands,
        ]
      end
      cmds << ["External commands", Command.external_commands]

      # Output commands grouped by category (omitting empty lists).
      cmds.reject! { |_title, list| list.empty? }
      cmds.each_with_index do |(title, list), index|
        puts if index != 0
        ohai title
        puts_columns list.sort.map(&:pretty_print)
      end
    end
  end
end
