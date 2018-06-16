require_relative "./base"

module SupplierQuotations; module Models
  class Solicitation
    def self.all_for rfq
      rfq_no = rfq.fetch 'rfq_no'
      solicitations = []

      M.database do |db|
        c = (M.cursors[:solicitations_for_rfq] ||= db.parse(<<-SQL
          select
            inquiry_no "rfq_no",
            vendor_no "supplier_id",
            ifsapp.supplier_info_api.get_name(vendor_no) "supplier",
            addr_no "address_no",
            contact "contact_id",
            last_printed_revision "last_seen_revision"
          from ifsapp.inquiry_supplier
          where inquiry_no = :rfq_no
          SQL
        ))

        c.define 1, Fixnum
        c.define 6, Fixnum

        c.bind_param ':rfq_no', rfq_no, Fixnum
        c.exec

        c.fetch_hash {|r| solicitations << (block_given? ? yield(r) : r)}
      end

      return solicitations
    end

    def self.fetch supplier_id, rfq
      supplier = all_for(rfq).find {|s| s.fetch("supplier_id") == supplier_id}
      raise NotFound if supplier.nil?
      return supplier
    end

    def self.was_sent_prior_revision? solicitation, rfq
      sr = solicitation.fetch('last_seen_revision')
      sr && sr < rfq.fetch('revision') ? sr : false
    end
  end
end; end

