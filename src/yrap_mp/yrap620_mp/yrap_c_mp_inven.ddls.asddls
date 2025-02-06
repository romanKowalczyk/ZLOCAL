@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
@AccessControl.authorizationCheck: #CHECK
define root view entity YRAP_C_MP_INVEN
  provider contract transactional_query
  as projection on YRAP_R_MP_INVEN
{
  key Uuid,
  InventoryId,
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
