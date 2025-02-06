class lhc_y_r_mp_r620_invt definition inheriting from cl_abap_behavior_handler.
  private section.
    methods:
      get_global_authorizations for global authorization
        importing
        request requested_authorizations for Inventory
        result result,
      CalculateInventoryID for determine on save
        importing keys for Inventory~CalculateInventoryID,
      GetPrice for determine on modify
        importing keys for Inventory~GetPrice.
endclass.

class lhc_y_r_mp_r620_invt implementation.
  method get_global_authorizations.
  endmethod.

  method CalculateInventoryID.
    data inventories type table for read result y_r_mp_r620_invt.

    read entities of y_r_mp_r620_invt in local mode
         entity Inventory
         fields ( InventoryID )
         with corresponding #( keys )
         result inventories.

    delete inventories where InventoryID is not initial.
    check inventories[] is not initial.
    select max( inventory_id ) from ymp_r620_invt into @data(maxInventoryID).

    modify entities of y_r_mp_r620_invt in local mode
           entity Inventory
           update fields ( InventoryID )
           with value #( for inventory in inventories index into i (
                           %tky = inventory-%tky
                           inventoryID = maxInventoryID + i ) )
           reported data(lt_reported).

    reported = corresponding #( deep lt_reported ).
  endmethod.

  method GetPrice.
    data destination type ref to if_soap_destination.
    data proxy type ref to ycl_prx_mp_co_epm_product_soap.
    data response type ycl_prx_mp_res_msg_type.

    data inventories type table for read result y_r_mp_r620_invt.
    data readReported type response for reported y_r_mp_r620_invt.
    data readFailed type response for failed y_r_mp_r620_invt.
    data proxyReported like reported-inventory.

    read entities of y_r_mp_r620_invt in local mode
         entity Inventory
         fields ( ProductID Price ) with corresponding #( keys )
         result inventories
         reported readReported
         failed readFailed.

    delete inventories where ProductID is initial or Price is not initial.
    check inventories is not initial.

    "get price
    loop at inventories assigning field-symbol(<inventory>).
      try.
          if destination is initial.
            destination = cl_soap_destination_provider=>create_by_url('https://sapes5.sapdevcenter.com/sap/bc/srt/xip/sap/zepm_product_soap/002/epm_product_soap/epm_product_soap').
          endif.
          if proxy is initial.
            proxy = new ycl_prx_mp_co_epm_product_soap( destination = destination ).
          endif.

          data(request) = value ycl_prx_mp_req_msg_type( req_msg_type-product = <inventory>-ProductId ).

          proxy->get_price(
            exporting
              input  = request
            importing
              output = response
          ).
          <inventory>-Price = response-res_msg_type-price.
          <inventory>-CurrencyCode = response-res_msg_type-currency.

        catch cx_soap_destination_error into data(x_soap_destination_error).
          data(error_msg) = x_soap_destination_error->get_text( ).
        catch cx_ai_system_fault into data(x_ai_system_fault).
          error_msg = |code: { x_ai_system_fault->code } codetext: { x_ai_system_fault->codecontext }|.
        catch ycl_prx_mp_cx_fault_msg_type into data(x_soap_exc).
          error_msg = x_soap_exc->error_text.
          "fill reported structure to be displayed on UI
          append value #(
              %key = <inventory>-%key
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = error_msg
                     )
              %element-price = if_abap_behv=>mk-on
          ) to readReported-inventory.
          " inventory entry w/ no price should not be passed to modify
          delete table inventories from <inventory>.
      endtry.
    endloop.

    data modifyReported type response for reported y_r_mp_r620_invt.
    data modifyFailed type response for failed y_r_mp_r620_invt.

    modify entities of y_r_mp_r620_invt in local mode
           entity Inventory
           update fields ( Price )
           with value #( for inventory in inventories
            ( %tky = inventory-%tky
              Price = inventory-Price
              CurrencyCode = inventory-CurrencyCode )
           )
           reported modifyReported
           failed modifyFailed.

     reported = corresponding #( deep modifyReported ).
     reported-inventory = corresponding #( deep appending base ( reported-inventory ) readReported-inventory ).

  endmethod.

endclass.
