module SQLite3
  class Database
    def close
      close_or_discard_db
      self
    end

    def closed?
      @ctx&.db.nil?
    end

    def total_changes
      require_open_db

      FFI::CApi.sqlite3_total_changes(@ctx.db)
    end

    def trace(blk = nil, &block)
      require_open_db

      blk ||= block
      @ctx.trace_handler = blk
      FFI::CApi.sqlite3_trace_v2(@ctx.db, FFI::CApi::SQLITE_TRACE_STMT, blk.nil? ? nil : FFI::TRACE, FFI.wrap(@ctx))
      self
    end

    def busy_handler(blk = nil, &block)
      require_open_db

      blk ||= block
      @ctx.busy_handler = blk
      status = FFI::CApi.sqlite3_busy_handler(@ctx.db, FFI::BUSY_HANDLER, FFI.wrap(@ctx))
      FFI.check(@ctx.db, status)
      self
    end

    def statement_timeout=(milliseconds)
      @ctx.stmt_timeout = milliseconds.to_i
      n = milliseconds.to_i == 0 ? -1 : 1000
      FFI::CApi.sqlite3_progress_handler(@ctx.db, n, FFI::STATEMENT_TIMEOUT, FFI.wrap(@ctx))
      self
    end

    def last_insert_row_id
      require_open_db

      FFI::CApi.sqlite3_last_insert_rowid(@ctx.db)
    end

    def define_function_with_flags(name, flags, &block)
      require_open_db

      status = FFI::CApi.sqlite3_create_function(@ctx.db, FFI.string_value(name), block.arity, flags, FFI.wrap(block), FFI::FUNC, nil, nil)
      FFI.check(@ctx.db, status)
      @functions << block
      @ctx.functions = @functions
      self
    end

    def define_function(name, &block)
      define_function_with_flags(name, FFI::CApi::SQLITE_UTF8, &block)
    end

    def interrupt
      require_open_db

      FFI::CApi.sqlite3_interrupt(@ctx.db)
      self
    end

    def errmsg
      require_open_db

      FFI::CApi.sqlite3_errmsg(@ctx.db)
    end

    def errcode
      require_open_db

      FFI::CApi.sqlite3_errcode(@ctx.db)
    end

    def complete?(sql)
      FFI::CApi.sqlite3_complete(FFI.string_value(sql)) != 0
    end

    def changes
      require_open_db

      FFI::CApi.sqlite3_changes(@ctx.db)
    end

    def authorizer=(authorizer)
      require_open_db

      status = FFI::CApi.sqlite3_set_authorizer(@ctx.db, authorizer.nil? ? nil : FFI::AUTH, FFI.wrap(@ctx))
      FFI.check(@ctx.db, status)
      @ctx.authorizer = authorizer
    end

    def busy_timeout=(timeout)
      require_open_db

      FFI.check(@ctx.db, FFI::CApi.sqlite3_busy_timeout(@ctx.db, timeout))
    end

    def extended_result_codes=(enable)
      require_open_db

      FFI::CApi.sqlite3_extended_result_codes(@ctx.db, enable ? 1 : 0)
      self
    end

    def collation(name, comparator)
      require_open_db

      name = FFI.string_value(name)
      key = name.dup
      key.each_byte.with_index do |v, i|
        if v >= 65 && v <= 90 # 'A' and 'Z'
          key.setbyte(i, v + 32) # 'a' - 'A'
        end
      end

      @_collations ||= {}
      registry = @_collations

      status = FFI::CApi.sqlite3_create_collation(@ctx.db, name, FFI::CApi::SQLITE_UTF8, FFI.wrap(comparator), comparator.nil? ? nil : FFI::COMPARATOR)
      FFI.check(@ctx.db, status)

      registry[key] = comparator
      comparators = []
      comparators += registry.values
      @ctx.collations = comparators

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
        FFI.check(@ctx.db, FFI::CApi.sqlite3_enable_load_extension(@ctx.db, onoffparam))
        self
      end
    end

    def transaction_active?
      require_open_db

      FFI::CApi.sqlite3_get_autocommit(@ctx.db).zero?
    end

    def exec_batch(sql, results_as_hash)
      require_open_db

      sql_cstr = FFI.string_value(sql)
      @ctx.stmt_deadline = nil

      callback_ary = []
      err_msg = ::FFI::MemoryPointer.new(:pointer)
      callback = results_as_hash == true ? FFI::HASH_CALLBACK : FFI::REGULAR_CALLBACK
      frame = FFI::CallbackFrame.new
      FFI.push_callback_frame(frame)
      status = FFI::CApi.sqlite3_exec(@ctx.db, sql_cstr, callback, FFI.wrap(callback_ary), err_msg)
      if (state = FFI.pop_callback_frame(frame))
        FFI::CApi.sqlite3_free(err_msg.read_pointer)
        raise state
      end
      FFI.check_msg(@ctx.db, status, err_msg)
      callback_ary
    end

    def db_filename(db_name)
      require_open_db

      fname = FFI::CApi.sqlite3_db_filename(@ctx.db, db_name)
      fname.null? ? nil : fname.read_string.force_encoding(Encoding::UTF_8)
    end

    if FFI::CApi::HAVE_SQLITE3_SERIALIZE
      def serialize(db_name = nil)
        require_open_db

        z_schema = db_name.nil? ? nil : FFI.string_value_cstr(db_name)

        size = ::FFI::MemoryPointer.new(:int64)
        data = FFI::CApi.sqlite3_serialize(@ctx.db, z_schema, size, 0)
        size = size.read_int64

        if data.null? && size < 0
          raise SQLite3::Exception, "unable to serialize database \"%s\"" % [z_schema || "main"]
        end
        if data.null? && size > 0
          raise NoMemoryError, "failed to allocate %d bytes for serialization" % [size]
        end

        result = data.read_bytes(size)
        FFI::CApi.sqlite3_free(data)
        result
      end
    end

    if FFI::CApi::HAVE_SQLITE3_DESERIALIZE && FFI::CApi.sqlite3_libversion_number >= 3054000
      def deserialize(data, db_name = nil)
        require_open_db

        data = FFI.string_value(data)
        z_schema = db_name.nil? ? nil : FFI.string_value_cstr(db_name)
        sz_db = data.bytesize

        sz_buf = sz_db + 20
        p_data = FFI::CApi.sqlite3_malloc64(sz_buf)
        if p_data.null?
          raise NoMemoryError, "failed to allocate %d bytes for deserialization" % [sz_buf]
        end
        p_data.put_bytes(0, data)
        p_data.put_bytes(sz_db, "\x00"*(sz_buf - sz_db))

        status = FFI::CApi.sqlite3_deserialize(@ctx.db, z_schema, p_data, sz_db, sz_db, FFI::CApi::SQLITE_DESERIALIZE_FREEONCLOSE | FFI::CApi::SQLITE_DESERIALIZE_RESIZEABLE)

        FFI.check(@ctx.db, status)
        self
      end
    end

    private

    def require_open_db
      if @ctx&.db.nil?
        raise SQLite3::Exception, "cannot use a closed database"
      end
    end

    def require_closed_db
      if !@ctx&.db.nil?
        raise SQLite3::Exception, "cannot open a database that is already open"
      end
    end

    def discard_db
      sfile = ::FFI::MemoryPointer.new(:pointer)

      FFI::CApi.sqlite3_db_release_memory(@ctx.db)

      if FFI::CApi::HAVE_SQLITE3_DB_NAME
        j_db = 0
        while !(db_name = FFI::CApi.sqlite3_db_name(@ctx.db, j_db)).null?
          status = FFI::CApi.sqlite3_file_control(@ctx.db, db_name, FFI::CApi::SQLITE_FCNTL_FILE_POINTER, sfile)
          if status == 0
            # TODO
          end
          j_db += 1
        end
      else
        status = FFI::CApi.sqlite3_file_control(@ctx.db, nil, FFI::CApi::SQLITE_FCNTL_FILE_POINTER, sfile)
        if status == 0
          # TODO
        end
      end

      status = FFI::CApi.sqlite3_file_control(@ctx.db, nil, FFI::CApi::SQLITE_FCNTL_JOURNAL_POINTER, sfile)
      if status == 0
        # TODO
      end

      @ctx.db = nil
      @ctx.discarded = true
    end

    def close_or_discard_db
      unless @ctx&.db.nil?
        if @ctx.readonly || @ctx.owner == Process.pid
          @ctx.db.free
          @ctx.db = nil
        else
          discard_db
        end
      end
    end

    def utf16_string_value_ptr(str)
      str = FFI.string_value(str)

      utf16str = str.dup
      if utf16str.encoding != Encoding::UTF_16LE && utf16str.encoding != Encoding::UTF_16BE
        utf16str.force_encoding(Encoding::UTF_16LE)
      end
      codepoints = utf16str.codepoints
      if codepoints.include?(0)
        raise ArgumentError, "string contains null char"
      end

      str = str.dup
      str << 0
      str << 0
      str
    end

    def open_v2(file, flags, zvfs)
      require_closed_db
      @ctx = FFI::Context.new
      @ctx.owner = Process.pid
      db = ::FFI::MemoryPointer.new(:pointer)
      status = FFI::CApi.sqlite3_open_v2(FFI.string_value_cstr(file), db, flags, zvfs.nil? ? nil : FFI.string_value_cstr(zvfs))
      @ctx.db = ::FFI::AutoPointer.new(db.read_pointer, FFI::CApi.method(:sqlite3_close_v2))
      FFI.check(@ctx.db, status)
      if (flags & FFI::CApi::SQLITE_OPEN_READONLY) != 0
        @ctx.readonly = true
      end
      self
    end

    def disable_quirk_mode
      return false if @ctx&.db.nil?

      FFI::CApi.sqlite3_db_config(@ctx.db, FFI::CApi::SQLITE_DBCONFIG_DQS_DDL, :int, 0, :pointer, nil)
      FFI::CApi.sqlite3_db_config(@ctx.db, FFI::CApi::SQLITE_DBCONFIG_DQS_DML, :int, 0, :pointer, nil)
      true
    end

    def discard
      discard_db
      self
    end

    if FFI::CApi::HAVE_SQLITE3_LOAD_EXTENSION
      def load_extension_internal(file)
        require_open_db

        err_msg = ::FFI::MemoryPointer.new(:pointer)
        status = FFI::CApi.sqlite3_load_extension(@ctx.db, FFI.string_value(file), nil, err_msg)
        FFI.check_msg(@ctx.db, status, err_msg)
        self
      end
    end

    def open16(file)
      require_closed_db
      @ctx = FFI::Context.new
      @ctx.owner = Process.pid
      db = ::FFI::MemoryPointer.new(:pointer)
      status = FFI::CApi.sqlite3_open16(utf16_string_value_ptr(file), db)
      @ctx.db = ::FFI::AutoPointer.new(db.read_pointer, FFI::CApi.method(:sqlite3_close_v2))
      if status != FFI::CApi::SQLITE_OK
        # https://github.com/ffi/ffi/issues/1121
        # msg = FFI::CApi.sqlite3_mprintf("%s", :string, FFI::CApi.sqlite3_errmsg(@ctx.db))
        # msg = ::FFI::MemoryPointer.new(:pointer).write_pointer(msg)
        msg = FFI::CApi.sqlite3_errmsg(@ctx.db)
        @ctx.db.free
        @ctx.db = nil
        FFI.check_msg(@ctx.db, status, msg)
      end
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

      @_aggregators ||= []
      aggregators = @_aggregators

      aw = FFI::AggregatorWrapper.new
      aw.handler_klass = aggregator
      aw.instances = []

      status = FFI::CApi.sqlite3_create_function(@ctx.db, FFI.string_value(ruby_name), arity, FFI::CApi::SQLITE_UTF8, FFI.wrap(aw), nil, FFI::AGGREGATOR_STEP, FFI::AGGREGATOR_FINAL)
      FFI.check(@ctx.db, status)

      aggregators << aw
      @ctx.aggregators = aggregators

      self
    end
  end
end
