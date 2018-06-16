require_relative "./base"

module SupplierQuotations; module Models
  class DocumentText
    def self.for record
      if record.respond_to?(:has_key?) && record.has_key?('note_id')
        note_id = record.fetch('note_id')
      else
        note_id = record
      end

      return [] unless note_id

      note_id = note_id.to_i
      texts = []

      M.database do |db|
        c = (M.cursors[:doc_text] ||= db.parse(<<-SQL
          select
            convert(dt.note_text, 'UTF8')
          from ifsapp.document_text dt
          where dt.note_id = :note_id
            and dt.output_type in (
              select
                ot.output_type
              from ifsapp.output_type_document ot
              where ot.document_code = '53'
            )
          order by
            dt.output_type,
            dt.objid
          SQL
        ))

        c.bind_param ':note_id', note_id, Fixnum
        c.exec

        c.fetch {|r| texts << r[0]}
      end

      return texts
    end
  end
end; end

