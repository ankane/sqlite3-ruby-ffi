module SQLite3
  module FFI
    module CApi
      extend ::FFI::Library

      # TODO vendor sqlite3
      libs = ["sqlite3"]
      if RbConfig::CONFIG["host_os"] =~ /darwin/i
        if RbConfig::CONFIG["host_cpu"] =~ /arm|aarch64/i
          libs.unshift("/opt/homebrew/opt/sqlite3/lib/libsqlite3.dylib")
        else
          libs.unshift("/usr/local/opt/sqlite3/lib/libsqlite3.dylib")
        end
      end
      ffi_lib libs

      SQLITE_OK         =  0
      SQLITE_ERROR      =  1
      SQLITE_INTERNAL   =  2
      SQLITE_PERM       =  3
      SQLITE_ABORT      =  4
      SQLITE_BUSY       =  5
      SQLITE_LOCKED     =  6
      SQLITE_NOMEM      =  7
      SQLITE_READONLY   =  8
      SQLITE_INTERRUPT  =  9
      SQLITE_IOERR      = 10
      SQLITE_CORRUPT    = 11
      SQLITE_NOTFOUND   = 12
      SQLITE_FULL       = 13
      SQLITE_CANTOPEN   = 14
      SQLITE_PROTOCOL   = 15
      SQLITE_EMPTY      = 16
      SQLITE_SCHEMA     = 17
      SQLITE_TOOBIG     = 18
      SQLITE_CONSTRAINT = 19
      SQLITE_MISMATCH   = 20
      SQLITE_MISUSE     = 21
      SQLITE_NOLFS      = 22
      SQLITE_AUTH       = 23
      SQLITE_FORMAT     = 24
      SQLITE_RANGE      = 25
      SQLITE_NOTADB     = 26
      SQLITE_NOTICE     = 27
      SQLITE_WARNING    = 28
      SQLITE_ROW        = 100
      SQLITE_DONE       = 101

      SQLITE_INTEGER = 1
      SQLITE_FLOAT   = 2
      SQLITE_TEXT    = 3
      SQLITE_BLOB    = 4
      SQLITE_NULL    = 5

      SQLITE_UTF8          = 1
      SQLITE_UTF16LE       = 2
      SQLITE_UTF16BE       = 3
      SQLITE_UTF16         = 4
      SQLITE_ANY           = 5
      SQLITE_UTF16_ALIGNED = 8

      SQLITE_DENY   = 1
      SQLITE_IGNORE = 2

      SQLITE_STATIC    = ::FFI::Pointer.new(0)
      SQLITE_TRANSIENT = ::FFI::Pointer.new(-1)

      SQLITE_DBCONFIG_MAINDBNAME            = 1000
      SQLITE_DBCONFIG_LOOKASIDE             = 1001
      SQLITE_DBCONFIG_ENABLE_FKEY           = 1002
      SQLITE_DBCONFIG_ENABLE_TRIGGER        = 1003
      SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER = 1004
      SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION = 1005
      SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE      = 1006
      SQLITE_DBCONFIG_ENABLE_QPSG           = 1007
      SQLITE_DBCONFIG_TRIGGER_EQP           = 1008
      SQLITE_DBCONFIG_RESET_DATABASE        = 1009
      SQLITE_DBCONFIG_DEFENSIVE             = 1010
      SQLITE_DBCONFIG_WRITABLE_SCHEMA       = 1011
      SQLITE_DBCONFIG_LEGACY_ALTER_TABLE    = 1012
      SQLITE_DBCONFIG_DQS_DML               = 1013
      SQLITE_DBCONFIG_DQS_DDL               = 1014
      SQLITE_DBCONFIG_ENABLE_VIEW           = 1015
      SQLITE_DBCONFIG_LEGACY_FILE_FORMAT    = 1016
      SQLITE_DBCONFIG_TRUSTED_SCHEMA        = 1017
      SQLITE_DBCONFIG_STMT_SCANSTATUS       = 1018
      SQLITE_DBCONFIG_REVERSE_SCANORDER     = 1019
      SQLITE_DBCONFIG_ENABLE_ATTACH_CREATE  = 1020
      SQLITE_DBCONFIG_ENABLE_ATTACH_WRITE   = 1021
      SQLITE_DBCONFIG_ENABLE_COMMENTS       = 1022
      SQLITE_DBCONFIG_MAX                   = 1022

      SQLITE_OPEN_READONLY       = 0x00000001
      SQLITE_OPEN_READWRITE      = 0x00000002
      SQLITE_OPEN_CREATE         = 0x00000004
      SQLITE_OPEN_DELETEONCLOSE  = 0x00000008
      SQLITE_OPEN_EXCLUSIVE      = 0x00000010
      SQLITE_OPEN_AUTOPROXY      = 0x00000020
      SQLITE_OPEN_URI            = 0x00000040
      SQLITE_OPEN_MEMORY         = 0x00000080
      SQLITE_OPEN_MAIN_DB        = 0x00000100
      SQLITE_OPEN_TEMP_DB        = 0x00000200
      SQLITE_OPEN_TRANSIENT_DB   = 0x00000400
      SQLITE_OPEN_MAIN_JOURNAL   = 0x00000800
      SQLITE_OPEN_TEMP_JOURNAL   = 0x00001000
      SQLITE_OPEN_SUBJOURNAL     = 0x00002000
      SQLITE_OPEN_SUPER_JOURNAL  = 0x00004000
      SQLITE_OPEN_NOMUTEX        = 0x00008000
      SQLITE_OPEN_FULLMUTEX      = 0x00010000
      SQLITE_OPEN_SHAREDCACHE    = 0x00020000
      SQLITE_OPEN_PRIVATECACHE   = 0x00040000
      SQLITE_OPEN_WAL            = 0x00080000
      SQLITE_OPEN_NOFOLLOW       = 0x01000000
      SQLITE_OPEN_EXRESCODE      = 0x02000000
      SQLITE_OPEN_MASTER_JOURNAL = 0x00004000

      SQLITE_STMTSTATUS_FULLSCAN_STEP = 1
      SQLITE_STMTSTATUS_SORT          = 2
      SQLITE_STMTSTATUS_AUTOINDEX     = 3
      SQLITE_STMTSTATUS_VM_STEP       = 4
      SQLITE_STMTSTATUS_REPREPARE     = 5
      SQLITE_STMTSTATUS_RUN           = 6
      SQLITE_STMTSTATUS_FILTER_MISS   = 7
      SQLITE_STMTSTATUS_FILTER_HIT    = 8
      SQLITE_STMTSTATUS_MEMUSED       = 99

      SQLITE_TRACE_STMT    = 0x01
      SQLITE_TRACE_PROFILE = 0x02
      SQLITE_TRACE_ROW     = 0x04
      SQLITE_TRACE_CLOSE   = 0x08

      attach_function :sqlite3_aggregate_context, [:pointer, :int], :pointer
      attach_function :sqlite3_backup_finish, [:pointer], :int
      attach_function :sqlite3_backup_init, [:pointer, :string, :pointer, :string], :pointer
      attach_function :sqlite3_backup_pagecount, [:pointer], :int
      attach_function :sqlite3_backup_remaining, [:pointer], :int
      attach_function :sqlite3_backup_step, [:pointer, :int], :int
      attach_function :sqlite3_bind_blob, [:pointer, :int, :pointer, :int, :pointer], :int
      attach_function :sqlite3_bind_double, [:pointer, :int, :double], :int
      attach_function :sqlite3_bind_int64, [:pointer, :int, :int64], :int
      attach_function :sqlite3_bind_null, [:pointer, :int], :int
      attach_function :sqlite3_bind_parameter_count, [:pointer], :int
      attach_function :sqlite3_bind_parameter_index, [:pointer, :string], :int
      attach_function :sqlite3_bind_text, [:pointer, :int, :string, :int, :pointer], :int
      attach_function :sqlite3_bind_text16, [:pointer, :int, :pointer, :int, :pointer], :int
      attach_function :sqlite3_busy_handler, [:pointer, :pointer, :pointer], :int
      attach_function :sqlite3_busy_timeout, [:pointer, :int], :int
      attach_function :sqlite3_changes, [:pointer], :int
      attach_function :sqlite3_clear_bindings, [:pointer], :int
      attach_function :sqlite3_close_v2, [:pointer], :int
      attach_function :sqlite3_column_blob, [:pointer, :int], :pointer
      attach_function :sqlite3_column_bytes, [:pointer, :int], :int
      attach_function :sqlite3_column_count, [:pointer], :int
      attach_function :sqlite3_column_decltype, [:pointer, :int], :string
      attach_function :sqlite3_column_double, [:pointer, :int], :double
      attach_function :sqlite3_column_int64, [:pointer, :int], :int64
      attach_function :sqlite3_column_name, [:pointer, :int], :string
      attach_function :sqlite3_column_text, [:pointer, :int], :pointer
      attach_function :sqlite3_column_type, [:pointer, :int], :int
      attach_function :sqlite3_complete, [:string], :int
      attach_function :sqlite3_create_collation, [:pointer, :string, :int, :pointer, :pointer], :int
      attach_function :sqlite3_create_function, [:pointer, :string, :int, :int, :pointer, :pointer, :pointer, :pointer], :int
      attach_function :sqlite3_db_config, [:pointer, :int, :varargs], :int
      attach_function :sqlite3_db_handle, [:pointer], :pointer
      attach_function :sqlite3_db_filename, [:pointer, :string], :pointer
      attach_function :sqlite3_db_release_memory, [:pointer], :int
      attach_function :sqlite3_errcode, [:pointer], :int
      attach_function :sqlite3_errmsg, [:pointer], :string
      attach_function :sqlite3_error_offset, [:pointer], :int
      attach_function :sqlite3_exec, [:pointer, :string, :pointer, :pointer, :pointer], :int
      attach_function :sqlite3_expanded_sql, [:pointer], :string
      attach_function :sqlite3_extended_result_codes, [:pointer, :int], :int
      attach_function :sqlite3_file_control, [:pointer, :string, :int, :pointer], :int
      attach_function :sqlite3_finalize, [:pointer], :int
      attach_function :sqlite3_free, [:pointer], :void
      attach_function :sqlite3_get_autocommit, [:pointer], :int
      attach_function :sqlite3_interrupt, [:pointer], :void
      attach_function :sqlite3_last_insert_rowid, [:pointer], :int64
      attach_function :sqlite3_libversion, [], :string
      attach_function :sqlite3_libversion_number, [], :int
      attach_function :sqlite3_open16, [:pointer, :pointer], :int
      attach_function :sqlite3_open_v2, [:string, :pointer, :int, :pointer], :int
      attach_function :sqlite3_prepare_v2, [:pointer, :string, :int, :pointer, :pointer], :int
      attach_function :sqlite3_progress_handler, [:pointer, :int, :pointer, :pointer], :void
      attach_function :sqlite3_reset, [:pointer], :int
      attach_function :sqlite3_result_blob, [:pointer, :pointer, :int, :pointer], :void
      attach_function :sqlite3_result_double, [:pointer, :double], :void
      attach_function :sqlite3_result_int64, [:pointer, :int64], :void
      attach_function :sqlite3_result_null, [:pointer], :void
      attach_function :sqlite3_result_text, [:pointer, :string, :int, :pointer], :void
      attach_function :sqlite3_set_authorizer, [:pointer, :pointer, :pointer], :int
      attach_function :sqlite3_sql, [:pointer], :string
      attach_function :sqlite3_status64, [:int, :pointer, :pointer, :int], :int
      attach_function :sqlite3_step, [:pointer], :int
      attach_function :sqlite3_stmt_status, [:pointer, :int, :int], :int
      attach_function :sqlite3_threadsafe, [], :int
      attach_function :sqlite3_total_changes, [:pointer], :int
      attach_function :sqlite3_trace_v2, [:pointer, :uint, :pointer, :pointer], :int
      attach_function :sqlite3_user_data, [:pointer], :pointer
      attach_function :sqlite3_value_blob, [:pointer], :pointer
      attach_function :sqlite3_value_bytes, [:pointer], :int
      attach_function :sqlite3_value_double, [:pointer], :double
      attach_function :sqlite3_value_int64, [:pointer], :int64
      attach_function :sqlite3_value_text, [:pointer], :pointer
      attach_function :sqlite3_value_type, [:pointer], :int

      HAVE_SQLITE3_ENABLE_LOAD_EXTENSION = begin
        attach_function :sqlite3_enable_load_extension, [:pointer, :int], :int
        true
      rescue ::FFI::NotFoundError
        false
      end

      HAVE_SQLITE3_LOAD_EXTENSION = begin
        attach_function :sqlite3_load_extension, [:pointer, :string, :pointer, :pointer], :int
        true
      rescue ::FFI::NotFoundError
        false
      end
    end
  end
end
