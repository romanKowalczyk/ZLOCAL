CLASS yrap620_cl_ce_products_rk DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES t_product_range TYPE RANGE OF yrap_sc_products_mp=>tys_sepmra_i_product_etype.
    TYPES t_business_data TYPE yrap_sc_products_mp=>tyt_sepmra_i_product_etype.   " return type for Service Consumption Model
    TYPES t_business_data_ext TYPE TABLE OF yrap_ce_mp_products WITH KEY Product.  " return type for Client Response of Custom Entity

    METHODS get_products
      IMPORTING
        it_filter_cond   TYPE if_rap_query_filter=>tt_name_range_pairs   OPTIONAL
        top              TYPE i OPTIONAL
        skip             TYPE i OPTIONAL
      EXPORTING
        et_business_data TYPE  t_business_data
      RAISING
        /iwbep/cx_cp_remote
        /iwbep/cx_gateway
        cx_web_http_client_error
        cx_http_dest_provider_error
      .
    INTERFACES if_oo_adt_classrun .
    INTERFACES if_rap_query_provider.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS yrap620_cl_ce_products_rk IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA business_data TYPE t_business_data.
    DATA filter_conditions TYPE if_rap_query_filter=>tt_name_range_pairs.
    DATA ranges_table TYPE if_rap_query_filter=>tt_range_option.
    ranges_table = VALUE #( ( sign = 'I' option = 'GE' low = 'HT-1200' ) ).
    filter_conditions = VALUE #( ( name = 'PRODUCT' range = ranges_table ) ).

    TRY.
        get_products(
          EXPORTING
            it_filter_cond   = filter_conditions
            top              = 3
            skip             = 1
          IMPORTING
            et_business_data = business_data
        ).
        out->write( business_data ).
      CATCH cx_root INTO DATA(exc).
        out->write( cl_message_helper=>get_latest_t100_exception( exc )->if_message~get_longtext( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_products.
    DATA:
      filter_factory   TYPE REF TO /iwbep/if_cp_filter_factory,
      filter_node      TYPE REF TO /iwbep/if_cp_filter_node,
      root_filter_node TYPE REF TO /iwbep/if_cp_filter_node.

    DATA:
      ls_business_data   TYPE yrap_sc_products_mp=>tys_sepmra_i_product_etype,
      http_client        TYPE REF TO if_web_http_client,
      odata_client_proxy TYPE REF TO /iwbep/if_cp_client_proxy,
      create_request     TYPE REF TO /iwbep/if_cp_request_create,
      read_list_request  TYPE REF TO /iwbep/if_cp_request_read_list,
      read_list_response TYPE REF TO /iwbep/if_cp_response_read_lst.

    TRY.
        " Create http client
*DATA(http_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
*                                             comm_scenario  = '<Comm Scenario>'
*                                             comm_system_id = '<Comm System Id>'
*                                             service_id     = '<Service Id>' ).
        DATA(http_destination) = cl_http_destination_provider=>create_by_url( i_url = 'https://sapes5.sapdevcenter.com' ).
        http_client = cl_web_http_client_manager=>create_by_http_destination( http_destination ).

        odata_client_proxy = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
          EXPORTING
             is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                 proxy_model_id      = 'YRAP620_SC_PRODUCTS_MP'
                                                 proxy_model_version = '0001' )
            io_http_client             = http_client
            iv_relative_service_root   = '/sap/opu/odata/sap/ZPDCDS_SRV/' ).

        ASSERT http_client IS BOUND.

* Prepare business data
        ls_business_data = VALUE #(
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

        LOOP AT it_filter_cond INTO DATA(filter_condition).
          filter_node = filter_factory->create_by_range(
               iv_property_path     =  filter_condition-name
               it_range             =  filter_condition-range
          ).
          IF root_filter_node IS INITIAL.
            root_filter_node = filter_node.
          ELSE.
            root_filter_node = root_filter_node->and( filter_node ).
          ENDIF.
        ENDLOOP.

        " Set the business data for the created entity
*        create_request->set_business_data( ls_business_data ).

        IF root_filter_node IS NOT INITIAL.
          read_list_request->set_filter( root_filter_node ).
        ENDIF.
        IF top > 0.
          read_list_request->set_top( top ).
        ENDIF.
        read_list_request->set_skip( skip ).


        " Execute the request and retrieve the business data
        read_list_response = read_list_request->execute( ).
        read_list_response->get_business_data( IMPORTING et_business_data = et_business_data ).

      catch /iwbep/cx_cp_remote into data(lx_remote).
        " Handle remote Exception
        " It contains details about the problems of your http(s) connection
      catch /iwbep/cx_gateway into data(lx_gateway).
        " Handle Exception
      catch cx_web_http_client_error into data(lx_web_http_client_error).
        " Handle Exception
        raise shortdump lx_web_http_client_error.
    ENDTRY.
  ENDMETHOD.

  METHOD if_rap_query_provider~select.
    DATA business_data TYPE t_business_data.
    DATA business_data_ext TYPE t_business_data_ext.
    DATA(sorting) = io_request->get_sort_elements( ).

    TRY.
        get_products(
          EXPORTING
            it_filter_cond   = io_request->get_filter( )->get_as_ranges( )
            top              = io_request->get_paging( )->get_page_size( )
            skip             = io_request->get_paging( )->get_offset( )
          IMPORTING
            et_business_data = business_data
        ).
        DATA(sort_keys) = CORRESPONDING abap_sortorder_tab( sorting MAPPING name = element_name descending = descending ).
        SORT business_data BY (sort_keys).


        business_data_ext =
            CORRESPONDING t_business_data_ext( business_data
                  MAPPING Product = product
                          ProductCategory = product_category
                          Supplier = supplier
        ).
        io_response->set_data( business_data_ext ).
        io_response->set_total_number_of_records( lines( business_data_ext ) ).
      CATCH cx_root INTO DATA(exc).
        DATA(exc_mess) = cl_message_helper=>get_latest_t100_exception( exc )->if_message~get_longtext( ).
*        raise exception type cx_rap_query_provider exporting textid = exc->textid.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
