class Keg
  if ENV["HOMEBREW_RUBY_MACHO"]
    require "os/mac/ruby_keg"
    include RubyKeg
  else
    require "os/mac/cctools_keg"
    include CctoolsKeg
  end

  def log_relocate(backend, file, what, args = {})
    prefix = "[#{backend}] #{name}: "

    lines = [
      "#{prefix}#{file.relative_path_from(path)}",
      "#{prefix}  what = #{what}",
    ]
    args.each do |arg, value|
      lines << "#{prefix}  #{arg.to_s.ljust(4)} = #{value.inspect}"
    end

    puts lines.join("\n") if ARGV.debug?

    log_path = HOMEBREW_LOGS/"#{name}/relocate.log"
    log_path.parent.mkpath
    log_path.open("a") { |f| f.puts lines.join("\n") }
  end
end
