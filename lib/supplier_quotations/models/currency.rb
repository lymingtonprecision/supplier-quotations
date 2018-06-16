require_relative "./base"

module SupplierQuotations; module Models
  class Currency
    def self.all
      currencies = []

      M.database do |db|
        c = (M.cursors[:fetch_currencies] ||= db.parse(<<-SQL
          select
            currency_code
          from ifsapp.currency_code_tab
          where company = 'LPE'
          order by
            decode(
              currency_code,
              'GBP', 1,
              'EUR', 2,
              'USD', 3,
              '4'
            ),
            currency_code
          SQL
        ))

        c.exec

        while r = c.fetch
          currencies << r[0]
        end
      end

      return currencies
    end

    def self.exists? currency
      all.any? {|c| c == currency}
    end
  end
end; end

