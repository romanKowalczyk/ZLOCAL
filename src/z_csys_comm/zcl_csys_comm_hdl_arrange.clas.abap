class zcl_csys_comm_hdl_arrange definition
  public
  final
  create public .

  public section.
    methods: constructor
      importing
        i_scenario_id type if_com_management=>ty_cscn_id
        i_service_id  type if_com_management=>ty_cscn_outb_srv_id optional
        i_uri_path    type string optional
        i_query       type string optional.

    interfaces zif_csys_comm_handler .
  protected section.
  private section.
    data: scenario_id type if_com_management=>ty_cscn_id,
          service_id  type if_com_management=>ty_cscn_outb_srv_id,
          uri_path    type string,
          query       type string.
endclass.

class zcl_csys_comm_hdl_arrange implementation.
  method constructor.
    scenario_id = i_scenario_id.
    service_id = i_service_id.
    uri_path = i_uri_path.
    query = i_query.
  endmethod.

  method zif_csys_comm_handler~send.
    data(ca_factory) = cl_com_arrangement_factory=>create_instance( ).
    data(cscn_id_range) = value if_com_scenario_factory=>ty_query-cscn_id_range( ( sign = 'I' option = 'EQ' low = scenario_id ) ).

    ca_factory->query_ca(
      exporting
        is_query           = value #( cscn_id_range = cscn_id_range )
      importing
        et_com_arrangement = data(cas)
    ).

    assert cas is not initial.
    data(ca) = cas[ 1 ].

    try.
        data(http_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
           comm_scenario  = scenario_id
           service_id     = service_id
           comm_system_id = ca->get_comm_system_id( )
        ).
        data(http_client) = cl_web_http_client_manager=>create_by_http_destination( http_dest ).
        data(http_request) = http_client->get_http_request( ).
        if uri_path is not initial.
            http_request->set_uri_path( i_uri_path = uri_path ).
        endif.
        if query is not initial.
            http_request->set_query( query = query ).
        endif.
        r_response = http_client->execute( if_web_http_client=>get ).

    catch cx_http_dest_provider_error cx_web_message_error into data(exc).
        raise exception type cx_web_http_client_error exporting previous = exc.
    endtry.

  endmethod.
endclass.
