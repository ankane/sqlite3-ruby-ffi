module SQLite3
  class Blob < String
  end

  module Constants
    module Open
      READONLY       = FFI::CApi::SQLITE_OPEN_READONLY
      READWRITE      = FFI::CApi::SQLITE_OPEN_READWRITE
      CREATE         = FFI::CApi::SQLITE_OPEN_CREATE
      DELETEONCLOSE  = FFI::CApi::SQLITE_OPEN_DELETEONCLOSE
      EXCLUSIVE      = FFI::CApi::SQLITE_OPEN_EXCLUSIVE
      MAIN_DB        = FFI::CApi::SQLITE_OPEN_MAIN_DB
      TEMP_DB        = FFI::CApi::SQLITE_OPEN_TEMP_DB
      TRANSIENT_DB   = FFI::CApi::SQLITE_OPEN_TRANSIENT_DB
      MAIN_JOURNAL   = FFI::CApi::SQLITE_OPEN_MAIN_JOURNAL
      TEMP_JOURNAL   = FFI::CApi::SQLITE_OPEN_TEMP_JOURNAL
      SUBJOURNAL     = FFI::CApi::SQLITE_OPEN_SUBJOURNAL
      MASTER_JOURNAL = FFI::CApi::SQLITE_OPEN_SUPER_JOURNAL
      SUPER_JOURNAL  = FFI::CApi::SQLITE_OPEN_SUPER_JOURNAL
      NOMUTEX        = FFI::CApi::SQLITE_OPEN_NOMUTEX
      FULLMUTEX      = FFI::CApi::SQLITE_OPEN_FULLMUTEX
      AUTOPROXY      = FFI::CApi::SQLITE_OPEN_AUTOPROXY
      SHAREDCACHE    = FFI::CApi::SQLITE_OPEN_SHAREDCACHE
      PRIVATECACHE   = FFI::CApi::SQLITE_OPEN_PRIVATECACHE
      WAL            = FFI::CApi::SQLITE_OPEN_WAL
      URI            = FFI::CApi::SQLITE_OPEN_URI
      MEMORY         = FFI::CApi::SQLITE_OPEN_MEMORY
    end
  end

  def self.threadsafe
    FFI::CApi.sqlite3_threadsafe
  end

  def self.sqlcipher?
    false
  end

  def self.libversion
    FFI::CApi.sqlite3_libversion
  end

  def self.status(parameter, reset_flag = false)
    op = parameter.to_i
    reset = reset_flag ? 1 : 0

    p_current = ::FFI::MemoryPointer.new(:int64)
    p_highwater = ::FFI::MemoryPointer.new(:int64)
    FFI::CApi.sqlite3_status64(op, p_current, p_highwater, reset)

    {
      current: p_current.read_int64,
      highwater: p_highwater.read_int64
    }
  end

  SQLITE_VERSION = FFI::CApi.sqlite3_libversion
  SQLITE_VERSION_NUMBER = FFI::CApi.sqlite3_libversion_number
  SQLITE_LOADED_VERSION = FFI::CApi.sqlite3_libversion
  SQLITE_PACKAGED_LIBRARIES = false
  SQLITE_PRECOMPILED_LIBRARIES = false
end
