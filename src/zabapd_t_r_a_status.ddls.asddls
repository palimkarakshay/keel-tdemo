@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Analytics - orders by status'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZABAPD_T_R_A_STATUS
  as select from zabapd_t_order as Ord
{
  key Ord.status        as Status,
  key Ord.currency_code as CurrencyCode,
      count( * )        as Orders,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( Ord.total_amount ) as Value
}
group by Ord.status, Ord.currency_code
