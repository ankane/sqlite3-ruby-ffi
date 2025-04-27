module SQLite3
  module FFI
    def self.sqlite3val2rb(val)
      case CApi.sqlite3_value_type(val)
      when CApi::SQLITE_INTEGER
        CApi.sqlite3_value_int64(val)
      when CApi::SQLITE_FLOAT
        CApi.sqlite3_value_double(val)
      when CApi::SQLITE_TEXT
        len = CApi.sqlite3_value_bytes(val)
        CApi.sqlite3_value_text(val).read_bytes(len).force_encoding(Encoding::UTF_8).freeze
      when CApi::SQLITE_BLOB
        len = CApi.sqlite3_value_bytes(val)
        CApi.sqlite3_value_text(val).read_bytes(len).freeze
      when CApi::SQLITE_NULL
        nil
      else
        raise RuntimeError, "bad type"
      end
    end

    def self.set_sqlite3_func_result(ctx, result)
      case result
      when NilClass
        CApi.sqlite3_result_null(ctx)
      when Integer
        CApi.sqlite3_result_int64(ctx, result)
      when Float
        CApi.sqlite3_result_double(ctx, result)
      when String
        if result.is_a?(Blob) || result.encoding == Encoding::BINARY
          CApi.sqlite3_result_blob(ctx, result, result.bytesize, CApi::SQLITE_TRANSIENT)
        else
          CApi.sqlite3_result_text(ctx, result, result.bytesize, CApi::SQLITE_TRANSIENT)
        end
      else
        raise RuntimeError, "can't return #{result.class.name}"
      end
    end

    def self.interned_utf8_cstr(str)
      -str
    end

    def self.string_value(obj)
      unless obj.respond_to?(:to_str)
        val =
          case obj
          when nil
            "nil"
          when true, false
            obj.to_s
          else
            obj.class.name
          end
        raise TypeError, "no implicit conversion of #{val} into String"
      end
      obj.to_str
    end

    RB_ERRINFO = :sqlite3_ffi_rb_errinfo

    def self.rb_errinfo
      Thread.current[RB_ERRINFO]
    end

    def self.rb_errinfo=(e)
      Thread.current[RB_ERRINFO] = e
    end

    OBJECT_REGISTRY = ObjectSpace::WeakMap.new

    def self.wrap(obj)
      OBJECT_REGISTRY[obj.object_id] = obj
      ::FFI::Pointer.new(obj.object_id)
    end

    def self.unwrap(ptr)
      OBJECT_REGISTRY[ptr.to_i] || (raise "object not found")
    end
  end
end
