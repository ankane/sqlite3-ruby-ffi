module SQLite3
  class Statement
    def prepare(db, sql)
      sql = FFI.string_value(sql)

      @db = db # so can check if discarded
      db = db.instance_variable_get(:@db)
      stmt = ::FFI::MemoryPointer.new(:pointer)
      tail = ::FFI::MemoryPointer.new(:pointer)
      status = FFI::CApi.sqlite3_prepare_v2(db, sql, sql.bytesize, stmt, tail)
      FFI.check_prepare(db, status, sql)

      @stmt = stmt.read_pointer
      @db.instance_variable_set(:@stmt_deadline, nil)

      tail.read_pointer.read_string.force_encoding(Encoding::UTF_8)
    end

    def close
      require_open_stmt

      FFI::CApi.sqlite3_finalize(@stmt)
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

      value = FFI::CApi.sqlite3_step(stmt)
      if FFI.rb_errinfo
        exception = FFI.rb_errinfo
        FFI.rb_errinfo = nil
        raise exception
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
      when FFI::CApi::SQLITE_DONE
        @done = true
        return nil
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
          status = FFI::CApi.sqlite3_bind_blob(@stmt, index, value, value.bytesize, FFI::CApi::SQLITE_TRANSIENT)
        elsif value.encoding == Encoding::UTF_16LE || value.encoding == Encoding::UTF_16BE
          status = FFI::CApi.sqlite3_bind_text16(@stmt, index, value, value.bytesize, FFI::CApi::SQLITE_TRANSIENT)
        else
          if value.encoding != Encoding::UTF_8 && value.encoding != Encoding::US_ASCII
            value = value.encode(Encoding::UTF_8)
          end
          status = FFI::CApi.sqlite3_bind_text(@stmt, index, value, value.bytesize, FFI::CApi::SQLITE_TRANSIENT)
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

      FFI::CApi.sqlite3_column_decltype(@stmt, index)
    end

    def bind_parameter_count
      require_live_db
      require_open_stmt

      FFI::CApi.sqlite3_bind_parameter_count(@stmt)
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

      FFI::CApi.sqlite3_expanded_sql(@stmt).force_encoding(Encoding::UTF_8).freeze
    end

    private

    def require_open_stmt
      if closed?
        raise SQLite3::Exception, "cannot use a closed statement"
      end
    end

    def require_live_db
      if @db.instance_variable_get(:@discarded)
        raise SQLite3::Exception, "cannot use a statement associated with a discarded database"
      end
    end
  end
end
