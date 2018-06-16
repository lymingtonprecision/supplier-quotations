require "oci8"
require_relative "../rack-oci8-compatability"

module SupplierQuotations
  module Models
    class << self
      def connect_to instance, username, password
        @instance = instance
        @uid = username
        @pwd = password
        @pool = OCI8::ConnectionPool.new 0, 5, 1, @uid, @pwd, @instance

        @conns = {}
        @cursors = {}
      end

      def database &block
        db = @conns[Thread.current]

        if db.nil?
          db = OCI8.new @uid, @pwd, @pool || @instance
          @conns[Thread.current] = db
          existing_conn = false
        else
          existing_conn = true
        end

        begin
          yield db
        rescue
          db.rollback

          # Rack::ShowException seems to dislike OCI error classes
          raise $!.kind_of?(OCIException) ? OciError.new($!) : $!
        ensure
          disconnect unless existing_conn
        end
      end

      def transaction &block
        database {|db|
          t = db.kind_of?(OCI8::Transaction) ? db : OCI8::Transaction.new(db)
          @conns[Thread.current] = t
          yield t
          db.commit if t.commit?
        }
      end

      def cursors
        @cursors[Thread.current] ||= {}
      end

      def cursor name, sql
        cursors[name] ||= database {|db| db.parse(sql)}
      end

      def disconnect
        db = @conns[Thread.current]

        unless db.nil?
          cursors.each {|c| c[1].close if c[1].respond_to?(:close)}
          db.logoff
        end

        @cursors.delete Thread.current
        @conns.delete Thread.current
      end
    end

    M = self
  end
end

