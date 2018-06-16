require_relative "./base"
require_relative "./document_text"
require_relative "./rfq_line_sql"
require_relative "./behaviours/diff"

module SupplierQuotations; module Models; class Rfq;
  class Line
    def self.fetch_cursor db, rfq, line
      c = (M.cursors[:fetch_rfq_line] ||= db.parse(fetch_sql))

      c.define 1, Fixnum
      c.define 2, Fixnum
      c.define 3, Fixnum
      c.define 6, Float
      c.define 8, Date

      c.bind_param ':rfq_no', rfq.fetch('rfq_no'), Fixnum
      c.bind_param ':revision', rfq.fetch('revision'), Fixnum
      c.bind_param ':line_no', line, Fixnum

      return c
    end

    def self.all_on rfq
      lines = {}
      fetch(rfq, nil) {|l|
        lines[l.fetch('line_no')] = (block_given? ? yield(l) : l)
      }
      return lines
    end

    def self.fetch rfq, number
      line = :not_found

      M.database do |db|
        c = fetch_cursor db, rfq, number
        c.exec
        c.fetch_hash {|r|
          text = r.inject([]) {|t,kv|
            t << DocumentText.for(kv[1]) if kv[0] =~ /note_id$/
            t
          }.flatten

          r = r.merge 'text' => text
          line = block_given? ? yield(r) : r
        }
      end

      raise NotFound if line == :not_found
      return line
    end

    def self.closed? line
      line.fetch('status') == 'Closed'
    end

    def self.cancelled? line
      line.fetch('status') == 'Cancelled'
    end

    def self.open? line
      !(closed?(line) || cancelled?(line))
    end

    class << self
      alias_method :response_allowed?, :open?
    end

    def self.diff *args, &block
      Diff.call *args, &block
    end

    def self.ifs_approval_url line
      IFS.apps_url 'frmOrderQuotApprov', [
        line.fetch('rfq_no'),
        line.fetch('line_no'),
        line.fetch('revision')
      ]
    end
  end
end; end; end

