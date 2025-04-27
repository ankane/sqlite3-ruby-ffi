class SQLite3::TestCase
  def before_setup
    skip_tests = []
    # only fail locally
    if RbConfig::CONFIG["host_os"] =~ /darwin/i
      skip_tests << "SQLite3::TestDatabase#test_load_extension_is_defined_on_expected_platforms"
      skip_tests << "SQLite3::TestDiscardDatabase#test_fork_does_not_discard_readonly_connections"
    end
    skip_tests << "SQLite3::TestDatabase#test_function_gc_segfault" if stress?
    skip if skip_tests.include?("#{self.class.name}##{name}")

    GC.stress = true if stress?
    super
  end

  def after_teardown
    GC.stress = false if stress?
    super
  end

  def stress?
    ENV["STRESS"]
  end
end
