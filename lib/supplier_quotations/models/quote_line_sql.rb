module SupplierQuotations; module Models; class Quote
  class Line
    def self.fetch_sql
      <<-SQL
      select
        inquiry_no "rfq_no",
        line_no "line_no",
        revision_no "revision",
        vendor_no "supplier_id",
        price "price_each",
        promised_delivery_date "promised_date",
        convert(
          regexp_replace(note_text, '^Declined\.?\\s+', ''),
          'UTF8'
        ) "notes",
        case
          when regexp_instr(note_text, '^Declined\.?\\s') > 0 then
            'Declined'
          else
            objstate
        end "status"
      from ifsapp.quotation_line_com
      where inquiry_no = :rfq_no
        and revision_no = :revision
        and (:line_no is null or line_no = :line_no)
        and vendor_no = :supplier
      SQL
    end

    def self.update_sql
      <<-SQL
      declare
        info_ varchar2(32000);
        objid_ varchar2(32000);
        objver_ varchar2(32000);
        attr_ varchar2(32000);

        objstate_ varchar2(20);
        part_no_ varchar2(25);
        price_uom_ varchar2(10);
        price_conv_ number;
        add_cost_ number;
        add_cost_incl_tax_ number;
      begin
        select
          ql.objid,
          ql.objversion,
          ql.objstate,
          ifsapp.inquiry_line_part_order_api.get_part_no(
            ql.inquiry_no, ql.line_no
          ),
          nvl(ql.price_unit_meas, iq.buy_unit_meas),
          nvl(ql.price_conv_factor, 1),
          nvl(ql.additional_cost_amount, 0)
          nvl(ql.additional_cost_incl_tax, 0)
        into
          objid_,
          objver_,
          objstate_,
          part_no_,
          price_uom_,
          price_conv_,
          add_cost_,
          add_cost_incl_tax_
        from ifsapp.quotation_line_com ql
        join ifsapp.inquiry_line_revision iq
          on ql.inquiry_no = iq.inquiry_no
          and ql.revision_no = iq.revision_no
          and ql.line_no = iq.line_no
        where ql.inquiry_no = :rfq_no
          and ql.revision_no = :revision
          and ql.vendor_no = :supplier
          and ql.line_no = :line_no
        ;

        if (objstate_ = 'Answered') then
          ifsapp.quotation_line_api.undo_answer__(
            info_, objid_, objver_, attr_, 'DO'
          );
        end if;

        ifsapp.client_sys.clear_attr(attr_);
        ifsapp.client_sys.add_to_attr('DISCOUNT', 0, attr_);
        ifsapp.client_sys.add_to_attr(
          'PRICE_UNIT_MEAS', price_uom_, attr_
        );
        ifsapp.client_sys.add_to_attr(
          'PRICE_CONV_FACTOR', price_conv_, attr_
        );
        ifsapp.client_sys.add_to_attr(
          'ADDITIONAL_COST_AMOUNT', add_cost_, attr_
        );
        ifsapp.client_sys.add_to_attr(
          'ADDITIONAL_COST_INCL_TAX', add_cost_incl_tax_, attr_
        );
        ifsapp.client_sys.add_to_attr(
          'PRICE', :price_each, attr_
        );
        ifsapp.client_sys.add_to_attr(
          'PRICE_INCL_TAX', :price_each, attr_
        );
        ifsapp.client_sys.add_to_attr(
          'PROMISED_DELIVERY_DATE', :promised_date, attr_
        );
        ifsapp.client_sys.add_to_attr(
          'NOTE_TEXT', :notes, attr_
        );

        if (part_no_ is not null) then
          ifsapp.quotation_line_part_ord_api.modify__(
            info_, objid_, objver_, attr_, 'DO'
          );
        else
          ifsapp.quotation_line_nopart_ord_api.modify__(
            info_, objid_, objver_, attr_, 'DO'
          );
        end if;

        if (:declined > 0) then
          ifsapp.client_sys.clear_attr(attr_);
          ifsapp.quotation_line_api.answer__(
            info_, objid_, objver_, attr_, 'DO'
          );
        end if;
      end;
      SQL
    end
  end
end; end; end

