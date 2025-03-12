CLASS yrap_r_mp_100_trav_gen_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    interfaces if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS YRAP_R_MP_100_TRAV_GEN_DATA IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    delete from yrap_a_mp_trav.
    data:
        attachment type /dmo/attachment,
        file_name type /dmo/filename,
        mime_type type /dmo/mime_type.

    insert yrap_a_mp_trav from (
        select from /dmo/travel as travel
               fields
               travel~travel_id as travel_id,
               travel~agency_id as agency_id,
               travel~customer_id as customer_id,
               travel~begin_date as begin_date,
               travel~end_date as end_date,
               travel~booking_fee as booking_fee,
               travel~total_price as total_price,
               travel~currency_code as currency_code,
               travel~description as description,
               case travel~status
                   when 'N' then 'O'
                   when 'P' then 'O'
                   when 'B' then 'A'
                   else 'X'
               end as overall_status,
               @attachment as attachment,
               @mime_type as mime_type,
               @file_name as file_name,
               travel~createdby as created_by,
               travel~createdat as created_at,
               travel~lastchangedby as local_last_changed_by,
               travel~lastchangedat as local_last_changed_at,
               travel~lastchangedat as last_changed_by
               order by travel_id up to 100 rows
    ).
    commit work.
    out->write( 'RAP 100 demo data generated for a table YRAP_A_MP_TRAV' ).
  ENDMETHOD.
ENDCLASS.
