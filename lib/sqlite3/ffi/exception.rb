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

      exception = klass.new(msg.read_pointer.read_string)
      exception.instance_variable_set(:@code, status)
      CApi.sqlite3_free(msg.read_pointer)

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
  end
end
