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


endclass.
