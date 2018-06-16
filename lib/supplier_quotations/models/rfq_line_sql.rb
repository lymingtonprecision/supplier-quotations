module SupplierQuotations; module Models; class Rfq
  class Line
    def self.fetch_sql
      <<-SQL
      with revision_date as (
        select
          ih.inquiry_no,
          ih2.date_changed previous_release,
          ih.date_changed d
        from ifsapp.inquiry_hist ih
        left outer join ifsapp.inquiry_hist ih2
          on ih.inquiry_no = ih2.inquiry_no
          and ih2.revision_no = (ih.revision_no - 1)
          and ih2.event_db = 'RELEASED'
        where ih.inquiry_no = :rfq_no
          and ih.revision_no = :revision
          and ih.event_db = 'RELEASED'
      ),
      line_revision_nos as (
        select
          ilh.inquiry_no,
          ilh.line_no,
          max(ilh.revision_no) revision_no,
          min(
            case
              when rd.previous_release is null or ilh.date_changed >= rd.previous_release then
                ilh.history_no
              else
                null
            end
          ) history_no_start,
          max(ilh.history_no) history_no
        from revision_date rd
        join ifsapp.inquiry_line_hist ilh
          on rd.inquiry_no = ilh.inquiry_no
          and ilh.date_changed <= rd.d
        group by
          ilh.inquiry_no,
          ilh.line_no
      ),
      line_revision_description as (
        select
          lrn.inquiry_no,
          lrn.line_no,
          ilh.from_value description
        from line_revision_nos lrn
        join ifsapp.inquiry_line_hist ilh
          on ilh.history_no = (
            select
              min(ilh2.history_no)
            from ifsapp.inquiry_line_hist ilh2
            where lrn.inquiry_no = ilh2.inquiry_no
              and lrn.line_no = ilh2.line_no
              and ilh2.history_no > lrn.history_no
              and ilh2.event_db = 'DESCRIPTION'
          )
      ),
      line_revision_text_change as (
        select
          lrn.inquiry_no,
          lrn.line_no,
          count(ilh.history_no) doc_text_changes
        from line_revision_nos lrn
        join ifsapp.inquiry_line_hist ilh
          on lrn.inquiry_no = ilh.inquiry_no
          and lrn.line_no = ilh.line_no
          and ilh.history_no between lrn.history_no_start and lrn.history_no
          and ilh.event_db = 'DOC_TEXT'
        group by
          lrn.inquiry_no,
          lrn.line_no
      )
      select
        il.inquiry_no "rfq_no",
        il.line_no "line_no",
        il.revision_no "revision",
        pp.part_no "part_no",
        convert(
          nvl(lrd.description, il.description),
          'UTF8'
        ) "description",
        il.quantity "quantity",
        il.buy_unit_meas "uom",
        il.wanted_delivery_date "wanted_date",
        decode(
          ifsapp.inquiry_api.get_revision_no(il.inquiry_no),
          il.revision_no, ifsapp.inquiry_line_api.get_objstate(il.inquiry_no, il.line_no),
          ilh.rowstate
        ) "status",
        decode(nvl(lrtc.doc_text_changes, 0), 0, '', 'Y') "text_changed",
        il.note_id "note_id",
        pp.note_id "purchase_note_id",
        ip.note_id "inventory_note_id"
      from line_revision_nos lrn
      join ifsapp.inquiry_line_revision_ord_com il
        on lrn.inquiry_no = il.inquiry_no
        and il.line_no = lrn.line_no
        and lrn.revision_no = il.revision_no
      join ifsapp.inquiry_line_hist ilh
        on il.inquiry_no = ilh.inquiry_no
        and il.line_no = ilh.line_no
        and il.revision_no = lrn.revision_no
        and ilh.history_no = lrn.history_no
      left outer join line_revision_description lrd
        on il.line_no = lrd.line_no
      left outer join line_revision_text_change lrtc
        on il.line_no = lrtc.line_no
      left outer join ifsapp.purchase_part pp
        on pp.contract = 'LPE'
        and pp.part_no = ifsapp.inquiry_line_part_order_api.get_part_no(
          il.inquiry_no, il.line_no
        )
      left outer join ifsapp.inventory_part ip
        on pp.contract = 'LPE'
        and pp.part_no = ip.part_no
      where :line_no is null or lrn.line_no = :line_no
      order by
        il.line_no
      SQL
    end
  end
end; end; end

