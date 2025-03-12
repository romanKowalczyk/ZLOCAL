"! @testing BDEF:YRAP_R_MP_100_TRAV
class yrap_r_tc_mp_100_trav definition
  public
  final
  create public
  for testing risk level harmless duration short.

  public section.
  protected section.
  private section.
    class-data:
      cds_test_environment type ref to if_cds_test_environment,
      sql_test_environment type ref to if_osql_test_environment,
      begin_date           type /dmo/begin_date,
      end_date             type /dmo/end_date,
      agency_mock_data     type standard table of /dmo/agency,
      customer_mock_data   type standard table of /dmo/customer,
      carrier_mock_data    type standard table of /dmo/carrier,
      flight_mock_data     type standard table of /dmo/flight.
    class-methods:
      class_setup,  " setup test double framework
      class_teardown. " stop test doubles
    methods:
      setup,        " reset test doubles
      teardown.     " rollback any changes

    methods:
      create_with_action for testing raising cx_static_check.
ENDCLASS.



CLASS YRAP_R_TC_MP_100_TRAV IMPLEMENTATION.


  method class_setup.
    " create the test doubles for the underlying CDS entities
    cds_test_environment = cl_cds_test_environment=>create_for_multiple_cds( i_for_entities = value #( ( i_for_entity = 'YRAP_R_MP_100_TRAV' ) ) ).

    " create test doubles for additional used tables
    sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = value #(
       ( '/DMO/AGENCY ')
       ( '/DMO/CUSTOMER ')
       ( '/DMO/CARRIER ')
       ( '/DMO/FLIGHT ')
    ) ).

    " prepare the test data
    begin_date = cl_abap_context_info=>get_system_date( ) + 10.
    end_date = cl_abap_context_info=>get_system_date( ) + 30.

    agency_mock_data = value #( ( agency_id = '070041' name = 'Agency 070041' ) ).
    customer_mock_data = value #( ( customer_id = '000093' last_name = 'Customer 000093' ) ).
    carrier_mock_data = value #( ( carrier_id = '123' name = 'Carrier 123 ') ).
    flight_mock_data = value #( ( carrier_id = '123' connection_id = '9876' flight_date = begin_date price = '2000' currency_code = 'EUR' ) ).
  endmethod.


  method class_teardown.
    cds_test_environment->destroy( ).
    sql_test_environment->destroy( ).
  endmethod.


  method create_with_action.
    " create complete composition Travel (root)
    modify entities of yrap_r_mp_100_trav
           entity Travel
                create fields ( AgencyID CustomerID BeginDate EndDate Description TotalPrice BookingFee CurrencyCode )
                with value #( (
                    %cid = 'ROOT1'
                    AgencyID = agency_mock_data[ 1 ]-agency_id
                    CustomerID = customer_mock_data[ 1 ]-customer_id
                    BeginDate = begin_date
                    EndDate = end_date
                    Description = 'Test Travel 1'
                    TotalPrice = '1100'
                    BookingFee = '20'
                    CurrencyCode = 'EUR'
               ) )
          " execute action 'acceptTravel'
          entity Travel
                execute acceptTravel
                from value #( (
                    %cid_ref = 'ROOT1'
                ) )
          " execute action 'deductDiscount'
           entity Travel
                execute deductDiscount
                from value #( (
                    %cid_ref = 'ROOT1'
                    %param-discount_percent = '20'
                ) )
           mapped data(mapped)
           failed data(failed)
           reported data(reported).

    " expect a newly created record in the mapped table
    cl_abap_unit_assert=>assert_initial( msg = 'failed' act = failed ).

    commit entities responses
        failed datA(commit_failed)
        reported data(commit_reported).

    " no failures expected
    cl_abap_unit_assert=>assert_initial( msg = 'commit failed' act = commit_failed ).
    cl_abap_unit_assert=>assert_initial( msg = 'commit reported' act = commit_reported ).

    " read the data from the persisted travel entity (using the test doubles)
    select * from yrap_r_mp_100_trav into table @data(lt_travel).

    " assert the existence of the persisted travel entity
    cl_abap_unit_assert=>assert_not_initial( msg = 'travel from db' act = lt_travel ).
    cl_abap_unit_assert=>assert_not_initial( msg = 'travel-id' act = lt_travel[ 1 ]-TravelID ).
    " assert that action has changed the over status
    cl_abap_unit_assert=>assert_equals( msg = 'Overall Status' exp = 'A' act = lt_travel[ 1 ]-OverallStatus ).
    " assert discount has been applied
    cl_abap_unit_assert=>assert_equals( msg = 'discounted booking_fee' exp = 16 act = lt_travel[ 1 ]-BookingFee ).

  endmethod.


  method setup.
    " clear test doubles per test
    cds_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).
    " insert test data into test doubles
    sql_test_environment->insert_test_data( agency_mock_data ).
    sql_test_environment->insert_test_data( customer_mock_data ).
    sql_test_environment->insert_test_data( carrier_mock_data ).
    sql_test_environment->insert_test_data( flight_mock_data ).
  endmethod.


  method teardown.
    rollback entities.
  endmethod.
ENDCLASS.
