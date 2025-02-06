class yrap_ce_cl_mp_products definition
  public
  final
  create public .

  public section.
    types t_http_dest_seek type c length 1.
    constants:
      co_http_dest_seek_ca  type t_http_dest_seek value 'A',
      co_http_dest_seek_url type t_http_dest_seek value 'U'.

    types t_product_range type range of yrap_sc_products_mp=>tys_sepmra_i_product_etype.
    types t_business_data type yrap_sc_products_mp=>tyt_sepmra_i_product_etype.   " return type for Service Consumption Model
    types t_business_data_ext type table of yrap_ce_mp_products with key Product.  " return type for Client Response of Custom Entity

    methods get_products
      importing
        it_filter_cond   type if_rap_query_filter=>tt_name_range_pairs   optional
        top              type i optional
        skip             type i optional
      exporting
        et_business_data type  t_business_data
      raising
        /iwbep/cx_cp_remote
        /iwbep/cx_gateway
        cx_web_http_client_error
        cx_http_dest_provider_error
      .
    interfaces if_oo_adt_classrun .
    interfaces if_rap_query_provider.
  protected section.
  private section.
    methods provide_http_destination
      importing i_http_dest_seek type t_http_dest_seek
      returning value(r_http_destination) type ref to if_http_destination
      RAISING
        cx_http_dest_provider_error.
endclass.


class yrap_ce_cl_mp_products implementation.
  method if_oo_adt_classrun~main.
    data business_data type t_business_data.
    data filter_conditions type if_rap_query_filter=>tt_name_range_pairs.
    data ranges_table type if_rap_query_filter=>tt_range_option.
    ranges_table = value #( ( sign = 'I' option = 'GE' low = 'HT-1200' ) ).
    filter_conditions = value #( ( name = 'PRODUCT' range = ranges_table ) ).

    try.
        get_products(
          exporting
            it_filter_cond   = filter_conditions
            top              = 3
            skip             = 1
          importing
            et_business_data = business_data
        ).
        out->write( business_data ).
      catch cx_root into data(exc).
        out->write( cl_message_helper=>get_latest_t100_exception( exc )->if_message~get_longtext( ) ).
    endtry.
  endmethod.

  method get_products.
    data:
      filter_factory   type ref to /iwbep/if_cp_filter_factory,
      filter_node      type ref to /iwbep/if_cp_filter_node,
      root_filter_node type ref to /iwbep/if_cp_filter_node.

    data:
      ls_business_data   type yrap_sc_products_mp=>tys_sepmra_i_product_etype,
      http_client        type ref to if_web_http_client,
      odata_client_proxy type ref to /iwbep/if_cp_client_proxy,
      create_request     type ref to /iwbep/if_cp_request_create,
      read_list_request  type ref to /iwbep/if_cp_request_read_list,
      read_list_response type ref to /iwbep/if_cp_response_read_lst.

*    try.
        data(http_destination) = provide_http_destination( co_http_dest_seek_ca ).
        http_client = cl_web_http_client_manager=>create_by_http_destination( http_destination ).

        odata_client_proxy = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
          exporting
             is_proxy_model_key       = value #( repository_id       = 'DEFAULT'
                                                 proxy_model_id      = 'YRAP620_SC_PRODUCTS_MP'
                                                 proxy_model_version = '0001' )
            io_http_client             = http_client
            iv_relative_service_root   = '/sap/opu/odata/sap/ZPDCDS_SRV/' ).

        assert http_client is bound.

