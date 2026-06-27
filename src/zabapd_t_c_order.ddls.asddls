@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bookstore - order projection'
@Metadata.allowExtensions: true
define root view entity ZABAPD_T_C_ORDER
  provider contract transactional_query
  as projection on ZABAPD_T_R_ORDER
{
  key OrderUuid,
      OrderNo, CustomerUuid, CustomerName, OrderDate, Status, StatusCriticality,
      TotalAmount, CurrencyCode,
      CreatedBy, CreatedAt, LastChangedBy, LastChangedAt, LocalLastChangedAt,
      _Items : redirected to composition child ZABAPD_T_C_ORDERITEM
}
