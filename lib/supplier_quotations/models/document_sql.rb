require_relative "./base"

module SupplierQuotations; module Models
  class Document
    def self.document_fields_sql
      <<-SQL
        di.doc_class "doc_class_no",
        dc.doc_name "doc_class",
        di.doc_no "doc_no",
        di.doc_sheet "sheet",
        di.doc_rev "revision",
        convert(dt.title, 'UTF8') "title",
        f.file_no "file_no",
        convert(f.user_file_name, 'UTF8') "file_name",
        f.file_type "file_type"
      SQL
    end

    def self.document_reference_to_issue_sql
      <<-SQL
        join ifsapp.doc_issue di
          on dro.doc_class = di.doc_class
          and dro.doc_no = di.doc_no
          and dro.doc_sheet = di.doc_sheet
          and dro.doc_rev = di.doc_rev
          and di.objstate <> 'Obsolete'
      SQL
    end

    def self.document_joins_sql
      <<-SQL
        join ifsapp.doc_class dc
          on di.doc_class = dc.doc_class
        join ifsapp.doc_title dt
          on di.doc_class = dt.doc_class
          and di.doc_no = dt.doc_no
        join ifsapp.edm_file f
          on di.doc_class = f.doc_class
          and di.doc_no = f.doc_no
          and di.doc_sheet = f.doc_sheet
          and di.doc_rev = f.doc_rev
      SQL
    end

    def self.fetch_sql
      <<-SQL
      select
        #{document_fields_sql}
      from ifsapp.doc_issue di
      #{document_joins_sql}
      where di.doc_class = :doc_class
        and di.doc_no = :doc_no
        and di.doc_sheet = :sheet
        and di.doc_rev = :revision
        and di.objstate <> 'Obsolete'
      SQL
    end

    def self.document_head_reference_sql
      <<-SQL
      (
        dro.lu_name = 'InquiryOrder' and
        dro.key_ref = 'INQUIRY_NO=' || il.inquiry_no || '^'
      )
      SQL
    end

    def self.document_line_reference_sql
      <<-SQL
      (
        (
          dro.lu_name like 'InquiryLine%' and
          dro.key_ref = 'INQUIRY_NO=' || il.inquiry_no || '^LINE_NO=' || il.line_no || '^'
        )
        or (
          il.part_no is not null and
          dro.lu_name in ('InventoryPart', 'PurchasePart') and
          dro.key_ref = 'CONTRACT=LPE^PART_NO=' || il.part_no || '^'
        )
      )
      SQL
    end

    def self.document_filter_sql
      <<-SQL
      (
        (
          di.doc_class in ('175', '215') and
          f.doc_type = 'VIEW'
        )
        or (
          di.doc_class in ('170', '172', '200', '210') and
          (
            f.doc_type = 'REDLINE' or
            (f.doc_type = 'VIEW' and di.reason_for_issue = 'QUOTE')
          )
        )
      )
      SQL
    end

    def self.attached_to_head_sql
      <<-SQL
      select
        il.inquiry_no "rfq_no",
        #{document_fields_sql}
      from ifsapp.inquiry il
      join ifsapp.doc_reference_object dro
        on #{document_head_reference_sql}
      #{document_reference_to_issue_sql}
      #{document_joins_sql}
      where il.inquiry_no = :rfq_no
        and #{document_filter_sql}
      SQL
    end

    def self.attached_to_line_sql
      <<-SQL
      select
        il.inquiry_no "rfq_no",
        il.line_no "line_no",
        #{document_fields_sql}
      from ifsapp.inquiry_line_com il
      join ifsapp.doc_reference_object dro
        on #{document_line_reference_sql}
      #{document_reference_to_issue_sql}
      #{document_joins_sql}
      where il.inquiry_no = :rfq_no
        and (:line_no is null or il.line_no = :line_no)
        and #{document_filter_sql}
      SQL
    end

    def self.appears_on_sql
      <<-SQL
      select
        count(*)
      from ifsapp.inquiry_line_com il, ifsapp.doc_reference_object dro
      #{document_reference_to_issue_sql}
      #{document_joins_sql}
      where il.inquiry_no = :rfq_no
        and dro.doc_class = :doc_class
        and dro.doc_no = :doc_no
        and dro.doc_sheet = :sheet
        and dro.doc_rev = :revision
        and #{document_filter_sql}
        and (
          #{document_line_reference_sql} or
          #{document_head_reference_sql}
        )
      SQL
    end

    def self.data_sql
      <<-SQL
      select
        fs.file_data
      from ifsapp.doc_issue di
      #{document_joins_sql}
      join ifsapp.edm_file_storage fs
        on f.doc_class = fs.doc_class
        and f.doc_no = fs.doc_no
        and f.doc_sheet = fs.doc_sheet
        and f.doc_rev = fs.doc_rev
        and f.doc_type = fs.doc_type
        and fs.file_no = :file_no
      where di.doc_class = :doc_class
        and di.doc_no = :doc_no
        and di.doc_sheet = :sheet
        and di.doc_rev = :revision
        and #{document_filter_sql}
      SQL
    end
  end
end; end

