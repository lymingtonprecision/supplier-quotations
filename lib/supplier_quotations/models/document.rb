require_relative "./base"

module SupplierQuotations; module Models
  class Document
    def self.bind_document_to_cursor document, cursor
      doc_class, doc_no, sheet, revision = index_from_document document

      cursor.bind_param ':doc_class', doc_class, String, 12
      cursor.bind_param ':doc_no', doc_no, String, 120
      cursor.bind_param ':sheet', sheet, String, 10
      cursor.bind_param ':revision', revision, String, 6

      return cursor
    end

    def self.fetch document_index
      document = :not_found

      M.database do |db|
        c = (M.cursors[:fetch_document] ||= db.parse(fetch_sql))

        c.define 7, Fixnum
        bind_document_to_cursor document_index, c
        c.exec

        c.fetch_hash {|r| document = block_given? ? yield(r) : r}
      end

      raise NotFound if document == :not_found
      return document
    end

    def self.attached_to rfq, line=:none
      documents = []

      M.database do |db|
        if line == :none
          c = (M.cursors[:fetch_head_docs] ||= db.parse(attached_to_head_sql))
        else
          c = (M.cursors[:fetch_line_docs] ||= db.parse(attached_to_line_sql))
        end

        c.define 1, Fixnum
        c.bind_param ':rfq_no', rfq.fetch('rfq_no'), Fixnum

        if line == :none
          c.define 8, Fixnum
        else
          c.define 2, Fixnum
          c.define 9, Fixnum
          line_no = line.respond_to?(:fetch) ? line.fetch('line_no') : line
          c.bind_param ':line_no', line_no, Fixnum
        end

        c.exec

        c.fetch_hash {|r| documents << (block_given? ? yield(r) : r)}
      end

      return documents
    end

    def self.appears_on? rfq, document
      M.database do |db|
        c = (M.cursors[:document_on_rfq] ||= db.parse(appears_on_sql))

        bind_document_to_cursor document, c
        c.bind_param ':rfq_no', rfq.fetch('rfq_no'), Fixnum
        c.exec

        ((c.fetch || [])[0] || 0) > 0
      end
    end

    def self.index_from_document document
      %w{doc_class_no doc_no sheet revision}.collect {|k| document.fetch k}
    end

    def self.data document
      data = :not_found

      M.database do |db|
        c = (M.cursors[:fetch_document_data] ||= db.parse(data_sql))

        bind_document_to_cursor document, c
        c.bind_param ':file_no', document.fetch('file_no'), Fixnum
        c.exec

        c.fetch {|r| data = r[0].read}
      end

      raise NotFound if data == :not_found
      return data
    end
  end
end; end

