module CheckedHelper
  private

  def macho_fail(where, cc, rb)
    $stderr.puts "> Mismatch between cctools/ruby-macho in #{where} method!"
    $stderr.puts "| File: #{self}"
    $stderr.puts "|   cc: #{cc.inspect}"
    $stderr.puts "|   rb: #{rb.inspect}"
    raise "Mismatch between cctools/ruby-macho in #{where} method!"
  end
end
