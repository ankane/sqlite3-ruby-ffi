module SQLite3
  module FFI
    COMPARATOR = ::FFI::Function.new(:int, [:pointer, :int, :pointer, :int, :pointer]) do |ctx, a_len, a, b_len, b|
      comparator = unwrap(ctx)
      a_str = a.read_bytes(a_len).force_encoding(Encoding::UTF_8)
      b_str = b.read_bytes(b_len).force_encoding(Encoding::UTF_8)

      if Encoding.default_internal
        a_str = a_str.encode(Encoding.default_internal)
        b_str = b_str.encode(Encoding.default_internal)
      end

      comparator.compare(a_str, b_str)
    end

    TRACE = ::FFI::Function.new(:int, [:uint, :pointer, :pointer, :pointer]) do |_, ctx, _, x|
      unwrap(ctx).call(x.read_string)
      0
    end

    AUTH = ::FFI::Function.new(:int, [:pointer, :int, :string, :string, :string, :string]) do |ctx, op_id, s1, s2, s3, s4|
      result = unwrap(ctx).call(op_id, s1, s2, s3, s4)
      if result.is_a?(Integer)
        result
      elsif result == true
        CApi::SQLITE_OK
      elsif result == false
        CApi::SQLITE_DENY
      else
        CApi::SQLITE_IGNORE
      end
    end

    HASH_CALLBACK = ::FFI::Function.new(:int, [:pointer, :int, :pointer, :pointer]) do |ctx, count, data, columns|
      callback_ary = unwrap(ctx)
      new_hash = {}
      data.read_array_of_pointer(count).zip(columns.read_array_of_pointer(count)) do |value, column|
        new_hash[column.read_string] = value.null? ? nil : value.read_string
      end
      callback_ary << new_hash
      0
    end

    REGULAR_CALLBACK = ::FFI::Function.new(:int, [:pointer, :int, :pointer, :pointer]) do |ctx, count, data, columns|
      callback_ary = unwrap(ctx)
      new_ary = []
      data.read_array_of_pointer(count).each do |value|
        new_ary << (value.null? ? nil : value.read_string)
      end
      callback_ary << new_ary
      0
    end

    STATEMENT_TIMEOUT = ::FFI::Function.new(:int, [:pointer]) do |ctx|
      ctx = unwrap(ctx)
      current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if ctx.instance_variable_get(:@stmt_deadline).nil?
        ctx.instance_variable_set(:@stmt_deadline, current_time)
        0
      elsif current_time >= ctx.instance_variable_get(:@stmt_deadline)
        1
      else
        0
      end
    end

    BUSY_HANDLER = ::FFI::Function.new(:int, [:pointer, :int]) do |ctx, count|
      handler = unwrap(ctx).instance_variable_get(:@busy_handler)
      result = handler.(count)
      result == false ? 0 : 1
    end

    FUNC = ::FFI::Function.new(:void, [:pointer, :int, :pointer]) do |ctx, argc, argv|
      callable = unwrap(CApi.sqlite3_user_data(ctx))
      params = argv.read_array_of_pointer(argc).map { |v| FFI.sqlite3val2rb(v) }
      result = callable.(*params)
      FFI.set_sqlite3_func_result(ctx, result)
    end
  end
end
