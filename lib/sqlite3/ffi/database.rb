module SQLite3
  class Database
    def close
      close_or_discard_db
      @aggregators = nil
      self
    end

    def closed?
      @db.nil?
    end

    def total_changes
      require_open_db

      FFI::CApi.sqlite3_total_changes(@db)
    end

    def trace(blk = nil, &block)
      require_open_db

      blk ||= block
      @tracefunc = blk
      FFI::CApi.sqlite3_trace_v2(@db, FFI::CApi::SQLITE_TRACE_STMT, blk.nil? ? nil : FFI::TRACE, FFI.wrap(blk))
      self
    end

    def busy_handler(blk = nil, &block)
      require_open_db

      blk ||= block
      @busy_handler = blk
      status = FFI::CApi.sqlite3_busy_handler(@db, FFI::BUSY_HANDLER, FFI.wrap(self))
      FFI.check(@db, status)
      self
    end

    def statement_timeout=(milliseconds)
      @stmt_timeout = milliseconds.to_i
      n = milliseconds.to_i == 0 ? -1 : 1000
      FFI::CApi.sqlite3_progress_handler(@db, n, FFI::STATEMENT_TIMEOUT, FFI.wrap(self))
      self
    end

    def last_insert_row_id
      require_open_db

      FFI::CApi.sqlite3_last_insert_rowid(@db)
    end

    def define_function_with_flags(name, flags, &block)
      require_open_db

      status = FFI::CApi.sqlite3_create_function(@db, FFI.string_value(name), block.arity, flags, FFI.wrap(block), FFI::FUNC, nil, nil)
      FFI.check(@db, status)
      @functions[name] = block
      self
    end

    def define_function(name, &block)
      define_function_with_flags(name, FFI::CApi::SQLITE_UTF8, &block)
    end

    def interrupt
      require_open_db

      FFI::CApi.sqlite3_interrupt(@db)
      self
    end

    def errmsg
      require_open_db

      FFI::CApi.sqlite3_errmsg(@db)
    end

    def errcode
      require_open_db

      FFI::CApi.sqlite3_errcode(@db)
    end

    def complete?(sql)
      FFI::CApi.sqlite3_complete(FFI.string_value(sql)) != 0
    end

    def changes
      require_open_db

      FFI::CApi.sqlite3_changes(@db)
    end

    def authorizer=(authorizer)
      require_open_db

      status = FFI::CApi.sqlite3_set_authorizer(@db, authorizer.nil? ? nil : FFI::AUTH, FFI.wrap(authorizer))
      FFI.check(@db, status)
      @authorizer = authorizer
    end

    def busy_timeout=(timeout)
      require_open_db

      FFI.check(@db, FFI::CApi.sqlite3_busy_timeout(@db, timeout))
    end

    def extended_result_codes=(enable)
      require_open_db

      FFI::CApi.sqlite3_extended_result_codes(@db, enable ? 1 : 0)
      self
    end

    def collation(name, comparator)
      require_open_db

      status = FFI::CApi.sqlite3_create_collation(@db, name, FFI::CApi::SQLITE_UTF8, FFI.wrap(comparator), comparator.nil? ? nil : FFI::COMPARATOR)
      FFI.check(@db, status)
      @collations[name] = comparator
      self
    end

    if FFI::CApi::HAVE_SQLITE3_ENABLE_LOAD_EXTENSION && FFI::CApi::HAVE_SQLITE3_LOAD_EXTENSION
      def enable_load_extension(onoff)
        require_open_db

        if onoff == true
          onoffparam = 1
        elsif onoff == false
          onoffparam = 0
        else
          onoffparam = onoff.to_i
        end
        FFI.check(@db, FFI::CApi.sqlite3_enable_load_extension(@db, onoffparam))
        self
      end
    end

    def transaction_active?
      require_open_db

      FFI::CApi.sqlite3_get_autocommit(@db).zero?
    end

    def exec_batch(sql, results_as_hash)
      require_open_db

      callback_ary = []
      err_msg = ::FFI::MemoryPointer.new(:pointer)
      callback = results_as_hash == true ? FFI::HASH_CALLBACK : FFI::REGULAR_CALLBACK
      status = FFI::CApi.sqlite3_exec(@db, FFI.string_value(sql), callback, FFI.wrap(callback_ary), err_msg)
      FFI.check_msg(@db, status, err_msg)
      callback_ary
    end

    def db_filename(db_name)
      require_open_db

      fname = FFI::CApi.sqlite3_db_filename(@db, db_name)
      fname.null? ? nil : fname.read_string.force_encoding(Encoding::UTF_8)
    end

    private

    def require_open_db
      if @db.nil?
        raise SQLite3::Exception, "cannot use a closed database"
      end
    end

    def discard_db
      sfile = ::FFI::MemoryPointer.new(:pointer)

      FFI::CApi.sqlite3_db_release_memory(@db)

      if FFI::CApi::HAVE_SQLITE3_DB_NAME
        j_db = 0
        while !(db_name = FFI::CApi.sqlite3_db_name(@db, j_db)).null?
          status = FFI::CApi.sqlite3_file_control(@db, db_name, FFI::CApi::SQLITE_FCNTL_FILE_POINTER, sfile)
          if status == 0
            # TODO
          end
          j_db += 1
        end
      else
        status = FFI::CApi.sqlite3_file_control(@db, nil, FFI::CApi::SQLITE_FCNTL_FILE_POINTER, sfile)
        if status == 0
          # TODO
        end
      end

      status = FFI::CApi.sqlite3_file_control(@db, nil, FFI::CApi::SQLITE_FCNTL_JOURNAL_POINTER, sfile)
      if status == 0
        # TODO
      end

      @db = nil
      @discarded = true
    end

    def close_or_discard_db
      unless @db.nil?
        if @readonly || @owner == Process.pid
          FFI::CApi.sqlite3_close_v2(@db)
          @db = nil
        else
          discard_db
        end
      end
    end

    def utf16_string_value_ptr(str)
      str + "\x00\x00".encode(Encoding::UTF_16LE)
    end

    def open_v2(file, flags, zvfs)
      db = ::FFI::MemoryPointer.new(:pointer)
      status = FFI::CApi.sqlite3_open_v2(FFI.string_value(file), db, flags, zvfs)
      @db = db.read_pointer
      FFI.check(@db, status)
      if (flags & FFI::CApi::SQLITE_OPEN_READONLY) != 0
        @readonly = true
      end
      @owner = Process.pid
      self
    end

    def disable_quirk_mode
      return false if @db.nil?

      FFI::CApi.sqlite3_db_config(@db, FFI::CApi::SQLITE_DBCONFIG_DQS_DDL, :int, 0, :pointer, nil)
      FFI::CApi.sqlite3_db_config(@db, FFI::CApi::SQLITE_DBCONFIG_DQS_DML, :int, 0, :pointer, nil)
      true
    end

    def discard
      discard_db
      @aggregators = nil
      self
    end

    if FFI::CApi::HAVE_SQLITE3_LOAD_EXTENSION
      def load_extension_internal(file)
        require_open_db

        err_msg = ::FFI::MemoryPointer.new(:pointer)
        status = FFI::CApi.sqlite3_load_extension(@db, FFI.string_value(file), nil, err_msg)
        FFI.check_msg(@db, status, err_msg)
        self
      end
    end

    def open16(file)
      db = ::FFI::MemoryPointer.new(:pointer)
      status = FFI::CApi.sqlite3_open16(utf16_string_value_ptr(file), db)
      @db = db.read_pointer
      FFI.check(@db, status)
      status
    end

    def define_aggregator2(aggregator, ruby_name)
      require_open_db

      if aggregator.respond_to?(:arity)
        arity = aggregator.arity
      else
        arity = -1
      end

      if arity < -1 || arity > 127
        raise ArgumentError, "Aggregator arity=#{arity} out of range -1..127"
      end

      aw = FFI::AggregatorWrapper.new(aggregator)
      status = FFI::CApi.sqlite3_create_function(@db, FFI.string_value(ruby_name), arity, FFI::CApi::SQLITE_UTF8, FFI.wrap(aw), nil, FFI::AGGREGATOR_STEP, FFI::AGGREGATOR_FINAL)
      FFI.check(@db, status)

      @aggregators ||= []
      @aggregators << aw

      self
    end
  end
end
