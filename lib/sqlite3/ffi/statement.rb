module SQLite3
  class Statement
    def prepare(db, sql)
      @db_ctx = db.instance_variable_get(:@ctx)
      @db_ctx.stmt_deadline = nil

      sql_cstr = FFI.string_value(sql)
      sql_len = FFI.rstring_lenint(sql)

      db = @db_ctx.db
      stmt = ::FFI::MemoryPointer.new(:pointer)
      tail = ::FFI::MemoryPointer.new(:pointer)
      frame = FFI::CallbackFrame.new
      FFI.push_callback_frame(frame)
      status = FFI::CApi.sqlite3_prepare_v2(db, sql_cstr, sql_len, stmt, tail)
      # sqlite3_finalize is no-op on NULL pointer
      @stmt = ::FFI::AutoPointer.new(stmt.read_pointer, FFI::CApi.method(:sqlite3_finalize))
      if (callback_state = FFI.pop_callback_frame(frame))
        raise callback_state
      end

      FFI.check_prepare(db, status, sql)

      tail.read_pointer.read_string.force_encoding(Encoding::UTF_8)
    end

    def close
      require_open_stmt

      @stmt.free
      @stmt = nil
    end

    def closed?
      @stmt.nil? || @stmt.null?
    end

    def step
      require_live_db
      require_open_stmt

      return nil if @done

      stmt = @stmt

      if FFI::CApi.sqlite3_stmt_busy(stmt) == 0
        @db_ctx.stmt_deadline = nil
      end

      frame = FFI::CallbackFrame.new
      FFI.push_callback_frame(frame)
      value = FFI::CApi.sqlite3_step(stmt)
      if (callback_state = FFI.pop_callback_frame(frame))
        raise callback_state
      end

      if value == FFI::CApi::SQLITE_DONE
        @done = true
        return nil
      end

      length = FFI::CApi.sqlite3_column_count(stmt)
      list = []

      case value
      when FFI::CApi::SQLITE_ROW
        length.times do |i|
          case FFI::CApi.sqlite3_column_type(stmt, i)
          when FFI::CApi::SQLITE_INTEGER
            val = FFI::CApi.sqlite3_column_int64(stmt, i)
          when FFI::CApi::SQLITE_FLOAT
            val = FFI::CApi.sqlite3_column_double(stmt, i)
          when FFI::CApi::SQLITE_TEXT
            len = FFI::CApi.sqlite3_column_bytes(stmt, i)
            val = FFI::CApi.sqlite3_column_text(stmt, i).read_bytes(len).force_encoding(Encoding::UTF_8)
            if Encoding.default_internal
              val = val.encode(Encoding.default_internal)
            end
            val.freeze
          when FFI::CApi::SQLITE_BLOB
            len = FFI::CApi.sqlite3_column_bytes(stmt, i)
            val = FFI::CApi.sqlite3_column_blob(stmt, i).read_bytes(len)
            val.freeze
          when FFI::CApi::SQLITE_NULL
            val = nil
          else
            raise RuntimeError, "bad type"
          end
          list << val
        end
      else
        FFI::CApi.sqlite3_reset(stmt)
        @done = false
        FFI.check(FFI::CApi.sqlite3_db_handle(stmt), value)
      end

      list.freeze
      list
    end

    def bind_param(key, value)
      require_live_db
      require_open_stmt

      case key
      when Symbol, String
        key = key.to_s
        key = ":" + key if key[0] != ":"
        index = FFI::CApi.sqlite3_bind_parameter_index(@stmt, key)
      else
        index = key.to_i
      end

      if index == 0
        raise SQLite3::Exception, "no such bind parameter"
      end

      case value
      when String
        if value.is_a?(Blob) || value.encoding == Encoding::BINARY
          status = FFI::CApi.sqlite3_bind_blob(@stmt, index, value, FFI.rstring_lenint(value), FFI::CApi::SQLITE_TRANSIENT)
        elsif value.encoding == Encoding::UTF_16LE || value.encoding == Encoding::UTF_16BE
          status = FFI::CApi.sqlite3_bind_text16(@stmt, index, value, FFI.rstring_lenint(value), FFI::CApi::SQLITE_TRANSIENT)
        else
          if value.encoding != Encoding::UTF_8 && value.encoding != Encoding::US_ASCII
            value = value.encode(Encoding::UTF_8)
          end
          status = FFI::CApi.sqlite3_bind_text(@stmt, index, +value, FFI.rstring_lenint(value), FFI::CApi::SQLITE_TRANSIENT)
        end
      when Float
        status = FFI::CApi.sqlite3_bind_double(@stmt, index, value)
      when Integer
        status = FFI::CApi.sqlite3_bind_int64(@stmt, index, value)
      when NilClass
        status = FFI::CApi.sqlite3_bind_null(@stmt, index)
      else
        raise RuntimeError, "can't prepare #{value.class.name}"
      end

      FFI.check(FFI::CApi.sqlite3_db_handle(@stmt), status)

      self
    end

    def reset!
      require_live_db
      require_open_stmt

      FFI::CApi.sqlite3_reset(@stmt)
      @done = false
      self
    end

    def clear_bindings!
      require_live_db
      require_open_stmt

      FFI::CApi.sqlite3_clear_bindings(@stmt)
      @done = false
    end

    def done?
      @done
    end

    def column_count
      require_live_db
      require_open_stmt

      FFI::CApi.sqlite3_column_count(@stmt)
    end

    def column_name(index)
      require_live_db
      require_open_stmt

      name = FFI::CApi.sqlite3_column_name(@stmt, index)
      name ? FFI.interned_utf8_cstr(name) : nil
    end

    def column_decltype(index)
      require_live_db
      require_open_stmt

      name = FFI::CApi.sqlite3_column_decltype(@stmt, index)
      name ? name.force_encoding(Encoding::UTF_8) : nil
    end

    def column_decltype_downcased(index)
      require_live_db
      require_open_stmt

      name = FFI::CApi.sqlite3_column_decltype(@stmt, index)
      name ? FFI.interned_downcased_utf8_cstr(name) : nil
    end

    def bind_parameter_count
      require_live_db
      require_open_stmt

      FFI::CApi.sqlite3_bind_parameter_count(@stmt)
    end

    def named_params
      require_live_db
      require_open_stmt

      param_count = FFI::CApi.sqlite3_bind_parameter_count(@stmt)
      params = []

      1.upto(param_count) do |i|
        name = FFI::CApi.sqlite3_bind_parameter_name(@stmt, i)
        if name && name[0] != "?"
          param = FFI.interned_utf8_cstr(name[1..])
          params << param
        end
      end
      params.freeze
    end

    STMT_STAT_SYMBOLS = {
      fullscan_steps: FFI::CApi::SQLITE_STMTSTATUS_FULLSCAN_STEP,
      sorts: FFI::CApi::SQLITE_STMTSTATUS_SORT,
      autoindexes: FFI::CApi::SQLITE_STMTSTATUS_AUTOINDEX,
      vm_steps: FFI::CApi::SQLITE_STMTSTATUS_VM_STEP
    }
    private_constant :STMT_STAT_SYMBOLS

    def stats_as_hash
      require_live_db
      require_open_stmt

      STMT_STAT_SYMBOLS.to_h do |k, stat_type|
        [k, FFI::CApi.sqlite3_stmt_status(@stmt, stat_type, 0)]
      end
    end

    def stat_for(key)
      require_live_db
      require_open_stmt

      if !key.is_a?(Symbol)
        raise TypeError, "non-symbol given"
      end

      stat_type = STMT_STAT_SYMBOLS[key]
      if !stat_type
        raise ArgumentError, "unknown key: #{key}"
      end

      FFI::CApi.sqlite3_stmt_status(@stmt, stat_type, 0)
    end

    def sql
      require_live_db
      require_open_stmt

      FFI::CApi.sqlite3_sql(@stmt).force_encoding(Encoding::UTF_8).freeze
    end

    def expanded_sql
      require_live_db
      require_open_stmt

      expanded_sql = FFI::CApi.sqlite3_expanded_sql(@stmt)
      rb_expanded_sql = expanded_sql.read_string.force_encoding(Encoding::UTF_8).freeze
      FFI::CApi.sqlite3_free(expanded_sql)

      rb_expanded_sql
    end

    private

    def require_open_stmt
      if closed?
        raise SQLite3::Exception, "cannot use a closed statement"
      end
    end

    def require_live_db
      if @db_ctx.discarded
        raise SQLite3::Exception, "cannot use a statement associated with a discarded database"
      end
    end
  end
end
