#:  * `command` <cmd>:
#:    Display the path to the file which is used when invoking `brew` <cmd>.

module Homebrew
  def command
    if ARGV.empty?
      raise UsageError, "This command requires a command argument"
    end

    cmd = Command[ARGV.first]
    if cmd.unknown?
      odie "Unknown command: #{cmd}"
    else
      puts cmd.path
    end
  end
end
