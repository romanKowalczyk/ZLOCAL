class zcl_csys_comm_hdl_rfc_dest definition
  public
  final
  create public .

  public section.
    methods:
      constructor importing i_destination type rfcdest
                            i_uri_path    type string
                            i_query       type string.
    interfaces zif_csys_comm_handler .
  protected section.
  private section.
    data: destination type rfcdest,
          uri_path    type string,
          query       type string.
ENDCLASS.



CLASS ZCL_CSYS_COMM_HDL_RFC_DEST IMPLEMENTATION.


  method constructor.
    destination = i_destination.
    uri_path = i_uri_path.
    query = i_query.
  endmethod.


  method zif_csys_comm_handler~send.
    try.
        data(http_destination) = cl_http_destination_provider=>create_by_destination(
        exporting
          i_destination      = destination
        ).
        data(http_client) = cl_web_http_client_manager=>create_by_http_destination( http_destination ).

        data(http_request) = http_client->get_http_request( ).
        http_request->set_uri_path( i_uri_path = uri_path ).
        http_request->set_query( query = query ).
        r_response = http_client->execute( if_web_http_client=>get ).

      catch cx_http_dest_provider_error cx_web_message_error into data(exc).
        raise exception type cx_web_http_client_error exporting previous = exc.
    endtry.

  endmethod.
ENDCLASS.
