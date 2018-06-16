module SupplierQuotations; module Models
  class Quote
    def self.update_sql
      <<-SQL
      declare
        info_ varchar2(32000);
        objid_ varchar2(32000);
        objver_ varchar2(32000);
        attr_ varchar2(32000);

        date_received_ date;
      begin
        select
          qo.objid,
          qo.objversion,
          nvl(
            qo.date_received,
            decode(
              (
                select
                  nvl(count(ql.line_no), 0)
                from ifsapp.quotation_line ql
                where qo.inquiry_no = ql.inquiry_no
                  and qo.revision_no = ql.revision_no
                  and qo.vendor_no = ql.vendor_no
                  and ql.objstate = 'Created'
              ),
              0, sysdate,
              null
            )
          )
        into
          objid_,
          objver_,
          date_received_
        from ifsapp.quotation_order qo
        where qo.inquiry_no = :rfq_no
          and qo.revision_no = :revision
          and qo.vendor_no = :supplier
        ;

        ifsapp.client_sys.add_to_attr('LAST_ACTIVITY_DATE', sysdate, attr_);

        if :currency is not null then
          ifsapp.client_sys.add_to_attr('CURRENCY_CODE', :currency, attr_);
        end if;

        if date_received_ is not null then
          ifsapp.client_sys.add_to_attr(
            'DATE_RECEIVED', date_received_, attr_
          );
        end if;

        ifsapp.quotation_order_api.modify__(
          info_, objid_, objver_, attr_, 'DO'
        );

        ifsapp.lpe_inquiry_util_api.queue_quote_confirmation(
          :rfq_no, :revision, :supplier
        );
      end;
      SQL
    end
  end
end; end

