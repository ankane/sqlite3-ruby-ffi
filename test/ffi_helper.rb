module SQLite3::FFI::TestCase
  def before_setup
    skip_tests = []

    # not needed when stress testing
    if stress? || i_am_running_in_valgrind
      skip_tests << "IntegrationAggregateTestCase#test_multi_argument_step_arguments_survive_gc"
    end
    skip_tests << "SQLite3::TestDatabase#test_function_gc_segfault" if stress?

    # can use JRUBY_OPTS=-X+O to enable ObjectSpace.each_object, but behavior differs
    if RUBY_ENGINE == "jruby"
      skip_tests << "IntegrationAggregateTestCase#test_aggregate_instances_are_released_after_each_query"
      skip_tests << "SQLite3::TestCollation#test_replacing_a_collation_releases_the_previous_comparator"
    end

    skip if skip_tests.include?("#{self.class.name}##{name}")

    super
  end

  def stress?
    gc_level == :stress
  end
end

SQLite3::TestCase.prepend(SQLite3::FFI::TestCase)
