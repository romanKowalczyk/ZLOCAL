class lhc_yrap_r_mp_100_trav definition inheriting from cl_abap_behavior_handler.
  private section.
    constants:
      begin of co_travel_status,
        open     type c length 1 value 'O',
        accepted type c length 1 value 'A',
        rejected type c length 1 value 'X',
      end of co_travel_status.
    methods:
      get_global_authorizations for global authorization
        importing
        request requested_authorizations for Travel
        result result,
      earlynumbering_create for numbering
        importing entities for create Travel,
      setStatusToOpen for determine on modify
        importing keys for Travel~setStatusToOpen,
      validateCustomer for validate on save
        importing keys for Travel~validateCustomer.

    methods validateDates for validate on save
      importing keys for Travel~validateDates.
    methods deductDiscount for modify
      importing keys for action Travel~deductDiscount result result.
    methods copyTravel for modify
      importing keys for action Travel~copyTravel.
    methods acceptTravel for modify
      importing keys for action Travel~acceptTravel result result.

    methods rejectTravel for modify
      importing keys for action Travel~rejectTravel result result.
    methods get_instance_features for instance features
      importing keys request requested_features for Travel result result.
endclass.

class lhc_yrap_r_mp_100_trav implementation.
  method get_global_authorizations.
  endmethod.
  method earlynumbering_create.
    data: entity            type structure for create yrap_r_mp_100_trav,
          travel_id_max     type /dmo/travel_id,
          user_number_range type abap_bool value abap_true.

    loop at entities into entity where TravelID is not initial.
      append corresponding #( entity ) to mapped-travel.
    endloop.

    data(entities_wo_travelid) = entities.
    delete entities_wo_travelid where TravelID is not initial.

    if user_number_range = abap_true.
      "get numbers
      try.
          cl_numberrange_runtime=>number_get(
            exporting
              nr_range_nr       = '01'
              object            = '/DMO/TRV_M'
              quantity          = conv #( lines( entities_wo_travelid ) )
            importing
              number            = data(number_range_key)
              returncode        = data(number_range_ret_code)
              returned_quantity = data(number_range_ret_quant)
          ).
        catch cx_nr_object_not_found cx_number_ranges into data(exc_number_ranges).
          loop at entities_wo_travelid into entity.
            append value #(
                %cid = entity-%cid
                %key = entity-%key
                %is_draft = entity-%is_draft
            ) to failed-travel.
            append value #(
                %cid = entity-%cid
                %key = entity-%key
                %is_draft = entity-%is_draft
                %msg = exc_number_ranges
            ) to reported-travel.
          endloop.
      endtry.
      travel_id_max = number_range_key - number_range_ret_quant.
    else.
      "determine the first free travel id w/o number range
      "get max travel ID from active table
      select single from yrap_a_mp_trav fields max( travel_id ) as travelID into @travel_id_max.
      "get max travel ID from draft table
      select single from yrap_d_mp_trav fields max( travelid ) into @data(max_travelid_draft).
      if max_travelid_draft > travel_id_max.
        travel_id_max = max_travelid_draft.
      endif.
    endif.

    loop at entities_wo_travelid into entity.
      travel_id_max += 1.
      entity-TravelId = travel_id_max.

      append value #(
          %cid = entity-%cid
          %key = entity-%key
          %is_draft = entity-%is_draft
      ) to mapped-travel.
    endloop.
  endmethod.

  method setStatusToOpen.
    read entities of yrap_r_mp_100_trav in local mode
         entity Travel
         fields ( OverallStatus )
         with corresponding #( keys )
         result data(travels)
         failed data(failed).

