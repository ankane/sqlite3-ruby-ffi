class SQLite3::TestCase
  def before_setup
    skip_tests = [
      "SQLite3::TestDatabase#test_load_extension_is_defined_on_expected_platforms",
      "SQLite3::TestDiscardDatabase#test_fork_does_not_discard_readonly_connections",
      "SQLite3::TestStatement#test_column_names_are_deduped"
    ]
    skip_tests << "SQLite3::TestDatabase#test_function_gc_segfault" if stress?
    # TODO report bug
    if RUBY_ENGINE == "truffleruby"
      skip_tests << "IntegrationStatementTestCase#test_long_running_statements_get_interrupted_when_statement_timeout_set"
    end
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
