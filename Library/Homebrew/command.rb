class Command
  INTERNAL_COMMAND_PATH = HOMEBREW_LIBRARY_PATH/"cmd"
  INTERNAL_DEVELOPER_COMMAND_PATH = HOMEBREW_LIBRARY_PATH/"dev-cmd"
  INTERNAL_COMMAND_PREFIXES = %W[
    #{INTERNAL_COMMAND_PATH}/
    #{INTERNAL_DEVELOPER_COMMAND_PATH}/
  ].freeze

  attr_reader :name
  attr_reader :path

  def initialize(name, path)
    @name = name
    @path = path
  end

  def aliases
    @aliases ||= uncached_aliases
  end

  def kind
    @kind ||= uncached_kind
  end

  def external?
    kind == :external
  end

  def internal?
    kind == :internal
  end

  def unknown?
    kind == :unknown
  end

  def language
    @language ||= uncached_language
  end

  def bash?
    language == :bash
  end

  def ruby?
    language == :ruby
  end

  def help(format = :markdown)
    fetch_help unless @help

    case format
    when :lines
      @help
    when :markdown
      @help.join
    when :tty
      @help.map { |line| format_help_for_tty(line) }.join
    else
      raise "Unsupported help format '#{format}' requested."
    end
  end

  def documented?
    !help(:lines).empty?
  end

  def hide_from_man_page?
    fetch_help unless @help_tags

    @help_tags.include?(:hide_from_man_page)
  end

  def sort_key
    # Options come after regular commands (`~` comes after `z` in ASCII table).
    name.sub(/^--/, "~~").sub(/^-/, "~")
  end

  def inspect
    "#<#{self.class.name}: #{pretty_print} (#{kind}, #{language}) in #{path}>"
  end

  def to_s
    name
  end

  def pretty_print
    name
  end

  def <=>(other)
    sort_key <=> other.sort_key
  end

  private

  def fetch_help
    @help = path.readlines.grep(/^#:/).map { |line| line[2..-1] }
    @help_tags = [:hide_from_man_page].select do |tag|
      @help.reject! { |line| line.strip == "@#{tag}" }
    end
  end

  def format_help_for_tty(line)
    # Replace bullets in lists with `brew` to end up with `brew <command>`.
    line = line.sub(/^  \* /, "#{Tty.highlight}brew#{Tty.reset} ")

    # Make text in backticks bold.
    line = line.gsub(/`(.*?)`/, "#{Tty.highlight}\\1#{Tty.reset}")

    # Make text in angle brackets emphasized (underlined).
    line = line.gsub(/<(.*?)>/, "#{Tty.em}\\1#{Tty.reset}")

    line
  end

  def uncached_aliases
    Command.aliases.select { |_, cmd| cmd.canonical_name == name }.keys.sort
  end

  def uncached_kind
    if path.nil?
      :unknown
    elsif path.to_s.start_with?(*INTERNAL_COMMAND_PREFIXES)
      :internal
    else
      :external
    end
  end

  def uncached_language
    if path.nil?
      :none
    elsif path.to_s.end_with?(".rb")
      :ruby
    elsif path.to_s.end_with?(".sh")
      :bash
    else
      :opaque
    end
  end
end

class CommandAlias < Command
  attr_reader :canonical_name

  def initialize(name, path, canonical_name)
    super(name, path)

    @canonical_name = canonical_name
  end

  def pretty_print
    "#{name} => #{canonical_name}"
  end
end

class Command
  class << self
    def aliases
      internal_aliases
    end

    def commands
      list = internal_commands
      list += internal_developer_commands if ARGV.homebrew_developer?
      list += external_commands
      list
    end

    def external_commands
      list = []
      paths.each do |directory|
        Pathname.glob("#{directory}/brew-*") do |path|
          next unless path.file? && path.executable?
          name = path.basename(".rb").to_s[5..-1]
          next if name.include?(".")
          list << Command.new(name, path)
        end
      end
      list
    end

    def internal_aliases
      @internal_aliases ||= begin
        hash = {}
        Pathname.glob("#{INTERNAL_COMMAND_PATH}/*.alias") do |path|
          next unless path.file?
          name = path.basename(".alias").to_s
          next if name.include?(".")
          canonical_name = path.readlines.first.chomp
          hash[name] = CommandAlias.new(name, path, canonical_name)
        end
        hash
      end
    end

    def internal_commands
      @internal_commands ||= begin
        internal_commands_in_directory(INTERNAL_COMMAND_PATH)
      end
    end

    def internal_developer_commands
      @internal_developer_commands ||= begin
        internal_commands_in_directory(INTERNAL_DEVELOPER_COMMAND_PATH)
      end
    end

    def [](name)
      name = aliases[name].canonical_name if aliases.key?(name)
      path = lookup_command_by_name(name)
      Command.new(name, path)
    end

    private

    def internal_commands_in_directory(directory)
      list = []
      Pathname.glob("#{directory}/*.{rb,sh}") do |path|
        next unless path.file?
        name = path.basename.to_s[0..-4]
        next if name.include?(".")
        list << Command.new(name, path)
      end
      list
    end

    def lookup_command_by_name(name)
      return nil if name.include?(".")

      path = [
        INTERNAL_COMMAND_PATH/"#{name}.rb",
        INTERNAL_COMMAND_PATH/"#{name}.sh",
      ].find(&:file?)

      if ARGV.homebrew_developer?
        path ||= [
          INTERNAL_DEVELOPER_COMMAND_PATH/"#{name}.rb",
          INTERNAL_DEVELOPER_COMMAND_PATH/"#{name}.sh",
        ].find(&:file?)
      end

      path || which("brew-#{name}") || which("brew-#{name}.rb")
    end
  end
end
