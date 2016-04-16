require "utils/bottles"
require "formula"
require "thread"

module Homebrew
  module Cleanup
    @@disk_cleanup_size = 0

    def self.cleanup
      cleanup_cellar
      cleanup_cache
      cleanup_logs
      unless ARGV.dry_run?
        cleanup_lockfiles
        rm_DS_Store
      end
    end

    def self.update_disk_cleanup_size(path_size)
      @@disk_cleanup_size += path_size
    end

    def self.disk_cleanup_size
      @@disk_cleanup_size
    end

    def self.cleanup_formula(formula)
      formula.eligible_kegs_for_cleanup.each do |keg|
        cleanup_path(keg) { keg.uninstall }
      end
    end

    def self.cleanup_logs
      return unless HOMEBREW_LOGS.directory?
      HOMEBREW_LOGS.subdirs.each do |dir|
        cleanup_path(dir) { dir.rmtree } if prune?(dir, :days_default => 14)
      end
    end

    def self.cleanup_cellar
      Formula.installed.each do |formula|
        cleanup_formula formula
      end
    end

    def self.cleanup_cache(cache = HOMEBREW_CACHE)
      return unless cache.directory?

      cache.children.each do |path|
        if path.to_s.end_with? ".incomplete"
          cleanup_path(path) { path.unlink }
          next
        end

        if %w[java_cache npm_cache].include?(path.basename.to_s) && path.directory?
          cleanup_path(path) { FileUtils.rm_rf path }
          next
        end

        is_resource = path.basename.to_s.include?("--")

        if prune?(path)
          if path.file?
            cleanup_path(path) { path.unlink }
          elsif path.directory? && is_resource
            cleanup_path(path) { FileUtils.rm_rf path }
          end
          next
        end

        next unless path.file? || (path.directory? && is_resource)

        version = nil
        if is_resource
          name, resource = path.basename.to_s.split("--", 2)
          if resource && resource.start_with?("patch-")
            kind = :patch
          else
            kind = :resource
          end
        else
          if Pathname::BOTTLE_EXTNAME_RX === path.to_s
            kind = :bottle
            version = Utils::Bottles.resolve_version(path) rescue path.version
          else
            kind = :source
            version = path.version
          end
          next unless version # TODO: Report missing version.
          name = path.basename.to_s[/^(.*)-(?:#{Regexp.escape(version)})/, 1]
        end

        if ARGV.flag?("--list") # Because `--debug` is a bit too noisy.
          kind_s = kind.to_s.ljust(8)
          version_s = " (#{version})" if version
          puts "[#{kind_s}] #{name}#{version_s} => #{path.basename}"
        end

        # FIXME: Validate name, e.g., use `Formula.valid_name?`!
        next unless name # TODO: Report missing name.

        next unless HOMEBREW_CELLAR.directory?
        begin
          f = Formulary.from_rack(HOMEBREW_CELLAR/name)
        rescue FormulaUnavailableError, TapFormulaAmbiguityError, TapFormulaWithOldnameAmbiguityError
          opoo "No formula for '#{name}' (#{path})." if ARGV.homebrew_developer?
          next
        end

        is_stale = path_is_stale(f, path, kind, version)
        is_unneeded = ARGV.flag?("--scrub") && !f.installed?

        if is_stale || is_unneeded || Utils::Bottles.file_outdated?(f, path)
          if path.file?
            cleanup_path(path) { path.unlink }
          elsif path.directory? && is_resource
            cleanup_path(path) { FileUtils.rm_rf(path) }
          end
        end
      end
    end

    def self.path_is_stale(formula, path, kind, version)
      case kind
      when :patch
        patch_is_stale(formula, path)
      when :resource
        resource_is_stale(formula, path)
      when :bottle, :source
        if PkgVersion === version
          formula.pkg_version > version
        else
          formula.version > version
        end
      end
    end

    def self.patch_is_stale(formula, path)
      [:stable, :devel, :head].each do |spec_symbol|
        spec = formula.send(spec_symbol)
        next if spec.nil?

        spec.patches.each do |patch|
          next unless patch.is_a?(ExternalPatch)
          return false if path == patch.cached_download
        end
      end

      true
    end

    def self.resource_is_stale(formula, path)
      [:stable, :devel, :head].each do |spec_symbol|
        spec = formula.send(spec_symbol)
        next if spec.nil?

        resources = spec.resources.values.map(&:cached_download)
        resources << spec.cached_download
        return false if resources.include?(path)
      end

      true
    end

    def self.cleanup_path(path)
      if ARGV.dry_run?
        puts "Would remove: #{path} (#{path.abv})"
      else
        puts "Removing: #{path}... (#{path.abv})"
        yield
      end

      update_disk_cleanup_size(path.disk_usage)
    end

    def self.cleanup_lockfiles
      return unless HOMEBREW_CACHE_FORMULA.directory?
      candidates = HOMEBREW_CACHE_FORMULA.children
      lockfiles  = candidates.select { |f| f.file? && f.extname == ".brewing" }
      lockfiles.each do |file|
        next unless file.readable?
        file.open.flock(File::LOCK_EX | File::LOCK_NB) && file.unlink
      end
    end

    def self.rm_DS_Store
      paths = Queue.new
      %w[Cellar Frameworks Library bin etc include lib opt sbin share var].
        map { |p| HOMEBREW_PREFIX/p }.each { |p| paths << p if p.exist? }
      workers = (0...Hardware::CPU.cores).map do
        Thread.new do
          begin
            while p = paths.pop(true)
              quiet_system "find", p, "-name", ".DS_Store", "-delete"
            end
          rescue ThreadError # ignore empty queue error
          end
        end
      end
      workers.map(&:join)
    end

    def self.prune?(path, options = {})
      @time ||= Time.now

      path_modified_time = path.mtime
      days_default = options[:days_default]

      prune = ARGV.value "prune"

      return true if prune == "all"

      prune_time = if prune
        @time - 60 * 60 * 24 * prune.to_i
      elsif days_default
        @time - 60 * 60 * 24 * days_default.to_i
      end

      return false unless prune_time

      path_modified_time < prune_time
    end
  end
end
