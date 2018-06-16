class OCI8
  class Transaction < BasicObject
    def initialize connection
      @connection = connection
      @commit = false
    end

    def method_missing *args, &block
      @connection.send *args, &block
    end

    def commit
      @commit = true
    end

    def commit?
      @commit
    end
  end
end

class OciError < StandardError
  def initialize error
    super error.to_s
    set_backtrace error.backtrace
  end
end

