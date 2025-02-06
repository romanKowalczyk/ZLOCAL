@EndUserText.label: 'RAP620: Custom Entity Products from ES5'
@ObjectModel.query.implementedBy: 'ABAP:YCL_CE_MP_R620_PRODUCTS'
@Metadata.allowExtensions: true
define custom entity Y_CE_MP_R620_PRODUCTS 
{
  key Product : abap.char(10);
      ProductCategory: abap.char(40);
      Supplier: abap.char(10);  
}
