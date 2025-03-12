class lhc_yrap100_r_traveltp_lhu definition inheriting from cl_abap_behavior_handler.
  private section.
    constants:
      begin of travel_status,
        open     type c length 1 value 'O', "Open
        accepted type c length 1 value 'A', "Accepted
        rejected type c length 1 value 'X', "Rejected
      end of travel_status.
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

class lhc_yrap100_r_traveltp_lhu implementation.
  method get_global_authorizations.
  endmethod.

  method earlynumbering_create.
    data:
      entity           type structure for create YRAP100_R_TravelTP_LHU,
      travel_id_max    type /dmo/travel_id,
      " change to abap_false if you get the ABAP Runtime error 'BEHAVIOR_ILLEGAL_STATEMENT'
      use_number_range type abap_bool value abap_false.

    "Ensure Travel ID is not set yet (idempotent)- must be checked when BO is draft-enabled
    loop at entities into entity where TravelID is not initial.
      append corresponding #( entity ) to mapped-travel.
    endloop.

    data(entities_wo_travelid) = entities.
    "Remove the entries with an existing Travel ID
    delete entities_wo_travelid where TravelID is not initial.
    if use_number_range = abap_true.
      "Get numbers
      try.
          cl_numberrange_runtime=>number_get(
            exporting
              nr_range_nr       = '01'
              object            = '/DMO/TRV_M'
              quantity          = conv #( lines( entities_wo_travelid ) )
            importing
              number            = data(number_range_key)
              returncode        = data(number_range_return_code)
              returned_quantity = data(number_range_returned_quantity)
          ).
        catch cx_number_ranges into data(lx_number_ranges).
          loop at entities_wo_travelid into entity.
            append value #( %cid      = entity-%cid
                            %key      = entity-%key
                            %is_draft = entity-%is_draft
                            %msg      = lx_number_ranges
                          ) to reported-travel.
            append value #( %cid      = entity-%cid
                            %key      = entity-%key
                            %is_draft = entity-%is_draft
                          ) to failed-travel.
          endloop.
          exit.
      endtry.

      "determine the first free travel ID from the number range
      travel_id_max = number_range_key - number_range_returned_quantity.
    else.
      "determine the first free travel ID without number range
      "Get max travel ID from active table
      select single from yrap100_atravlhu fields max( travel_id ) as travelID into @travel_id_max.
      "Get max travel ID from draft table
      select single from yrap100_dtravlhu fields max( travelid ) into @data(max_travelid_draft).
      if max_travelid_draft > travel_id_max.
        travel_id_max = max_travelid_draft.
      endif.
    endif.
    "Set Travel ID for new instances w/o ID
    loop at entities_wo_travelid into entity.
      travel_id_max += 1.
      entity-TravelID = travel_id_max.

      append value #( %cid      = entity-%cid
                      %key      = entity-%key
                      %is_draft = entity-%is_draft
                    ) to mapped-travel.
    endloop.
  endmethod.

  method setStatusToOpen.
    "Read travel instances of the transferred keys
    read entities of YRAP100_R_TravelTP_LHU in local mode
     entity Travel
       fields ( OverallStatus )
       with corresponding #( keys )
     result data(travels)
     failed data(read_failed).

    "If overall travel status is already set, do nothing, i.e. remove such instances
    delete travels where OverallStatus is not initial.
    check travels is not initial.

    "else set overall travel status to open ('O')
    modify entities of YRAP100_R_TravelTP_LHU in local mode
      entity Travel
        update set fields
        with value #( for travel in travels ( %tky          = travel-%tky
                                              OverallStatus = travel_status-open ) )
    reported data(update_reported).

    "Set the changing parameter
    reported = corresponding #( deep update_reported ).
  endmethod.

**********************************************************************
* Validation: Check the validity of the entered customer data
**********************************************************************
  method validateCustomer.
    "read relevant travel instance data
    read entities of YRAP100_R_TravelTP_LHU in local mode
    entity Travel
     fields ( CustomerID )
     with corresponding #( keys )
    result data(travels).

    data customers type sorted table of /dmo/customer with unique key customer_id.
    "optimization of DB select: extract distinct non-initial customer IDs
    customers = corresponding #( travels discarding duplicates mapping customer_id = customerID except * ).
    delete customers where customer_id is initial.
    if customers is not initial.
      "check if customer ID exists
      select from /dmo/customer fields customer_id
                                for all entries in @customers
                                where customer_id = @customers-customer_id
        into table @data(valid_customers).
    endif.
    "raise msg for non existing and initial customer id
    loop at travels into data(travel).
      append value #( %tky        = travel-%tky
                      %state_area = 'VALIDATE_CUSTOMER'
                    ) to reported-travel.

      if travel-CustomerID is  initial.
        append value #( %tky = travel-%tky ) to failed-travel.
        append value #( %tky                = travel-%tky
                        %state_area         = 'VALIDATE_CUSTOMER'
                        %msg                = new /dmo/cm_flight_messages(
                        textid   = /dmo/cm_flight_messages=>enter_customer_id
                        severity = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on
                      ) to reported-travel.

      elseif travel-CustomerID is not initial and not line_exists( valid_customers[ customer_id = travel-CustomerID ] ).
        append value #(  %tky = travel-%tky ) to failed-travel.
        append value #( %tky                = travel-%tky
                        %state_area         = 'VALIDATE_CUSTOMER'
                        %msg                = new /dmo/cm_flight_messages(
                        customer_id = travel-customerid
                        textid      = /dmo/cm_flight_messages=>customer_unkown
                        severity    = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on
                      ) to reported-travel.
      endif.
    endloop.

  endmethod.


