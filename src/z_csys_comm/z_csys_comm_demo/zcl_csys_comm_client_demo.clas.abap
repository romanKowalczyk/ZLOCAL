class zcl_csys_comm_client_demo definition
  public
  final
  create public .

  public section.
    interfaces if_oo_adt_classrun.
  protected section.
  private section.
    methods:
      send_http_request importing out type ref to if_oo_adt_classrun_out,
      send_scm_request importing out type ref to if_oo_adt_classrun_out.

    data csys_comm_hdl type ref to zif_csys_comm_handler.
    constants:
      co_host          type string value 'sapes5.sapdevcenter.com',
      co_uri_path      type string value '/sap/opu/odata/sap/ZPDCDS_SRV/SEPMRA_I_Product_E',
      co_uri_path_auth type string value '/sap/opu/odata/iwbep/GWSAMPLE_BASIC/',
      co_query         type string value '?$top=1&$format=json'.
endclass.



class zcl_csys_comm_client_demo implementation.
  method if_oo_adt_classrun~main.
    csys_comm_hdl = new zcl_csys_comm_hdl_url( i_url = |https://{ co_host }{ co_uri_path }{ co_query }| ).
    out->write( 'Client API via URL - Unauthenticated' ).
    send_http_request( out ).
*    out->write( 'Service Communication Model via URL - Unauthenticated' ).
*    send_scm_request( out ).

    csys_comm_hdl = new zcl_csys_comm_hdl_arrange(
      i_scenario_id = 'Z_API_ES5_CSCN'
      i_service_id  = 'Z_ES5_OUTB_REST'
      i_uri_path    = co_uri_path
      i_query       = co_query
    ).
    out->write( 'Client API via Arragements - Unauthenticated' ).
    send_http_request( out ).
*    out->write( 'Service Communication Model via Arragements - Unauthenticated' ).
*    send_scm_request( out ).

    csys_comm_hdl = new zcl_csys_comm_hdl_arrange(
      i_scenario_id = 'Z_API_ES5_CSCN_BAUTH'
      i_service_id  = 'Z_ES5_OUTB_REST'
      i_uri_path    = co_uri_path
      i_query       = co_query
    ).
    out->write( 'Client API via Arragements - Basic Auth' ).
    send_http_request( out ).
    out->write( 'Service Communication Model via Arragements - Basic Auth' ).
    send_scm_request( out ).


*    out->write( 'Communication via Cloud Destination unauthenticated' ).
*    csys_comm_hdl = new zcl_csys_comm_hdl_cloud_dest(
*      i_destination = 'ES5'
*      i_uri_path    = co_uri_path
*      i_query       = co_query
*    ).
*    send_http_request( out ).

*    out->write( 'Communication via RFC Destination unauthenticated' ).
*    csys_comm_hdl = new zcl_csys_comm_hdl_rfc_dest(
*      i_destination = ''
*      i_uri_path    = co_uri_path
*      i_query       = co_query
*    ).
*    send_http_request( out ).
  endmethod.
  method send_http_request.
    try.
        data(http_response) = csys_comm_hdl->send( ).
        data(http_status) = http_response->get_status( ).
        data(http_raw_response) = http_response->get_text( ).

        out->write( |Response: { http_status-code } { http_status-reason } { cl_abap_char_utilities=>newline }Payload: { http_raw_response } { cl_abap_char_utilities=>newline }| ).

      catch cx_web_http_client_error into data(exc).
        out->write( cond string( when exc->previous is bound
            then |{ exc->get_longtext( ) } { exc->previous->get_longtext( ) }|
            else exc->get_longtext( ) )
       ).
    endtry.
  endmethod.

  method send_scm_request.
    data:
      lt_business_data type table of zsc_gwsample_basic_mp=>tys_vh_country,
      lo_http_client   type ref to if_web_http_client,
      lo_resource      type ref to /iwbep/if_cp_resource_entity,
      lo_client_proxy  type ref to /iwbep/if_cp_client_proxy,
      lo_request       type ref to /iwbep/if_cp_request_read_list,
      lo_response      type ref to /iwbep/if_cp_response_read_lst.
**********************************************************************
* TODO migrate as a seprate interface-type COMM Handler or rebuild the handlers
 data(ca_factory) = cl_com_arrangement_factory=>create_instance( ).
    data(cscn_id_range) = value if_com_scenario_factory=>ty_query-cscn_id_range(
        ( sign = 'I' option = 'EQ' low = 'Z_API_ES5_CSCN_BAUTH' )
    ).

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
           comm_scenario  = 'Z_API_ES5_CSCN_BAUTH'
           service_id     = 'Z_ES5_OUTB_REST'
           comm_system_id = ca->get_comm_system_id( )
        ).
        data(http_client) = cl_web_http_client_manager=>create_by_http_destination( http_dest ).
        data(http_request) = http_client->get_http_request( ).
*        if uri_path is not initial.
*            http_request->set_uri_path( i_uri_path = uri_path ).
*        endif.
*        if query is not initial.
*            http_request->set_query( query = query ).
*        endif.
*        r_response = http_client->execute( if_web_http_client=>get ).

    catch cx_http_dest_provider_error cx_web_message_error cx_web_http_client_error into data(exc).
        raise exception type cx_web_http_client_error exporting previous = exc.
    endtry.


**********************************************************************


    try.
*        data(http_response) = csys_comm_hdl->send( ).
        lo_client_proxy = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
          exporting
             is_proxy_model_key       = value #( repository_id       = 'DEFAULT'
                                                 proxy_model_id      = 'ZSC_GWSAMPLE_BASIC_MP'
                                                 proxy_model_version = '0001' )
            io_http_client             = http_client
            iv_relative_service_root   = '/sap/opu/odata/iwbep/GWSAMPLE_BASIC' ).  "investigate how to set URI instead of here (excludes onselves)

        assert http_client is bound.


        " Navigate to the resource and create a request for the read operation
        lo_request = lo_client_proxy->create_resource_for_entity_set( 'VH_COUNTRY_SET' )->create_request_for_read( ).

        " Create the filter tree
*lo_filter_factory = lo_request->create_filter_factory( ).
*
*lo_filter_node_1  = lo_filter_factory->create_by_range( iv_property_path     = 'LAND_1'
*                                                        it_range             = lt_range_LAND_1 ).
*lo_filter_node_2  = lo_filter_factory->create_by_range( iv_property_path     = 'LANDX'
*                                                        it_range             = lt_range_LANDX ).

*lo_filter_node_root = lo_filter_node_1->and( lo_filter_node_2 ).
*lo_request->set_filter( lo_filter_node_root ).

        lo_request->set_top( 50 )->set_skip( 0 ).

        " Execute the request and retrieve the business data
        lo_response = lo_request->execute( ).
        lo_response->get_business_data( importing et_business_data = lt_business_data ).
        out->write( lt_business_data ).

      catch /iwbep/cx_cp_remote into data(lx_remote).
        " Handle remote Exception
        " It contains details about the problems of your http(s) connection

      catch /iwbep/cx_gateway into data(lx_gateway).
        " Handle Exception

      catch cx_web_http_client_error into data(lx_web_http_client_error).
        " Handle Exception
        raise shortdump lx_web_http_client_error.


    endtry.
  endmethod.

endclass.
