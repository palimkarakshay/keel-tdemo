@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bookstore - review projection'
@Metadata.allowExtensions: true
define root view entity ZABAPD_T_C_REVIEW
  provider contract transactional_query
  as projection on ZABAPD_T_R_REVIEW
{
  key ReviewUuid,
      BookUuid, BookTitle, CustomerUuid, CustomerName, Rating, RatingCriticality, CommentText, ReviewDate,
      CreatedBy, CreatedAt, LastChangedBy, LastChangedAt, LocalLastChangedAt
}
