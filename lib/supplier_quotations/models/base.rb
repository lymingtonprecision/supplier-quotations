module SupplierQuotations
  module Models
    class NotFound < StandardError
    end

    class IFS
      def self.base_url
        @base_url ||= M.database do |db|
          c = db.parse(<<-SQL
            select
              ifsapp.fnd_setting_api.get_value('URL_EXT_SERVER')
            from dual
            SQL
          )

          c.exec
          c.fetch[0]
        end
      end

      def self.apps_url form, keys
        [
          base_url,
          '/client/runtime/Ifs.Fnd.Explorer.application?',
          'url=ifsapf%3A',
          form,
          '%3Faction%3Dget%26key1%3D',
          keys.join('%255E'),
          '%26COMPANY%3DLPE'
        ].join
      end
    end
  end
end

Dir[File.join(File.dirname(__FILE__), 'behaviours', '*.rb')].each {|f| require f}

