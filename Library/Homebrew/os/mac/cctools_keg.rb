module CctoolsKeg
  def install_name_tool(*args)
    @require_install_name_tool = true
    tool = MacOS.install_name_tool
    system(tool, *args) || raise(ErrorDuringExecution.new(tool, args))
  end

  def require_install_name_tool?
    !!@require_install_name_tool
  end

  def change_dylib_id(id, file)
    log_relocate(:cc, file, :id_dylib, :old => file.dylib_id, :new => id)
    puts "Changing dylib ID of #{file}\n  from #{file.dylib_id}\n    to #{id}" if ARGV.debug?
    install_name_tool("-id", id, file)
  end

  def change_install_name(old, new, file)
    log_relocate(:cc, file, :load_dylib, :old => old, :new => new)
    puts "Changing install name in #{file}\n  from #{old}\n    to #{new}" if ARGV.debug?
    install_name_tool("-change", old, new, file)
  end
end
