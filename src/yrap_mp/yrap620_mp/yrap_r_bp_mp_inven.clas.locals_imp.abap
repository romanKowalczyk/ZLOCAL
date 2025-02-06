class lhc_yrap_r_mp_inven definition inheriting from cl_abap_behavior_handler.
  public section.
    types: t_reported type response for reported late yrap_r_mp_inven.
  private section.
    methods:
      get_global_authorizations for global authorization
        importing
        request requested_authorizations for Inventory
        result result,
      CalculateInventoryID for determine on save
        importing keys for Inventory~CalculateInventoryID,
      GetPrice for determine on modify
        importing keys for Inventory~GetPrice,
      GetProductPriceSoap importing i_product type yrap_r_mp_inven-ProductId
                          exporting e_price   type yrap_r_mp_inven-Price
                                    e_currency type yrap_r_mp_inven-CurrencyCode
                                    e_reported type lhc_yrap_r_mp_inven=>t_reported.

    data destination_soap type ref to if_soap_destination.
    data proxy_soap type ref to yrap620_co_epm_product_soap.
endclass.

class lhc_yrap_r_mp_inven implementation.
  method get_global_authorizations.
  endmethod.
  method CalculateInventoryID.
    data inventories type table for read result yrap_r_mp_inven.

    read entities of yrap_r_mp_inven in local mode
         entity Inventory
         fields ( InventoryID )
         with corresponding #( keys )
         result inventories.

    delete inventories where InventoryID is not initial.
    check inventories[] is not initial.
    select max( inventory_id ) from yrap_a_mp_inven into @data(maxInventoryID).

    modify entities of yrap_r_mp_inven in local mode
           entity Inventory
           update fields ( InventoryID )
           with value #( for inventory in inventories index into i (
                           %tky = inventory-%tky
                           inventoryID = maxInventoryID + i ) )
           reported data(lt_reported).

    reported = corresponding #( deep lt_reported ).
  endmethod.

  method GetPrice.
    data inventories type table for read result yrap_r_mp_inven.
    data reported_inventory_soap like reported.

    read entities of yrap_r_mp_inven in local mode
         entity Inventory
         fields ( Price ProductID )
         with corresponding #( keys )
         result inventories.

    delete inventories where ProductId is initial.

    loop at inventories assigning field-symbol(<inventory>).
        getproductpricesoap(
          exporting
            i_product  = <inventory>-ProductId
          importing
            e_price    = <inventory>-Price
            e_currency = <inventory>-CurrencyCode
            e_reported = reported_inventory_soap
        ).
    endloop.

    modify entities of yrap_r_mp_inven in local mode
           entity Inventory
           update fields ( Price CurrencyCode )
           with value #( for inventory in inventories (
                             %tky = inventory-%tky
                             Price = inventory-Price
                             CurrencyCode = inventory-CurrencyCode
                        ) )
           reported data(lt_reported).

    reported = corresponding #( deep lt_reported ).

    loop at reported_inventory_soap-inventory assigning field-symbol(<reported_inventory_soap>).
      append <reported_inventory_soap> to reported-inventory.
    endloop.

  endmethod.

  method getproductpricesoap.
    try.
        if destination_soap is initial.
          destination_soap = cl_soap_destination_provider=>create_by_url( 'https://sapes5.sapdevcenter.com/sap/bc/srt/xip/sap/zepm_product_soap/002/epm_product_soap/epm_product_soap' ).
        endif.
        if proxy_soap is initial.
          proxy_soap = new yrap620_co_epm_product_soap( destination = destination_soap ).
        endif.

        " fill request
        data(request) = value yrap620_req_msg_type( ).
        request-req_msg_type-product = i_product.

        proxy_soap->get_price(
          exporting
            input = request
          importing
            output = data(response)
        ).
        e_price = response-res_msg_type-price.
        e_currency = response-res_msg_type-currency.
      catch cx_soap_destination_error into data(exc_soap_destination).
        data(error_message) = exc_soap_destination->get_text( ).
      catch cx_ai_system_fault into data(exc_system).
        error_message = |code: { exc_system->code }, codetextext: { exc_system->codecontext }|.
      catch yrap620_cx_fault_msg_type into data(exc_soap).
        error_message = exc_soap->error_text.
    endtry.

    if error_message is not initial.
        append value #(
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = error_message
                   )
            %element-price = if_abap_behv=>mk-on
        ) to e_reported-inventory.
    endif.
  endmethod.

endclass.
