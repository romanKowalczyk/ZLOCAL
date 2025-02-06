@EndUserText.label: 'Custom entity for products from ES5'
@ObjectModel.query.implementedBy: 'ABAP:YRAP_CE_CL_MP_PRODUCTS'
@Metadata.allowExtensions: true
define custom entity YRAP_CE_MP_PRODUCTS
{
  key Product : abap.char( 10 );
      ProductCategory : abap.char( 40 );
      Supplier : abap.char( 10 );  
}
