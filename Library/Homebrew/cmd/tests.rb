#: @hide_from_man_page
#:  * `tests` [`-v`] [`--coverage`] [`--generic`] [`--no-compat`] [`--only=`<test_script/test_method>] [`--seed` <seed>] [`--trace`] [`--online`] [`--official-cmd-taps`]:
#:    Run Homebrew's unit and integration tests.

require "fileutils"
require "tap"

module Homebrew
  def tests
    ENV["HOMEBREW_NO_ANALYTICS_THIS_RUN"] = "1"

    (HOMEBREW_LIBRARY/"Homebrew/test").cd do
      Homebrew.install_gem_setup_path! "bundler"
      unless quiet_system("bundle", "check")
        system "bundle", "install", "--path", "vendor/bundle"
      end

      args, envs = setup_args_and_envs
      print_args_and_envs(args, envs) if ARGV.debug? || ARGV.dry_run?
      return if ARGV.dry_run?

      ohai "Running `rake test`..." if ARGV.debug?
      ENV.update(envs)
      system "bundle", "exec", "rake", "test", *args
      Homebrew.failed = !$?.success?
    end

    fs_leak_log = HOMEBREW_LIBRARY/"Homebrew/test/fs_leak_log"
    if fs_leak_log.file?
      fs_leak_log_content = fs_leak_log.read
      unless fs_leak_log_content.empty?
        ofail "Detected a file leak"
        puts fs_leak_log_content
      end
    end
  end

  private

  def print_args_and_envs(args, envs)
    ohai "Test arguments:", args unless args.empty?
    ohai "Test environment:", envs.map { |kv| kv.join("=") } unless envs.empty?
  end

  def setup_args_and_envs
    args = []
    envs = {}

    # Extra arguments that accumulate or require special handling.
    args_extra = Hash.new { |hash, key| hash[key] = [] }

    # Override author/committer as global settings might be invalid and thus
    # will cause silent failure during the setup of dummy Git repositories.
    %w[AUTHOR COMMITTER].each do |role|
      envs["GIT_#{role}_NAME"] = "brew tests"
      envs["GIT_#{role}_EMAIL"] = "brew-tests@localhost"
    end

    # Handle most arguments.
    args << "--trace" if ARGV.include? "--trace"
    args_extra["TESTOPTS"] << "-v" if ARGV.verbose?
    envs["HOMEBREW_NO_COMPAT"] = "1" if ARGV.include? "--no-compat"
    envs["HOMEBREW_TEST_GENERIC_OS"] = "1" if ARGV.include? "--generic"
    envs["HOMEBREW_NO_GITHUB_API"] = "1" unless ARGV.include? "--online"
    if ARGV.include? "--official-cmd-taps"
      envs["HOMEBREW_TEST_OFFICIAL_CMD_TAPS"] = "1"
    end
    if ARGV.include? "--coverage"
      envs["HOMEBREW_TESTS_COVERAGE"] = "1"
      FileUtils.rm_f "coverage/.resultset.json"
    end

    # Make it easier to reproduce test runs.
    args_extra["SEED"] << ARGV.next if ARGV.include? "--seed"

    # Make it easier to run a single test script/method.
    if ARGV.value("only")
      envs["HOMEBREW_TESTS_ONLY"] = "1"
      test_script, test_method = ARGV.value("only").split("/", 2)
      args_extra["TEST"] << "test_#{test_script}.rb"
      args_extra["TESTOPTS"] << "--name=test_#{test_method}" if test_method
    end

    # Handle user-supplied extra arguments like `TESTOPTS=<something>`.
    ARGV.named.select { |arg| arg[/^[A-Z]+=/] }.each do |arg|
      key, _, val = arg.partition("=")
      case key
      when "TESTOPTS"
        args_extra[key] << val
      else
        raise "Variable #{key} was already set." if args_extra.key?(key)
        args_extra[key] = [val]
      end
    end
    args += args_extra.map { |key, list| "#{key}=#{list.join(" ")}" }

    [args, envs]
  end
end
