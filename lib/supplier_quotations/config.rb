require "yaml"

module SupplierQuotations
  module Config
    class Settings
      def initialize initial_values={}
        @settings = initial_values
      end

      def set key, value
        @settings[key] = value
      end

      def method_missing m, *args, &block
        super if args.size > 0
        value = @settings[m.to_s.downcase] || @settings[m.to_sym]

        if value.nil?
          self.class.new
        elsif value.kind_of? Hash
          self.class.new value
        else
          value
        end
      end

      def nil?
        @settings.empty?
      end

      def eql? other
        if other.nil?
          nil?
        else
          super
        end
      end

      def == other
        eql? other
      end

      def to_s
        nil? ? "" : super
      end
    end

    class << self
      def env
        (@env || ENV["RACK_ENV"] || "development").to_s.downcase
      end

      def env= name
        @env = name
      end

      def settings
        @settings ||= Settings.new
      end

      def load path
        config = YAML.load_file path
        @settings = Settings.new(config[env] || config)
      end

      def connect
        require_relative "./database"
        SupplierQuotations::Models.connect_to \
          settings.instance,
          settings.username,
          settings.password
      end
    end
  end
end

