module SQLite3
  module FFI
    module CoreExt
      # must override for Active Record
      def gem(name, ...)
        # TODO check version
        return if name == "sqlite3"
        super
      end
    end

    Kernel.prepend CoreExt
  end
end
