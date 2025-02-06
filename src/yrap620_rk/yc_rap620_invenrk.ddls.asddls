@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for Inventory'
@AccessControl.authorizationCheck: #CHECK
define root view entity YC_RAP620_INVENRK
  provider contract transactional_query
  as projection on YR_RAP620_INVENRK
//{
//  key Uuid,
//  InventoryId,
//  ProductId,
//  Quantity,
//  @Semantics.unitOfMeasure: true
//  QuantityUnit,
//  Price,
//  @Semantics.currencyCode: true
//  CurrencyCode,
//  Description,
//  OverallStatus,
//  CreatedBy,
//  CreatedAt,
//  LastChangedBy,
//  LastChangedAt,
//  LocalLastChangedAt
//  
//}
{
  key Uuid,
      InventoryId,
      ProductId,
      Quantity,
      @Consumption.valueHelpDefinition: [ {
      entity: {
        name: 'I_UnitOfMeasure',
        element: 'UnitOfMeasure'
      }
      } ]
      QuantityUnit,
      Price,
      @Consumption.valueHelpDefinition: [ {
      entity: {
        name: 'I_Currency',
        element: 'Currency'
      }
      } ]
      CurrencyCode,
      Description,
      OverallStatus,
      LastChangedAt
}
