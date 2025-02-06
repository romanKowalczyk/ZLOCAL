@EndUserText.label: 'Custom entity for products from ES5'
@ObjectModel.query.implementedBy: 'ABAP:YRAP620_CL_CE_PRODUCTS_RK'
define custom entity yrap620_ce_products_rk
{
  key Product                 : abap.char( 10 );
      ProductCategory         : abap.char( 40 );
      Supplier                : abap.char( 10 );  
}
