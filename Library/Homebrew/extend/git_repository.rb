require "utils/git"
require "utils/popen"

module GitRepositoryExtension
  def git?
    join(".git").exist?
  end

  def git_origin(remote = "origin")
    return unless git? && Utils.git_available?
    cd do
      # Much nicer than the fallback below, but requires Git 2.7.0 or newer.
      url = Utils.popen_read("git", "remote", "get-url", remote).chuzzle
      return url if $?.success?

      # Works with all Git versions, but requires grepping & additional checks.
      info = Utils.popen_read("git", "remote", "show", "-n", remote)
      url = info[/^\s+Fetch URL: (.+)$/, 1]
      return url unless url == remote

      # Return nil if all attempts failed (remote doesn't exist or has no URL).
    end
  end

  def git_head
    return unless git? && Utils.git_available?
    cd do
      Utils.popen_read("git", "rev-parse", "--verify", "-q", "HEAD").chuzzle
    end
  end

  def git_short_head
    return unless git? && Utils.git_available?
    cd do
      Utils.popen_read(
        "git", "rev-parse", "--short=4", "--verify", "-q", "HEAD"
      ).chuzzle
    end
  end

  def git_last_commit
    return unless git? && Utils.git_available?
    cd do
      Utils.popen_read("git", "show", "-s", "--format=%cr", "HEAD").chuzzle
    end
  end

  def git_last_commit_date
    return unless git? && Utils.git_available?
    cd do
      Utils.popen_read(
        "git", "show", "-s", "--format=%cd", "--date=short", "HEAD"
      ).chuzzle
    end
  end
end
