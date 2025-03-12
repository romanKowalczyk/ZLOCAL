class zcl_csys_comm_hdl_url definition
  public
  final
  create public .

  public section.
    methods:
       constructor importing i_url type string,
       set_http_method importing i_http_method type if_web_http_client=>method.
    interfaces zif_csys_comm_handler .
  protected section.
  private section.
    data url type string.
    data http_method type if_web_http_client=>method.
ENDCLASS.



CLASS ZCL_CSYS_COMM_HDL_URL IMPLEMENTATION.


  method constructor.
    url = i_url.
    set_http_method( if_web_http_client=>get ).
  endmethod.


  method set_http_method.
    http_method = i_http_method.
  endmethod.


  method zif_csys_comm_handler~send.
    data http_destination type ref to if_http_destination.
    data http_client type ref to if_web_http_client.

    try.
        http_destination = cl_http_destination_provider=>create_by_url( url ).
        http_client = cl_web_http_client_manager=>create_by_http_destination( http_destination ).

        http_client->get_http_request( )->set_header_fields(
            value #( ( name = if_web_http_header=>content_type value = if_web_http_header=>accept_application_json )
                     ( name = if_web_http_header=>accept value = if_web_http_header=>accept_application_json ) )
        ).
        r_response = http_client->execute( http_method ).

      catch cx_http_dest_provider_error cx_web_message_error into data(http_exc).
        raise exception type cx_web_http_client_error
          exporting
            previous = http_exc.
    endtry.
  endmethod.
ENDCLASS.