**********************************************************************
* Validation: Check the validity of begin and end dates
**********************************************************************
  method validateDates.

    read entities of YRAP100_R_TravelTP_LHU in local mode
      entity Travel
        fields (  BeginDate EndDate TravelID )
        with corresponding #( keys )
      result data(travels).

    loop at travels into data(travel).

      append value #( %tky        = travel-%tky
                      %state_area = 'VALIDATE_DATES' ) to reported-travel.

      if travel-BeginDate is initial.
        append value #( %tky = travel-%tky ) to failed-travel.
        append value #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new /dmo/cm_flight_messages(
                        textid   = /dmo/cm_flight_messages=>enter_begin_date
                        severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) to reported-travel.
      endif.
      if travel-BeginDate < cl_abap_context_info=>get_system_date( ) and travel-BeginDate is not initial.
        append value #( %tky               = travel-%tky ) to failed-travel.
        append value #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new /dmo/cm_flight_messages(
                        begin_date = travel-BeginDate
                        textid     = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
                        severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) to reported-travel.
      endif.
      if travel-EndDate is initial.
        append value #( %tky = travel-%tky ) to failed-travel.
        append value #( %tky             = travel-%tky
                        %state_area      = 'VALIDATE_DATES'
                        %msg             = new /dmo/cm_flight_messages(
                        textid   = /dmo/cm_flight_messages=>enter_end_date
                        severity = if_abap_behv_message=>severity-error )
                        %element-EndDate = if_abap_behv=>mk-on ) to reported-travel.
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


**************************************************************************
* Instance-bound non-factory action with parameter `deductDiscount`:
* Deduct the specified discount from the booking fee (BookingFee)
**************************************************************************
  method deductDiscount.
    data travels_for_update type table for update YRAP100_R_TravelTP_LHU.
    data(keys_with_valid_discount) = keys.

    " check and handle invalid discount values
    loop at keys_with_valid_discount assigning field-symbol(<key_with_valid_discount>)
      where %param-discount_percent is initial or %param-discount_percent > 100 or %param-discount_percent <= 0.

      " report invalid discount value appropriately
      append value #( %tky                       = <key_with_valid_discount>-%tky ) to failed-travel.

      append value #( %tky                       = <key_with_valid_discount>-%tky
                      %msg                       = new /dmo/cm_flight_messages(
                      textid   = /dmo/cm_flight_messages=>discount_invalid
                      severity = if_abap_behv_message=>severity-error )
                      %element-TotalPrice        = if_abap_behv=>mk-on
                      %op-%action-deductDiscount = if_abap_behv=>mk-on
                    ) to reported-travel.

      " remove invalid discount value
      delete keys_with_valid_discount.
    endloop.

    " check and go ahead with valid discount values
    check keys_with_valid_discount is not initial.

    " read relevant travel instance data (only booking fee)
    read entities of YRAP100_R_TravelTP_LHU in local mode
      entity Travel
        fields ( BookingFee )
        with corresponding #( keys_with_valid_discount )
      result data(travels).

    loop at travels assigning field-symbol(<travel>).
      data percentage type decfloat16.
      data(discount_percent) = keys_with_valid_discount[ key draft %tky = <travel>-%tky ]-%param-discount_percent.
      percentage =  discount_percent / 100 .
      data(reduced_fee) = <travel>-BookingFee * ( 1 - percentage ).

      append value #( %tky       = <travel>-%tky
                      BookingFee = reduced_fee
                    ) to travels_for_update.
    endloop.

    " update data with reduced fee
    modify entities of YRAP100_R_TravelTP_LHU in local mode
      entity Travel
        update fields ( BookingFee )
        with travels_for_update.

    " read changed data for action result
    read entities of YRAP100_R_TravelTP_LHU in local mode
      entity Travel
        all fields with
        corresponding #( travels )
      result data(travels_with_discount).

    " set action result
    result = value #( for travel in travels_with_discount ( %tky   = travel-%tky
                                                            %param = travel ) ).
  endmethod.

