require_relative "./base"
require_relative "./document_text"
require_relative "./rfq_sql"
require_relative "./behaviours/diff"

module SupplierQuotations; module Models
  class Rfq
    def self.current_revision rfq
      number = rfq.respond_to?(:fetch) ? rfq.fetch('rfq_no') : rfq

      M.database do |db|
        c = (M.cursors[:current_rfq_rev] ||= db.parse(<<-SQL
          select
            revision_no
          from ifsapp.inquiry
          where inquiry_no = :rfq_no
          SQL
        ))

        c.define 1, Fixnum
        c.bind_param ':rfq_no', number, Fixnum
        c.exec

        c.fetch[0]
      end
    end

    def self.fetch number, revision=:latest
      revision = current_revision number if revision == :latest
      rfq = :not_found

      M.database do |db|
        c = (M.cursors[:fetch_rfq] ||= db.parse(fetch_sql))

        c.define 1, Fixnum
        c.define 2, Fixnum
        c.define 8, Date

        c.bind_param ':rfq_no', number, Fixnum
        c.bind_param ':revision', revision, Fixnum
        c.exec

        c.fetch_hash {|r|
          r = r.merge 'text' => DocumentText.for(r)
          rfq = block_given? ? yield(r) : r
        }
      end

      raise NotFound if rfq == :not_found
      return rfq
    end

    def self.expired? rfq
      rfq.fetch('expires') < Date.today
    end

    def self.superceeded? rfq
      rfq.fetch('revision') < current_revision(rfq)
    end

    def self.closed? rfq
      rfq.fetch('status') == 'Closed' ||
      cancelled?(rfq) ||
      expired?(rfq) ||
      superceeded?(rfq)
    end

    def self.cancelled? rfq
      rfq.fetch('status') == 'Cancelled'
    end

    def self.response_allowed? rfq
      !closed?(rfq)
    end

    def self.line rfq, number
      rfq.fetch('lines')[number]
    end

    def self.diff *args, &block
      Diff.call *args, &block
    end

    def self.ifs_url rfq
      IFS.apps_url 'frmInquiry', [rfq.fetch('rfq_no')]
    end
  end
end; end

