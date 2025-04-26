module SQLite3
  module FFI
    class AggregatorWrapper
      attr_reader :handler_klass, :instances

      def initialize(handler_klass)
        @handler_klass = handler_klass
        @instances = []
      end
    end

    class AggregatorInstance
      attr_accessor :handler_instance
    end

    def self.aggregate_instance(ctx)
      aw = FFI.unwrap(CApi.sqlite3_user_data(ctx))
      handler_klass = aw.handler_klass
      inst_ptr = CApi.sqlite3_aggregate_context(ctx, 8)

      if inst_ptr.null?
        fatal "SQLite is out-of-merory"
      end

      if inst_ptr.read_pointer.null?
        instances = aw.instances

        inst = AggregatorInstance.new
        inst.handler_instance = handler_klass.new
        instances << inst
        inst_ptr.write_pointer(FFI.wrap(inst))
      else
        inst = FFI.unwrap(inst_ptr.read_pointer)
      end

      if inst.nil?
        fatal "SQLite called us back on an already destroyed aggregate instance"
      end

      inst
    end

    def self.aggregate_instance_destroy(ctx)
      aw = FFI.unwrap(CApi.sqlite3_user_data(ctx))
      instances = aw.instances
      inst_ptr = CApi.sqlite3_aggregate_context(ctx, 0)

      if inst_ptr.null? || inst_ptr.read_pointer.null?
        return
      end

      inst = FFI.unwrap(inst_ptr.read_pointer)

      if inst.nil?
        fatal "attempt to destroy aggregate instance twice"
      end

      inst.handler_instance = nil
      if instances.delete(inst).nil?
        fatal "must be in instances at that point"
      end

      inst_ptr.write_pointer(::FFI::Pointer.new(0))
    end

    AGGREGATOR_STEP = ::FFI::Function.new(:void, [:pointer, :int, :pointer]) do |ctx, argc, argv|
      begin
        inst = aggregate_instance(ctx)
        handler_instance = inst.handler_instance
        params = argv.read_array_of_pointer(argc).map { |v| FFI.sqlite3val2rb(v) }
        handler_instance.step(*params)
      rescue => e
        FFI.rb_errinfo = e
      end
    end

    AGGREGATOR_FINAL = ::FFI::Function.new(:void, [:pointer]) do |ctx|
      begin
        inst = aggregate_instance(ctx)
        handler_instance = inst.handler_instance
        result = handler_instance.finalize
        FFI.set_sqlite3_func_result(ctx, result)
        aggregate_instance_destroy(ctx)
      rescue => e
        FFI.rb_errinfo = e
      end
    end
  end
end