**************************************************************************
* Instance-bound factory action `copyTravel`:
* Copy an existing travel instance
**************************************************************************
  method copyTravel.
    data:
       travels       type table for create yrap100_r_traveltp_lhu\\travel.

    " remove travel instances with initial %cid (i.e., not set by caller API)
    read table keys with key %cid = '' into data(key_with_inital_cid).
    assert key_with_inital_cid is initial.

    " read the data from the travel instances to be copied
    read entities of yrap100_r_traveltp_lhu in local mode
       entity travel
       all fields with corresponding #( keys )
    result data(travel_read_result)
    failed failed.

    loop at travel_read_result assigning field-symbol(<travel>).
      " fill in travel container for creating new travel instance
      append value #( %cid      = keys[ key entity %key = <travel>-%key ]-%cid
                      %is_draft = keys[ key entity %key = <travel>-%key ]-%param-%is_draft
                      %data     = corresponding #( <travel> except TravelID )
      )
      to travels assigning field-symbol(<new_travel>).

      " adjust the copied travel instance data
      "" BeginDate must be on or after system date
      <new_travel>-BeginDate     = cl_abap_context_info=>get_system_date( ).
      "" EndDate must be after BeginDate
      <new_travel>-EndDate       = cl_abap_context_info=>get_system_date( ) + 30.
      "" OverallStatus of new instances must be set to open ('O')
      <new_travel>-OverallStatus = travel_status-open.
    endloop.

    " create new BO instance
    modify entities of yrap100_r_traveltp_lhu in local mode
       entity travel
       create fields ( AgencyID CustomerID BeginDate EndDate BookingFee
                         TotalPrice CurrencyCode OverallStatus Description )
          with travels
       mapped data(mapped_create).

    " set the new BO instances
    mapped-travel   =  mapped_create-travel .
  endmethod.


*************************************************************************************
* Instance-bound non-factory action: Set the overall travel status to 'A' (accepted)
*************************************************************************************
  method acceptTravel.
    " modify travel instance
    modify entities of yrap100_r_traveltp_lhu in local mode
       entity Travel
       update fields ( OverallStatus )
       with value #( for key in keys ( %tky          = key-%tky
                                       OverallStatus = travel_status-accepted ) )   " 'A'
    failed failed
    reported reported.

    " read changed data for action result
    read entities of yrap100_r_traveltp_lhu in local mode
       entity Travel
       all fields with
       corresponding #( keys )
       result data(travels).

    " set the action result parameter
    result = value #( for travel in travels ( %tky   = travel-%tky
                                              %param = travel ) ).
  endmethod.


*************************************************************************************
* Instance-bound non-factory action: Set the overall travel status to 'X' (rejected)
*************************************************************************************
  method rejectTravel.
    " modify travel instance(s)
    modify entities of yrap100_r_traveltp_lhu in local mode
       entity Travel
       update fields ( OverallStatus )
       with value #( for key in keys ( %tky          = key-%tky
                                       OverallStatus = travel_status-rejected ) )   " 'X'
    failed failed
    reported reported.

    " read changed data for action result
    read entities of yrap100_r_traveltp_lhu in local mode
       entity Travel
       all fields with
       corresponding #( keys )
       result data(travels).

    " set the action result parameter
    result = value #( for travel in travels ( %tky   = travel-%tky
                                              %param = travel ) ).
  endmethod.

**************************************************************************
* Instance-based dynamic feature control
**************************************************************************
  method get_instance_features.
    " read relevant travel instance data
    read entities of YRAP100_R_TravelTP_LHU in local mode
      entity travel
        fields ( TravelID OverallStatus )
        with corresponding #( keys )
      result data(travels)
      failed failed.

    " evaluate the conditions, set the operation state, and set result parameter
    result = value #( for travel in travels
                      ( %tky                   = travel-%tky

                        %features-%update      = cond #( when travel-OverallStatus = travel_status-accepted
                                                        then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled   )
                        %features-%delete      = cond #( when travel-OverallStatus = travel_status-open
                                                        then if_abap_behv=>fc-o-enabled else if_abap_behv=>fc-o-disabled   )
                        %action-Edit           = cond #( when travel-OverallStatus = travel_status-accepted
                                                         then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled   )
                        %action-acceptTravel   = cond #( when travel-OverallStatus = travel_status-accepted
                                                          then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled   )
                        %action-rejectTravel   = cond #( when travel-OverallStatus = travel_status-rejected
                                                          then if_abap_behv=>fc-o-disabled else if_abap_behv=>fc-o-enabled   )
                        %action-deductDiscount = cond #( when travel-OverallStatus = travel_status-open
                                                          then if_abap_behv=>fc-o-enabled else if_abap_behv=>fc-o-disabled   )
                    ) ).

  endmethod.


endclass.
