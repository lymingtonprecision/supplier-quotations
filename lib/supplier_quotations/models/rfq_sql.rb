module SupplierQuotations; module Models
  class Rfq
    def self.fetch_sql
      <<-SQL
      with revision_dates as (
        select
          i.inquiry_no,
          i.revision_no,
          pr.date_changed previous_release,
          max(i.date_changed) last_changed,
          nvl(pr.history_no, min(i.history_no)) history_starts,
          max(i.history_no) history_ends,
          r.rowstate
        from ifsapp.inquiry_hist i
        left outer join ifsapp.inquiry_hist r
          on i.inquiry_no = r.inquiry_no
          and i.revision_no = r.revision_no
          and r.event_db = 'RELEASED'
        left outer join ifsapp.inquiry_hist pr
          on i.inquiry_no = pr.inquiry_no
          and pr.revision_no = i.revision_no - 1
          and pr.event_db = 'RELEASED'
        where i.inquiry_no = :rfq_no
          and i.revision_no = :revision
          and (r.history_no is null or i.history_no <= r.history_no)
        group by
          i.inquiry_no,
          i.revision_no,
          pr.date_changed,
          pr.history_no,
          r.rowstate
      ),
      changes as (
        select
          ih.event_db,
          ifsapp.inquiry_hist_api.get_from_value(min(ih.history_no), ih.inquiry_no) v
        from revision_dates r
        join ifsapp.inquiry_hist ih
          on r.inquiry_no = ih.inquiry_no
          and ih.history_no > r.history_ends
        group by
          ih.inquiry_no,
          ih.event_db
      ),
      document_text as (
        select
          decode(
            sum(case when ih.history_no between r.history_starts and r.history_ends then 1 else 0 end),
            0, null,
            'Y'
          ) changed,
          decode(
            sum(case when ih.history_no < r.history_ends then 1 else 0 end),
            0, -1,
            i.note_id
          ) note_id
        from revision_dates r
        join ifsapp.inquiry i
          on r.inquiry_no = i.inquiry_no
        join ifsapp.inquiry_hist ih
          on r.inquiry_no = ih.inquiry_no
          and ih.event_db = 'DOC_TEXT'
        group by
          i.note_id
      )
      select
        r.inquiry_no "rfq_no",
        r.revision_no "revision",
        ic.user_id "initiated_by",
        nvl(b.v, i.buyer_code) "buyer_id",
        ifsapp.person_info_api.get_external_display_name(
          nvl(b.v, i.buyer_code)
        ) "buyer_name",
        ifsapp.fnd_user_property_Api.get_value(
          nvl(b.v, i.buyer_code), 'SMTP_MAIL_ADDRESS'
        ) "buyer_email",
        nvl((select v from changes where event_db = 'CURRENCY'), i.currency_code) "currency",
        nvl((select v from changes where event_db = 'TIME_LIMIT'), i.date_expires) "expires",
        nvl(r.rowstate, i.objstate) "status",
        (select changed from document_text) "text_changed",
        nvl((select note_id from document_text), i.note_id) "note_id"
      from revision_dates r
      join ifsapp.inquiry i
        on r.inquiry_no = i.inquiry_no
      join ifsapp.inquiry_hist ic
        on r.inquiry_no = ic.inquiry_no
        and ic.event_db = 'CREATED'
      left outer join changes b
        on b.event_db = 'BUYER'
      SQL
    end
  end
end; end

