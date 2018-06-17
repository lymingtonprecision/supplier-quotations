require_relative "./base"
require_relative "./quote"
require_relative "./quote_line_sql"

module SupplierQuotations; module Models; class Quote;
  class Line
    extend Validator

    validates('price_each', 'must be a number') {|v| (v || 0).kind_of? Numeric}
    validates('promised_date', 'must be a date') {|v| v.nil? || v.kind_of?(Date)}

    extend WebInputConvertor

    converts_from_web_number 'price_each'
    converts_from_web_date 'promised_date'
    converts_from_web 'notes', lambda {|n| n}

    def self.all_on quote
      lines = []
      fetch(quote, nil) {|l| lines << (block_given? ? yield(l) : l)}
      return lines
    end

    def self.fetch quote, line_number
      line = :not_found

      M.database do |db|
        c = (M.cursors[:fetch_quote_line] ||= db.parse(fetch_sql))

        c.define 1, Fixnum
        c.define 2, Fixnum
        c.define 3, Fixnum
        c.define 5, Float
        c.define 6, Date

        c.bind_param ':rfq_no', quote.fetch('rfq_no'), Fixnum
        c.bind_param ':revision', quote.fetch('revision'), Fixnum
        c.bind_param ':supplier', quote.fetch('supplier_id'), String, 20
        c.bind_param ':line_no', line_number, Fixnum
        c.exec

        c.fetch_hash {|r| line = block_given? ? yield(r) : r}
      end

      raise NotFound if line == :not_found
      return line
    end

    def self.can_be_revised? line
      !(rejected?(line) || approved?(line) || cancelled?(line))
    end

    def self.decline line
      update line, 'status', 'Declined'
    end

    def self.undecline line
      return line unless declined? line
      update line, 'status', 'Created'
    end

    def self.status_is? line, *statuses
      status = line.fetch('status')
      statuses.flatten.any? {|s| s == status}
    end

    def self.declined? line
      status_is? line, 'Declined'
    end

    def self.rejected? line
      status_is? line, 'Rejected'
    end

    def self.approved? line
      status_is? line, 'Approved', 'Converted'
    end

    def self.cancelled? line
      status_is? line, 'Cancelled'
    end

    def self.update_set_from_web lines, post_params
      lines.collect {|l|
        updates = post_params.fetch(l.fetch('line_no').to_s, :no_updates)
        updates == :no_updates ? l : update_from_web(l, updates)
      }
    end

    def self.update_from_web line, post_params
      new_line = line

      web_decline = post_params.fetch('declined', :off) == 'on'
      new_line = decline new_line if web_decline && !declined?(new_line)
      new_line = undecline new_line if !web_decline && declined?(new_line)

      %w{price_each promised_date notes}.each do |f|
        if post_params.has_key? f
          new_value = convert_from_web f, post_params.fetch(f)
          new_line = update new_line, f, new_value
        end
      end

      return validate(new_line)
    end

    def self.save line, database=:new
      return line if has_errors?(line) || !changed?(line)

      update = lambda do |db|
        c = (M.cursors[:update_quote_line] ||= db.parse(update_sql))

        c.bind_param ':rfq_no', line.fetch('rfq_no'), Fixnum
        c.bind_param ':revision', line.fetch('revision'), Fixnum
        c.bind_param ':line_no', line.fetch('line_no'), Fixnum
        c.bind_param ':supplier', line.fetch('supplier_id'), String, 20

        note_text = line.fetch('notes', '')

        if declined? line
          note_text = "Declined\n\n" + note_text if declined? line
          c.bind_param ':price_each', nil, Float
          c.bind_param ':promised_date', nil, Date
          c.bind_param ':declined', 1, Fixnum
        else
          c.bind_param ':price_each', line.fetch('price_each'), Float
          c.bind_param ':promised_date', line.fetch('promised_date'), Date
          c.bind_param ':declined', 0, Fixnum
        end

        c.bind_param ':notes', note_text, String, 2000

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

      return line.reject {|k,_| k == 'changes'}
    end

    #
    # Functions delegated to Quote class
    #
    def self.collection_populated? line, collection
      Quote.collection_populated? line, collection
    end

    def self.has_errors? line
      collection_populated? line, 'errors'
    end

    def self.changed? line
      collection_populated? line, 'changes'
    end

    def self.add_error line, attribute, error
      Quote.add_error line, attribute, error
    end

    def self.update line, attribute, new_value
      Quote.update line, attribute, new_value
    end
  end
end; end; end

