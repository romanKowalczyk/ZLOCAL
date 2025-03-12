class ycl_scope_page_space_lhu definition
public
final
create public .

  public section.
    interfaces if_oo_adt_classrun.
  protected section.
  private section.
ENDCLASS.



CLASS YCL_SCOPE_PAGE_SPACE_LHU IMPLEMENTATION.


  method if_oo_adt_classrun~main.


    data(lo_scope_api) = cl_aps_bc_scope_change_api=>create_instance( ).

    lo_scope_api->scope(
      exporting
        it_object_scope  = value #(
            pgmid       = if_aps_bc_scope_change_api=>gc_tadir_pgmid-r3tr
            scope_state = if_aps_bc_scope_change_api=>gc_scope_state-on
*           Space template
            ( object = if_aps_bc_scope_change_api=>gc_tadir_object-UIST obj_name = 'YRAP100_TRAVEL_LHU' )
*           Page template
            ( object = if_aps_bc_scope_change_api=>gc_tadir_object-uipg obj_name = 'YRAP100_TRAVEL_LHU' )
        )
        iv_simulate      = abap_false
        iv_force         = abap_false
      importing
        et_object_result = data(lt_results)
        et_message       = data(lt_messages) ).
  endmethod.
ENDCLASS.
