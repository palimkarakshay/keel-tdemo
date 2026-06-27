CLASS lhc_customer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Customer RESULT result.
    METHODS setCustomerNo FOR DETERMINE ON SAVE
      IMPORTING keys FOR Customer~setCustomerNo.
    METHODS validateEmail FOR VALIDATE ON SAVE
      IMPORTING keys FOR Customer~validateEmail.
ENDCLASS.

CLASS lhc_customer IMPLEMENTATION.
  METHOD get_global_authorizations.
    " Demo grants globally (empty handler = unrestricted). PRODUCTION hardening:
    "  - DCL access control (.dcls) with #CHECK (not #NOT_REQUIRED) bound to a PFCG authorization object,
    "  - and/or AUTHORITY-CHECK here against a custom SU21 object, setting result-%update / result-%delete / result-%action-...
  ENDMETHOD.

  METHOD setCustomerNo.
    READ ENTITIES OF zabapd_t_r_customer IN LOCAL MODE
      ENTITY Customer FIELDS ( CustomerNo ) WITH CORRESPONDING #( keys ) RESULT DATA(customers).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_customer.
    LOOP AT customers INTO DATA(cust) WHERE CustomerNo IS INITIAL.
      DATA(seq) = cl_abap_random_int=>create( seed = CONV i( sy-uzeit ) min = 100000 max = 999999 )->get_next( ).
      APPEND VALUE #( %tky = cust-%tky CustomerNo = |C{ seq }| ) TO upd.
    ENDLOOP.
    CHECK upd IS NOT INITIAL.
    MODIFY ENTITIES OF zabapd_t_r_customer IN LOCAL MODE
      ENTITY Customer UPDATE FIELDS ( CustomerNo ) WITH upd.
  ENDMETHOD.

  METHOD validateEmail.
    READ ENTITIES OF zabapd_t_r_customer IN LOCAL MODE
      ENTITY Customer FIELDS ( Email ) WITH CORRESPONDING #( keys ) RESULT DATA(customers).
    LOOP AT customers INTO DATA(cust).
      APPEND VALUE #( %tky = cust-%tky %state_area = 'VALIDATE_EMAIL' ) TO reported-customer.
      IF cust-Email IS INITIAL OR cust-Email NS '@'.
        APPEND VALUE #( %tky = cust-%tky ) TO failed-customer.
        APPEND VALUE #( %tky = cust-%tky
                        %state_area = 'VALIDATE_EMAIL'
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'A valid e-mail is required' )
                        %element-Email = if_abap_behv=>mk-on ) TO reported-customer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
