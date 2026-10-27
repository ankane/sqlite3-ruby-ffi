module SQLite3
  module FFI
    def self.check(db, status)
      raise_(db, status)
    end

    def self.check_msg(db, status, msg)
      raise_msg(db, status, msg)
    end

    def self.check_prepare(db, status, sql)
      raise_with_sql(db, status, sql)
    end

    def self.status2klass(status)
      case status & 0xff
      when 0
        nil
      when CApi::SQLITE_ERROR
        SQLite3::SQLException
      when CApi::SQLITE_INTERNAL
        SQLite3::InternalException
      when CApi::SQLITE_PERM
        SQLite3::PermissionException
      when CApi::SQLITE_ABORT
        SQLite3::AbortException
      when CApi::SQLITE_BUSY
        SQLite3::BusyException
      when CApi::SQLITE_LOCKED
        SQLite3::LockedException
      when CApi::SQLITE_NOMEM
        SQLite3::MemoryException
      when CApi::SQLITE_READONLY
        SQLite3::ReadOnlyException
      when CApi::SQLITE_INTERRUPT
        SQLite3::InterruptException
      when CApi::SQLITE_IOERR
        SQLite3::IOException
      when CApi::SQLITE_CORRUPT
        SQLite3::CorruptException
      when CApi::SQLITE_NOTFOUND
        SQLite3::NotFoundException
      when CApi::SQLITE_FULL
        SQLite3::FullException
      when CApi::SQLITE_CANTOPEN
        SQLite3::CantOpenException
      when CApi::SQLITE_PROTOCOL
        SQLite3::ProtocolException
      when CApi::SQLITE_EMPTY
        SQLite3::EmptyException
      when CApi::SQLITE_SCHEMA
        SQLite3::SchemaChangedException
      when CApi::SQLITE_TOOBIG
        SQLite3::TooBigException
      when CApi::SQLITE_CONSTRAINT
        SQLite3::ConstraintException
      when CApi::SQLITE_MISMATCH
        SQLite3::MismatchException
      when CApi::SQLITE_MISUSE
        SQLite3::MisuseException
      when CApi::SQLITE_NOLFS
        SQLite3::UnsupportedException
      when CApi::SQLITE_AUTH
        SQLite3::AuthorizationException
      when CApi::SQLITE_FORMAT
        SQLite3::FormatException
      when CApi::SQLITE_RANGE
        SQLite3::RangeException
      when CApi::SQLITE_NOTADB
        SQLite3::NotADatabaseException
      else
        SQLite3::Exception
      end
    end

    def self.raise_(db, status)
      klass = status2klass(status)
      return if klass.nil?

      exception = klass.new(CApi.sqlite3_errmsg(db))
      exception.instance_variable_set(:@code, status)

      raise exception
    end

    def self.raise_msg(db, status, msg)
      klass = status2klass(status)
      return if klass.nil?

      exception = klass.new(msg.is_a?(String) ? msg : msg.read_pointer.read_string)
      exception.instance_variable_set(:@code, status)
      CApi.sqlite3_free(msg.read_pointer) unless msg.is_a?(String)

      raise exception
    end

    def self.raise_with_sql(db, status, sql)
      klass = status2klass(status)
      return if klass.nil?

      exception = klass.new(CApi.sqlite3_errmsg(db))
      exception.instance_variable_set(:@code, status)
      if sql
        exception.instance_variable_set(:@sql, sql)
        exception.instance_variable_set(:@sql_offset, CApi.sqlite3_error_offset(db))
      end

      raise exception
    end

    CallbackFrame = Struct.new(:state, :prev, :holder)

    CallbackFrames = Struct.new(:top)

    def self.current_callback_frames_holder
      holder = Thread.current[:__sqlite3_callback_frames__]
      holder.is_a?(CallbackFrames) ? holder : nil
    end

    def self.current_callback_frames
      holder = current_callback_frames_holder
      holder.nil? ? nil : holder
    end

    def self.push_callback_frame(frame)
      holder = current_callback_frames_holder

      if holder.nil?
        holder = CallbackFrames.new
        Thread.current[:__sqlite3_callback_frames__] = holder
      end
      frames = holder

      frame.state = nil
      frame.prev = frames.top
      frame.holder = holder
      frames.top = frame
    end

    def self.pop_callback_frame(frame)
      frame.holder.top = frame.prev
      frame.state
    end

    def self.protect_callback
      frames = current_callback_frames
      frame = frames ? frames.top : nil
      result = nil
      state = nil

      if frame && frame.state
        failed = true
        return [nil, failed]
      end

      begin
        result = yield
      rescue => e
        state = e
      end
      failed = !state.nil?

      if frame
        frame.state = state
      elsif state
        self.rb_errinfo = nil
      end

      [result, failed]
    end
  end
end
