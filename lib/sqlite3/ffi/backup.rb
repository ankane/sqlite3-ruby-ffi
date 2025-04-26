module SQLite3
  class Backup
    def initialize(dstdb, dstname, srcdb, srcname)
      if srcdb.closed?
        raise ArgumentError, "cannot backup from a closed database"
      end
      if dstdb.closed?
        raise ArgumentError, "cannot backup to a closed database"
      end

      ddb = dstdb.instance_variable_get(:@db)
      @p =
        FFI::CApi.sqlite3_backup_init(
          ddb,
          FFI.string_value(dstname),
          srcdb.instance_variable_get(:@db),
          FFI.string_value(srcname)
        )

      if @p.null?
        FFI.check(ddb, FFI::CApi.sqlite3_errcode(ddb))
      end
    end

    def step(n_page)
      require_open_backup

      FFI::CApi.sqlite3_backup_step(@p, n_page)
    end

    def finish
      require_open_backup

      FFI::CApi.sqlite3_backup_finish(@p)
      @p = nil
      nil
    end

    def remaining
      require_open_backup

      FFI::CApi.sqlite3_backup_remaining(@p)
    end

    def pagecount
      require_open_backup

      FFI::CApi.sqlite3_backup_pagecount(@p)
    end

    private

    def require_open_backup
      if @p.nil? || @p.null?
        raise SQLite3::Exception, "cannot use a closed backup"
      end
    end
  end
end
