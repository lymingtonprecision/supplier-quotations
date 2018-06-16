Needs a user account (e.g. supplierquotes) with the following permissions:

* create session
* select on ifsapp.currency_code_tab
* select on ifsapp.doc_class
* select on ifsapp.doc_issue
* select on ifsapp.doc_title
* select on ifsapp.doc_reference_object
* select on ifsapp.edm_file
* select on ifsapp.edm_file_storage
* select on ifsapp.inquiry
* select on ifsapp.inquiry_hist
* select on ifsapp.inquiry_line_com
* select on ifsapp.inquiry_line_hist
* select on ifsapp.inquiry_line_revision
* select on ifsapp.inquiry_line_revision_ord_com
* select on ifsapp.inquiry_supplier
* select on ifsapp.quotation_order
* select on ifsapp.quotation_line
* select on ifsapp.quotation_line_com
* select on ifsapp.inventory_part
* select on ifsapp.purchase_part
* select on ifsapp.document_text
* select on ifsapp.output_type_document
* execute on ifsapp.lpe_inquiry_util_api
* execute on ifsapp.inquiry_api
* execute on ifsapp.inquiry_hist_api
* execute on ifsapp.inquiry_line_api
* execute on ifsapp.inquiry_line_part_order_api
* execute on ifsapp.quotation_order_api
* execute on ifsapp.quotation_line_api
* execute on ifsapp.quotation_line_part_ord_api
* execute on ifsapp.quotation_line_nopart_ord_api
* execute on ifsapp.supplier_info_api
* execute on ifsapp.person_info_api
* execute on ifsapp.fnd_user_property_api
* execute on ifsapp.fnd_setting_api
* execute on ifsapp.client_sys

... and an entry in the "User Allowed Site" tab:

    insert into ifsapp.user_allowed_site_tab (
      userid, contract, user_site_type
    ) values (
      'SUPPLIERQUOTES', 'LPE', 'DEFAULT SITE'
    );

... and an entry in the "Foundation Users" tab:

    insert into fnd_user_tab (
      identity,
      description,
      oracle_user,
      web_user,
      active,
      rowversion
    ) values (
      'SUPPLIERQUOTES',
      'Supplier Quotes',
      'SUPPLIERQUOTES',
      'SUPPLIERQUOTES',
      'FALSE',
      1
    );