* Prepare business data
        ls_business_data = value #(
                  product                  = 'Product'
                  product_type             = 'ProductType'
                  product_category         = 'ProductCategory'
                  created_by_user          = 'CreatedByUser'
                  creation_date_time       = 20170101123000
                  last_changed_by_user     = 'LastChangedByUser'
                  last_changed_date_time   = 20170101123000
                  price                    = '1'
                  currency                 = 'Currency'
                  height                   = '1'
                  width                    = '1'
                  depth                    = '1'
                  dimension_unit           = 'DimensionUnit'
                  product_picture_url      = 'ProductPictureUrl'
                  product_value_added_tax  = 10
                  supplier                 = 'Supplier'
                  product_base_unit        = 'ProductBaseUnit'
                  weight                   = '1'
                  weight_unit              = 'WeightUnit'
                  original_language        = 'OriginalLanguage' ).

        " Navigate to the resource and create a request for the create operation
        read_list_request = odata_client_proxy->create_resource_for_entity_set( 'SEPMRA_I_PRODUCT_E' )->create_request_for_read( ).

        " create the filter tree
        filter_factory = read_list_request->create_filter_factory( ).

        loop at it_filter_cond into data(filter_condition).
          filter_node = filter_factory->create_by_range(
               iv_property_path     =  filter_condition-name
               it_range             =  filter_condition-range
          ).
          if root_filter_node is initial.
            root_filter_node = filter_node.
          else.
            root_filter_node = root_filter_node->and( filter_node ).
          endif.
        endloop.

        " Set the business data for the created entity
*        create_request->set_business_data( ls_business_data ).

        if root_filter_node is not initial.
          read_list_request->set_filter( root_filter_node ).
        endif.
        if top > 0.
          read_list_request->set_top( top ).
        endif.
        read_list_request->set_skip( skip ).


        " Execute the request and retrieve the business data
        read_list_response = read_list_request->execute( ).
        read_list_response->get_business_data( importing et_business_data = et_business_data ).

*      catch /iwbep/cx_cp_remote into data(lx_remote).
*        " Handle remote Exception
*        " It contains details about the problems of your http(s) connection
*      catch /iwbep/cx_gateway into data(lx_gateway).
*        " Handle Exception
*      catch cx_http_dest_provider_error into data(lx_dest_error).
*
*      catch cx_web_http_client_error into data(lx_web_http_client_error).
*        " Handle Exception
*        raise shortdump lx_web_http_client_error.
*    endtry.
  endmethod.

  method provide_http_destination.
    case i_http_dest_seek.
      when co_http_dest_seek_ca.
        "find destination via Communication Arragement
        data(ca_factory) = cl_com_arrangement_factory=>create_instance( ).
        data(cscn_id_range) = value if_com_scenario_factory=>ty_query-cscn_id_range(
            ( sign = 'I' option = 'EQ' low = 'Z_API_ES5_CSCN')
        ).
        ca_factory->query_ca(
          exporting
            is_query           = value #( cscn_id_range = cscn_id_range )
          importing
            et_com_arrangement = data(cas)
        ).
        read table cas into data(ca) index 1.

        r_http_destination = cl_http_destination_provider=>create_by_comm_arrangement(
               comm_scenario  = 'Z_API_ES5_CSCN'
               service_id     = 'Z_ES5_OUTB_REST'
               comm_system_id = ca->get_comm_system_id( )
        ).
      when co_http_dest_seek_url.
        r_http_destination = cl_http_destination_provider=>create_by_url( i_url = 'https://sapes5.sapdevcenter.com' ).
    endcase.
  endmethod.

  method if_rap_query_provider~select.
    data business_data type t_business_data.
    data business_data_ext type t_business_data_ext.
    data(sorting) = io_request->get_sort_elements( ).

    try.
        get_products(
          exporting
            it_filter_cond   = io_request->get_filter( )->get_as_ranges( )
            top              = io_request->get_paging( )->get_page_size( )
            skip             = io_request->get_paging( )->get_offset( )
          importing
            et_business_data = business_data
        ).
        data(sort_keys) = corresponding abap_sortorder_tab( sorting mapping name = element_name descending = descending ).
        sort business_data by (sort_keys).


        business_data_ext =
            corresponding t_business_data_ext( business_data
                  mapping Product = product
                          ProductCategory = product_category
                          Supplier = supplier
        ).
        io_response->set_data( business_data_ext ).
        io_response->set_total_number_of_records( lines( business_data_ext ) ).
      catch cx_root into data(exc).
        data(exc_mess) = cl_message_helper=>get_latest_t100_exception( exc )->if_message~get_longtext( ).
        data(exc_t100key) = cl_message_helper=>get_latest_t100_exception( exc )->t100key.
        raise exception type ycx_rap_query_provider
          exporting
            textid  = exc_t100key
*            previous = exc
        .
     endtry.
  endmethod.

endclass.
