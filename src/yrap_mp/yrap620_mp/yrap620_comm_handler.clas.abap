class yrap620_comm_handler definition
  public
  final
  create public .

  public section.
    methods:
        send_request_by_url
            importing url type string
            returning value(lo_response) type ref to if_web_http_response
            raising cx_web_http_client_error,

        send_request_by_arrangement
            importing
                scenario_id type if_com_management=>ty_cscn_id
                service_id type if_com_management=>ty_cscn_outb_srv_id optional
                uri_path type string
                query type string
            returning value(lo_response) type ref to if_web_http_response
            raising cx_web_http_client_error.
  protected section.
  private section.
ENDCLASS.



CLASS YRAP620_COMM_HANDLER IMPLEMENTATION.


  method send_request_by_arrangement.

  endmethod.


  method send_request_by_url.
    data lo_http_destination type ref to if_http_destination.
    data lo_http_clien type ref to if_web_http_client.

    try.
*        lo_http_destination = cl_http_destination_provider=>create_by_url( i_url =  )
      catch cx_root into data(exc).
    endtry.
  endmethod.
ENDCLASS.
