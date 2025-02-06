@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
@AccessControl.authorizationCheck: #CHECK
define root view entity Y_C_MP_R620_INVT
  provider contract transactional_query
  as projection on Y_R_MP_R620_INVT
{
  key Uuid,
  InventoryId,
  @Consumption.valueHelpDefinition: [{
      entity: {
          name: 'Y_CE_MP_R620_PRODUCTS',
          element: 'Product'          
      },
      useForValidation: true
  }]
  ProductId,
  Quantity,
  @Semantics.unitOfMeasure: true
  QuantityUnit,
  Price,
  @Semantics.currencyCode: true
  CurrencyCode,
  Description,
  OverallStatus,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt
  
}
