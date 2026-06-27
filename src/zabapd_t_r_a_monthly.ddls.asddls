@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Analytics - monthly revenue'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZABAPD_T_R_A_MONTHLY
  as select from zabapd_t_order as Ord
{
  key Ord.order_date    as OrderDate,
  key Ord.currency_code as CurrencyCode,
      count( * )        as Orders,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( Ord.total_amount ) as Revenue
}
where Ord.status <> 'X'
group by Ord.order_date, Ord.currency_code
