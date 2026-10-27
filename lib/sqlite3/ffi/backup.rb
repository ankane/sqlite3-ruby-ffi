module SQLite3
  class Backup
    def initialize(dstdb, dstname, srcdb, srcname)
      if srcdb.closed?
        raise ArgumentError, "cannot backup from a closed database"
      end
      if dstdb.closed?
        raise ArgumentError, "cannot backup to a closed database"
      end

      ddb = dstdb.instance_variable_get(:@ctx).db
      @p =
        FFI::CApi.sqlite3_backup_init(
          ddb,
          FFI.string_value(dstname),
          srcdb.instance_variable_get(:@ctx).db,
          FFI.string_value(srcname)
        )

      if @p.null?
        FFI.check(ddb, FFI::CApi.sqlite3_errcode(ddb))
      end
    end

    def step(n_page)
      require_open_backup
      pages = n_page.to_i

      frame = FFI::CallbackFrame.new
      FFI.push_callback_frame(frame)
      status = FFI::CApi.sqlite3_backup_step(@p, pages)
      if (callback_state = FFI.pop_callback_frame(frame))
        raise callback_state
      end
      status
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