*    delete travels where OverallStatus is not initial.
*    check travels is not initial.

    modify entities of yrap_r_mp_100_trav in local mode
           entity Travel
           update fields ( OverallStatus )
           with value #( for travel in travels
                ( %tky = travel-%tky
                  OverallStatus = co_travel_status-open ) )
           reported data(update_reported).

    reported = corresponding #( deep update_reported ).
  endmethod.

  method validateCustomer.
    read entities of yrap_r_mp_100_trav in local mode
         entity Travel
         fields ( CustomerID )
         with corresponding #( keys )
         result data(travels).

    data customers type sorted table of /dmo/customer with unique key customer_id.

    customers = corresponding #( travels discarding duplicates mapping customer_id = customerID except * ).
    delete customers where customer_id is initial.
    if customers is not initial.
      select from /dmo/customer fields customer_id
             for all entries in @customers
             where customer_id = @customers-customer_id
             into table @data(valid_customers).
    endif.
    loop at travels into data(travel).
      append value #( %tky = travel-%tky
                      %state_area = 'VALIDATE_CUSTOMER'
      ) to reported-travel.

      if travel-CustomerID is initial.
        append value #( %tky = travel-%tky ) to failed-travel.

        append value #( %tky = travel-%tky
                        %state_area = 'VALIDATE_CUSTOMER'
                        %msg = new /dmo/cm_flight_messages(
                            textid = /dmo/cm_flight_messages=>enter_customer_id
                            severity = if_abap_behv_message=>severity-error
                        )
                        %element-CustomerID = if_abap_behv=>mk-on
        ) to reported-travel.
      elseif travel-CustomerID is not initial and not line_exists( valid_customers[ customer_id = travel-CustomerID ] ).
        append value #( %tky = travel-%tky ) to failed-travel.

        append value #( %tky = travel-%tky
                        %state_area = 'VALIDATE_CUSTOMER'
                        %msg = new /dmo/cm_flight_messages(
                            textid = /dmo/cm_flight_messages=>customer_unkown
                            customer_id = travel-customerid
                            severity = if_abap_behv_message=>severity-error
                        )
                        %element-CustomerID = if_abap_behv=>mk-on
        ) to reported-travel.
      endif.
    endloop.

  endmethod.

  method validateDates.
    read entities of yrap_r_mp_100_trav in local mode
         entity Travel
         fields ( BeginDate EndDate TravelID )
         with corresponding #( keys )
         result data(travels).

    loop at travels into data(travel).
      append value #( %tky = travel-%tky
                      %state_area = 'VALIDATE_DATES'
      ) to reported-travel.
      if travel-BeginDate is initial.
        append value #( %tky = travel-%tky ) to failed-travel.

        append value #( %tky = travel-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg = new /dmo/cm_flight_messages(
                            textid = /dmo/cm_flight_messages=>enter_begin_date
                            severity = if_abap_behv_message=>severity-error
                        )
                        %element-BeginDate = if_abap_behv=>mk-on
        ) to reported-travel.

      elseif travel-BeginDate < cl_abap_context_info=>get_system_date( ) and travel-BeginDate is not initial.
        append value #( %tky = travel-%tky ) to failed-travel.

        append value #( %tky = travel-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg = new /dmo/cm_flight_messages(
                            textid = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
                            begin_date = travel-BeginDate
                            severity = if_abap_behv_message=>severity-error
                        )
                        %element-BeginDate = if_abap_behv=>mk-on
        ) to reported-travel.
      endif.

      if travel-EndDate is initial.
        append value #( %tky = travel-%tky ) to failed-travel.

        append value #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg                = new /dmo/cm_flight_messages(
                            textid   = /dmo/cm_flight_messages=>enter_end_date
                            severity = if_abap_behv_message=>severity-error
                        )
                        %element-EndDate   = if_abap_behv=>mk-on ) to reported-travel.
      endif.
      if travel-EndDate < travel-BeginDate and travel-BeginDate is not initial
                                           and travel-EndDate is not initial.
        append value #( %tky = travel-%tky ) to failed-travel.

        append value #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new /dmo/cm_flight_messages(
                                                                textid     = /dmo/cm_flight_messages=>begin_date_bef_end_date
                                                                begin_date = travel-BeginDate
                                                                end_date   = travel-EndDate
                                                                severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate   = if_abap_behv=>mk-on ) to reported-travel.
      endif.
    endloop.
  endmethod.

  METHOD deductDiscount.
    data travels_for_update type table for update yrap_r_mp_100_trav.
    data(keys_with_valid_discount) = keys.

    loop at keys_with_valid_discount into data(key_with_valid_discount)
            where %param-discount_percent is initial
               or %param-discount_percent > 100
               or %param-discount_percent <= 0.
        "report invalid discount value
        append value #( %tky = key_with_valid_discount-%tky ) to failed-travel.
        append value #(
            %tky = key_with_valid_discount-%tky
            %msg = new /dmo/cm_flight_messages(
                textid = /dmo/cm_flight_messages=>discount_invalid
                severity = if_abap_behv_message=>severity-error )
            %element-BookingFee = if_abap_behv=>mk-on
            %op-%action-deductDiscount = if_abap_behv=>mk-on
        ) to reported-Travel.

        delete keys_with_valid_discount.
    endloop.

    check keys_with_valid_discount is not initial.

    read entities of yrap_r_mp_100_trav in local mode
         entity Travel
         fields ( BookingFee )
         with corresponding #( keys_with_valid_discount )
         result data(travels).

     loop at travels into data(travel).
        data(discount_percent) = keys_with_valid_discount[ key draft %tky = travel-%tky ]-%param-discount_percent.
        data percentage type decfloat16.
        percentage = discount_percent / 100.
        data(reduced_fee) = travel-BookingFee * ( 1 - percentage ).

        append value #(
            %tky = travel-%tky
            BookingFee = reduced_fee
        ) to travels_for_update.
     endloop.

     "update data with reduced fee
     modify entities of yrap_r_mp_100_trav in local mode
            entity Travel
            update fields ( BookingFee )
            with travels_for_update.

     " read changed data for action result
     read entities of yrap_r_mp_100_trav in local mode
          entity Travel
          all fields with corresponding #( travels )
          result data(travels_with_discount).

     " set action result parameter
     result = value #( for travel_with_discount in travels_with_discount
        ( %tky = travel_with_discount-%tky
          %param = travel )
     ).
  ENDMETHOD.

  METHOD copyTravel.
    data travels type table for create yrap_r_mp_100_trav\\Travel.
    data travels_read_result type table for read result yrap_r_mp_100_trav\\Travel.

    "remove travel instances with initial %cid (i.e. not set by caller API)
    read table keys with key %cid = '' into data(key_with_initial_cid).
    assert key_with_initial_cid is initial.

    read entities of yrap_r_mp_100_trav in local mode
         entity Travel
         all fields with corresponding #( keys )
         result travels_read_result
         failed failed.

    loop at travels_read_result into data(travel).
        append value #(
            %cid = keys[ key entity %key = travel-%key ]-%cid
            %is_draft = keys[ key entity %key = travel-%key ]-%param-%is_draft
        ) to travels assigning field-symbol(<new_travel>).

        <new_travel>-%data = travel-%data.
        <new_travel>-BeginDate = cl_abap_context_info=>get_system_date( ).
        <new_travel>-EndDate = cl_abap_context_info=>get_system_date( ) + 30.
        <new_travel>-OverallStatus = co_travel_status-rejected.
    endloop.

    "create new BO instance
    modify entities of yrap_r_mp_100_trav in local mode
           entity Travel
           create fields ( AgencyID CustomerID BeginDate EndDate BookingFee TotalPrice CurrencyCode Description )
           with travels
           mapped data(mapped_create).

    " set the new BP instances
    mapped-travel = mapped_create-travel.
  ENDMETHOD.

  METHOD acceptTravel.
    " modify travel instance
    modify entities of yrap_r_mp_100_trav in local mode
          entity Travel
          update fields ( OverallStatus )
          with value #( for key in keys
            ( %tky = key-%tky
              OverallStatus = co_travel_status-accepted )
          )
          reported reported
          failed failed.

     " read changed entities from the buffer
     read entities of yrap_r_mp_100_trav in local mode
          entity Travel
          all fields with corresponding #( keys )
          result data(travels).

    " set the action result parameter
    result = value #( for travel in travels
        ( %tky = travel-%tky
          %param = travel )
    ).
  ENDMETHOD.

  METHOD rejectTravel.
    " modify travel instance
    modify entities of yrap_r_mp_100_trav in local mode
          entity Travel
          update fields ( OverallStatus )
          with value #( for key in keys
            ( %tky = key-%tky
              OverallStatus = co_travel_status-rejected )
          )
          reported reported
          failed failed.

     " read changed entities from the buffer
     read entities of yrap_r_mp_100_trav in local mode
          entity Travel
          all fields with corresponding #( keys )
          result data(travels).

    " set the action result parameter
    result = value #( for travel in travels
        ( %tky = travel-%tky
          %param = travel )
    ).
  ENDMETHOD.

  METHOD get_instance_features.
    read entities of yrap_r_mp_100_trav in local mode
         entity Travel
         fields ( TravelID OverallStatus )
         with corresponding #( keys )
         result data(travels).

    result = value #( for travel in travels
        ( %tky = travel-%tky
          %features-%delete = cond #( when travel-OverallStatus = co_travel_status-open then if_abap_behv=>fc-o-enabled else if_abap_behv=>fc-o-disabled )
          %features-%update = cond #( when travel-OverallStatus = co_travel_status-accepted then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled )
          %action-Edit = cond #( when travel-OverallStatus = co_travel_status-accepted then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled )
          %action-deductDiscount = cond #( when travel-OverallStatus = co_travel_status-open then if_abap_behv=>fc-o-enabled else if_abap_behv=>fc-o-disabled )
          %action-acceptTravel = cond #( when travel-OverallStatus = co_travel_status-accepted then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled )
          %action-rejectTravel = cond #( when travel-OverallStatus = co_travel_status-rejected then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled ) )
    ).
  ENDMETHOD.

endclass.
