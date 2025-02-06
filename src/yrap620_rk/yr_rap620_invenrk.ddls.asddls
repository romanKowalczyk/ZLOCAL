@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection TEST BUG View for YRAP620_INVENRK'
define root view entity YR_RAP620_INVENRK
  as select from yrap620_invenrk
{
  key uuid as Uuid,
  inventory_id as InventoryId,
  @Consumption.valueHelpDefinition: [{ entity : {name: 'YRAP620_CE_PRODUCTS_RK', element: 'Product' } , useForValidation: true }]
  product_id as ProductId,
  @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
  quantity as Quantity,
  @Consumption.valueHelpDefinition: [ {
    entity.name: 'I_UnitOfMeasureStdVH', 
    entity.element: 'UnitOfMeasure', 
    useForValidation: true
  } ]
  quantity_unit as QuantityUnit,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  price as Price,
  @Consumption.valueHelpDefinition: [ {
    entity.name: 'I_CurrencyStdVH', 
    entity.element: 'Currency', 
    useForValidation: true
  } ]
  currency_code as CurrencyCode,
  description as Description,
  overall_status as OverallStatus,
  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  @Semantics.user.localInstanceLastChangedBy: true
  last_changed_by as LastChangedBy,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  last_changed_at as LastChangedAt,
  @Semantics.systemDateTime.lastChangedAt: true
  local_last_changed_at as LocalLastChangedAt
  
}
