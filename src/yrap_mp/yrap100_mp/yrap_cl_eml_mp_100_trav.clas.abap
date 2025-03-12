class yrap_cl_eml_mp_100_trav definition
  public
  final
  create public .

  public section.

    interfaces if_oo_adt_classrun .
  protected section.
  private section.
    constants:
      is_draft  type if_abap_behv=>t_xflag value if_abap_behv=>mk-on,
      is_active type if_abap_behv=>t_xflag value if_abap_behv=>mk-off.

    class-data:
      travel_id      type /dmo/travel_id,
      instance_state type if_abap_behv=>t_xflag,
      console_out    type ref to if_oo_adt_classrun_out.

    methods:
      read_travel,
      update_travel,
      create_travel,
      delete_travel,
      activate_travel_draft,
      discard_travel_draft.
ENDCLASS.



CLASS YRAP_CL_EML_MP_100_TRAV IMPLEMENTATION.


  method activate_travel_draft.
    modify entity yrap_r_mp_100_trav
        execute Activate
        from value #( ( %cid = 'activate_draft_travel' %key-TravelId = travel_id ) )
        mapped data(mapped)
        reported data(reported)
        failed data(failed).

    "persist the transactional buffer
    commit entities
         response of yrap_r_mp_100_trav
         failed data(failed_commit)
         reported data(reported_commit).

    console_out->write( |Activate a draft travel BO entity instance| ).
    console_out->write( mapped-travel ).
    if failed is not initial.
      console_out->write( |- Cause for failed update = { failed-travel[ 1 ]-%fail-cause } | ).
    elseif failed_commit is not initial.
      console_out->write( |- Cause for failed commit = { failed_commit-travel[ 1 ]-%fail-cause } | ).
    endif.
    console_out->write( |----------------------------------------------------------| ).
  endmethod.


  method create_travel.
    data fields type table for create yrap_r_mp_100_trav\\Travel.

    fields = value #( (
         %cid        = 'create_travel'
         %is_draft   = instance_state
         CustomerID  = '15'
         AgencyID    = '070042'
         BeginDate   = cl_abap_context_info=>get_system_date( )
         EndDate     = cl_abap_context_info=>get_system_date( ) + 10
         Description = | ABAP DevDays { cl_abap_context_info=>get_system_time(  ) } |
    ) ).

    modify entity yrap_r_mp_100_trav\\Travel
           create fields ( CustomerID AgencyID BeginDate EndDate Description )
           with fields
           mapped data(mapped)
           reported data(reported)
           failed data(failed).

    "persist the transactional buffer
    commit entities
         response of yrap_r_mp_100_trav
         failed data(failed_commit)
         reported data(reported_commit).

    console_out->write( |Create a Travel BO entity instance| ).
    console_out->write( mapped-travel ).
    if failed is not initial.
      console_out->write( |- Cause for failed update = { failed-travel[ 1 ]-%fail-cause } | ).
    elseif failed_commit is not initial.
      console_out->write( |- Cause for failed commit = { failed_commit-travel[ 1 ]-%fail-cause } | ).
    endif.
    console_out->write( |----------------------------------------------------------| ).
  endmethod.


  method delete_travel.
    modify entity yrap_r_mp_100_trav
        delete from value #( ( TravelID = travel_id %is_draft = instance_state ) )
        failed data(failed)
        reported data(reported).

    commit entities
         response of yrap_r_mp_100_trav
         failed data(failed_commit)
         reported data(reported_commit).

    console_out->write( |Delete a Travel BO entity instance| ).
    console_out->write( |- TravelID = { travel_id }| ).
    if failed is not initial.
      console_out->write( |- Cause for failed update = { failed-travel[ 1 ]-%fail-cause } | ).
    elseif failed_commit is not initial.
      console_out->write( |- Cause for failed commit = { failed_commit-travel[ 1 ]-%fail-cause } | ).
    endif.
    console_out->write( |----------------------------------------------------------| ).
  endmethod.


  method discard_travel_draft.
    data draftWhere type table for read import yrap_r_mp_100_trav.
    data travelKeys type table for action import yrap_r_mp_100_trav~Discard.
    data travelDraftKeys type table for read result yrap_r_mp_100_trav.
    data reported type response for reported yrap_r_mp_100_trav.
    data failed type response for failed yrap_r_mp_100_trav.
    data failed_commit type response for failed late yrap_r_mp_100_trav.
    data reported_commit type response for reported late yrap_r_mp_100_trav.

    draftWhere = value #( ( TravelID = travel_id %is_draft = is_draft ) ).

    read entities of yrap_r_mp_100_trav
         entity Travel
         fields ( TravelID )
         with draftWhere
         result travelDraftKeys.

    travelKeys = value #( for travelDraftKey in travelDraftKeys
        ( TravelID = travelDraftKey-TravelId )
    ).
    modify entities of yrap_r_mp_100_trav
           entity Travel
           execute Discard from travelKeys
           reported reported
           failed failed.

    commit entities
           response of yrap_r_mp_100_trav
           failed failed_commit
           reported reported_commit.

    console_out->write( |Discard draft of a Travel BO entity instance| ).
    console_out->write( |- TravelID = { travel_id }| ).
    if failed is not initial.
      console_out->write( |- Cause for failed update = { failed-travel[ 1 ]-%fail-cause } | ).
    elseif failed_commit is not initial.
      console_out->write( |- Cause for failed commit = { failed_commit-travel[ 1 ]-%fail-cause } | ).
    endif.
    console_out->write( |----------------------------------------------------------| ).

  endmethod.


  method if_oo_adt_classrun~main.
    console_out = out.

    data(exec) = 55.

    "READ
    if exec = 1 or exec = 55.
      travel_id = '00000005'.
      instance_state = is_active.
      read_travel( ).
    endif.

    "UPDATE
    if exec = 2 or exec = 55.
      travel_id = '00000007'.
      instance_state = is_active.
      update_travel( ).
    endif.

    "CREATE
    if exec = 3 or exec = 55.
      instance_state = is_active.
      create_travel( ).
    endif.

    "DELETE
    if exec = 4 or exec = 55.
      travel_id = '00000006'.
      instance_state = is_active.
      delete_travel( ).
    endif.

    "ACTIVATE
    if exec = 5 or exec = 55.
      travel_id = '00000007'.
      activate_travel_draft( ).
    endif.

    "DISCARD TRAVEL DRAFT
    if exec = 4 or exec = 55.
      travel_id = '00000008'.
      instance_state = is_draft.
      discard_travel_draft( ).
    endif.
  endmethod.


  method read_travel.
    data travels type table for read result yrap_r_mp_100_trav.
    data failed type response for failed yrap_r_mp_100_trav.
    data reported type response for reported yrap_r_mp_100_trav.

    read entities of yrap_r_mp_100_trav
         entity Travel
         all fields
         with value #( ( TravelID = travel_id %is_draft = instance_state ) )
         result travels
         failed failed
         reported reported.

    console_out->write( |Read a Travel BO entity instance| ).
    console_out->write( travels ).
    if failed is not initial.
      console_out->write( |- Cause for failed read = { failed-travel[ 1 ]-%fail-cause } | ).
    endif.
    console_out->write( |----------------------------------------------------------| ).
  endmethod.


  method update_travel.
    data fields_tab type table for update yrap_r_mp_100_trav.
    data failed type response for failed yrap_r_mp_100_trav.
    data reported type response for reported yrap_r_mp_100_trav.
    data failed_commit type response for failed late yrap_r_mp_100_trav.
    data reported_commit type response for reported late yrap_r_mp_100_trav.

    fields_tab = value #( (
            %is_draft = instance_state
            TravelID = travel_id
            Description = |Vacation { cl_abap_context_info=>get_system_date( ) }|
    ) ).

    "update the transactional buffer
    modify entities of yrap_r_mp_100_trav
        entity Travel
        update fields ( Description )
        with fields_tab
        failed failed
        reported reported.

    "persist the transactional buffer
    commit entities
         response of yrap_r_mp_100_trav
         failed failed_commit
         reported reported_commit.

    console_out->write( |Update a Travel BO entity instance| ).
    console_out->write( |- TravelID = { travel_id } / Description was updated| ).
    if failed is not initial.
      console_out->write( |- Cause for failed update = { failed-travel[ 1 ]-%fail-cause } | ).
    elseif failed_commit is not initial.
      console_out->write( |- Cause for failed commit = { failed_commit-travel[ 1 ]-%fail-cause } | ).
    endif.
    console_out->write( |----------------------------------------------------------| ).
  endmethod.
ENDCLASS.
