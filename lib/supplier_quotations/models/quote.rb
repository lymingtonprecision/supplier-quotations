require_relative "./base"
require_relative "./currency"
require_relative "./quote_sql"
require_relative "./quote_line"

module SupplierQuotations; module Models
  class Quote
    def self.all_received_for rfq, revision=:from_rfq
      quotes = []
      fetch(nil, rfq, revision) {|q| quotes << (block_given? ? yield(q) : q)}
      return quotes
    end

    def self.fetch supplier, rfq, revision=:from_rfq
      supplier = supplier.respond_to?(:fetch) ?
        supplier.fetch('supplier_id') :
        supplier

      revision = revision == :from_rfq ? rfq.fetch('revision') : revision
      rfq_no = rfq.respond_to?(:fetch) ? rfq.fetch('rfq_no') : rfq

      quote = :not_found

      M.database do |db|
        c = (M.cursors[:fetch_quote] ||= db.parse(<<-SQL
          select
            qo.inquiry_no "rfq_no",
            qo.revision_no "revision",
            qo.vendor_no "supplier_id",
            ifsapp.supplier_info_api.get_name(qo.vendor_no) "supplier_name",
            qo.currency_code "currency",
            qo.date_received "quote_received",
            qo.last_activity_date "quote_updated"
          from ifsapp.quotation_order qo
          where qo.inquiry_no = :rfq_no
            and qo.revision_no = :revision
            and (:supplier_id is null or qo.vendor_no = :supplier_id)
          SQL
        ))

        c.define 1, Fixnum
        c.define 2, Fixnum
        c.define 6, Date
        c.define 7, Date

        c.bind_param ':rfq_no', rfq_no, Fixnum
        c.bind_param ':revision', revision, Fixnum
        c.bind_param ':supplier_id', supplier, String, 20
        c.exec

        c.fetch_hash {|r| quote = block_given? ? yield(r) : r}
      end

      raise NotFound if quote == :not_found

      return quote
    end

    def self.received? quote
      quote.has_key?('quote_received') && quote.fetch('quote_received')
    end

    def self.can_be_revised? quote
      return false unless quote.has_key? 'lines'
      quote.fetch('lines').any? {|l| Line.can_be_revised? l}
    end

    def self.decline quote
      return quote unless quote.has_key? 'lines'
      update quote, 'lines', quote.fetch('lines').each {|l| Line.decline l}
    end

    def self.line quote, line_number
      line = quote.fetch('lines').find {|l| l.fetch('line_no') == line_number}
      raise NotFound if line.nil?
      return line
    end

    def self.collection_populated? quote, collection
      [quote, quote.fetch('lines', [])].flatten.any? {|item|
        item.has_key?(collection) && item.fetch(collection).size > 0
      }
    end

    def self.has_errors? quote
      collection_populated? quote, 'errors'
    end

    def self.changed? quote
      collection_populated? quote, 'changes'
    end

    def self.update_from_web quote, post_params
      new_quote = quote

      if post_params.has_key? 'currency'
        new_currency = post_params.fetch 'currency'
        new_quote = update new_quote, 'currency', new_currency

        unless Currency.exists? new_currency
          add_error new_quote,
            'currency',
            "#{new_currency} is not a valid currency"
        end
      end

      if post_params.has_key? 'lines'
        lines = quote.fetch 'lines', Line.all_on(quote)
        new_lines = Line.update_set_from_web lines, post_params.fetch('lines')
        new_quote = update new_quote, 'lines', new_lines
      end

      return new_quote
    end

    def self.add_error quote, attribute, error
      errors = quote.fetch 'errors', {}
      quote.merge 'errors' => errors.merge(attribute => error)
    end

    def self.update quote, attribute, new_value
      old_value = quote.fetch(attribute, nil)

      return quote if old_value == new_value

      changes = quote.fetch('changes', {}).merge attribute => {
        'old' => old_value,
        'new' => new_value
      }

      quote.merge attribute => new_value, 'changes' => changes
    end

    def self.save quote, database=:new
      return quote if has_errors?(quote) || !changed?(quote)

      update = lambda do |db|
        quote.fetch('lines', []).each do |line|
          Line.save line, db
        end

        c = (M.cursors[:update_quote] ||= db.parse(update_sql))

        c.bind_param ':rfq_no', quote.fetch('rfq_no'), Fixnum
        c.bind_param ':revision', quote.fetch('revision'), Fixnum
        c.bind_param ':supplier', quote.fetch('supplier_id'), String, 20
        c.bind_param ':currency', quote.fetch('currency'), String, 3
        c.exec
      end

      if database == :new
        M.database {|db|
          update.call(db)
          db.commit
        }
      else
        update.call(database)
      end

      return quote.reject {|k,_| k == 'changes'}
    end

    def self.ifs_url quote
      IFS.apps_url 'frmPriceInquiryAnswer', [
        quote.fetch('rfq_no'),
        quote.fetch('revision'),
        quote.fetch('supplier_id')
      ]
    end
  end
end; end

