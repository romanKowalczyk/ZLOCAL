interface zif_csys_comm_handler
  public .
    methods send
    returning value(r_response) type ref to if_web_http_response
    raising cx_web_http_client_error.
endinterface.
