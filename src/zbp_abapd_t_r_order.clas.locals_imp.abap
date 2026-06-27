CLASS lhc_order DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF st,
        new      TYPE c LENGTH 2 VALUE 'N',
        paid     TYPE c LENGTH 2 VALUE 'P',
        picking  TYPE c LENGTH 2 VALUE 'K',
        shipped  TYPE c LENGTH 2 VALUE 'S',
        delivered TYPE c LENGTH 2 VALUE 'D',
        cancelled TYPE c LENGTH 2 VALUE 'X',
      END OF st.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Order RESULT result.
    METHODS setOrderDefaults FOR DETERMINE ON MODIFY IMPORTING keys FOR Order~setOrderDefaults.
    METHODS calcTotal FOR DETERMINE ON MODIFY IMPORTING keys FOR Order~calcTotal.
    METHODS validateItems FOR VALIDATE ON SAVE IMPORTING keys FOR Order~validateItems.
    METHODS pay FOR MODIFY IMPORTING keys FOR ACTION Order~pay RESULT result.
    METHODS ship FOR MODIFY IMPORTING keys FOR ACTION Order~ship RESULT result.
    METHODS deliver FOR MODIFY IMPORTING keys FOR ACTION Order~deliver RESULT result.
    METHODS cancel FOR MODIFY IMPORTING keys FOR ACTION Order~cancel RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Order RESULT result.
ENDCLASS.

CLASS lhc_order IMPLEMENTATION.
  METHOD get_global_authorizations.
    " Demo grants globally (empty handler = unrestricted). PRODUCTION hardening:
    "  - DCL access control (.dcls) with #CHECK (not #NOT_REQUIRED) bound to a PFCG authorization object,
    "  - and/or AUTHORITY-CHECK here against a custom SU21 object, setting result-%update / result-%delete / result-%action-...
  ENDMETHOD.

  METHOD setOrderDefaults.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order FIELDS ( OrderNo Status OrderDate CurrencyCode )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_order.
    LOOP AT orders INTO DATA(o).
      APPEND VALUE #( %tky = o-%tky
                      OrderNo      = COND #( WHEN o-OrderNo IS INITIAL THEN |SO{ sy-uzeit }| ELSE o-OrderNo )
                      Status       = COND #( WHEN o-Status IS INITIAL THEN st-new ELSE o-Status )
                      OrderDate    = COND #( WHEN o-OrderDate IS INITIAL THEN cl_abap_context_info=>get_system_date( ) ELSE o-OrderDate )
                      CurrencyCode = COND #( WHEN o-CurrencyCode IS INITIAL THEN 'USD' ELSE o-CurrencyCode )
                    ) TO upd.
    ENDLOOP.
    CHECK upd IS NOT INITIAL.
    MODIFY ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order UPDATE FIELDS ( OrderNo Status OrderDate CurrencyCode ) WITH upd.
  ENDMETHOD.

  METHOD calcTotal.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order BY \_Items ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(items).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_order.
    DATA total TYPE p LENGTH 8 DECIMALS 2.
    LOOP AT keys INTO DATA(k).
      CLEAR total.
      LOOP AT items INTO DATA(it) WHERE OrderUuid = k-OrderUuid.
        total = total + it-LineAmount.
      ENDLOOP.
      APPEND VALUE #( %tky = k-%tky TotalAmount = total ) TO upd.
    ENDLOOP.
    CHECK upd IS NOT INITIAL.
    MODIFY ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order UPDATE FIELDS ( TotalAmount ) WITH upd.
  ENDMETHOD.

  METHOD validateItems.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order BY \_Items ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(items).
    LOOP AT keys INTO DATA(k).
      APPEND VALUE #( %tky = k-%tky %state_area = 'VALIDATE_ITEMS' ) TO reported-order.
      IF NOT line_exists( items[ OrderUuid = k-OrderUuid ] ).
        APPEND VALUE #( %tky = k-%tky ) TO failed-order.
        APPEND VALUE #( %tky = k-%tky %state_area = 'VALIDATE_ITEMS'
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'An order needs at least one item' ) ) TO reported-order.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD pay.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(cur).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_order.
    LOOP AT cur INTO DATA(o).
      IF o-Status = st-new.
        APPEND VALUE #( %tky = o-%tky Status = st-paid ) TO upd.
      ELSE.
        APPEND VALUE #( %tky = o-%tky ) TO failed-order.
        APPEND VALUE #( %tky = o-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Pay is allowed only for a New order' ) ) TO reported-order.
      ENDIF.
    ENDLOOP.
    MODIFY ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order UPDATE FIELDS ( Status ) WITH upd.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    result = VALUE #( FOR r IN orders ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ship.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(cur).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_order.
    LOOP AT cur INTO DATA(o).
      IF o-Status = st-paid OR o-Status = st-picking.
        APPEND VALUE #( %tky = o-%tky Status = st-shipped ) TO upd.
      ELSE.
        APPEND VALUE #( %tky = o-%tky ) TO failed-order.
        APPEND VALUE #( %tky = o-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Ship is allowed only for a Paid order' ) ) TO reported-order.
      ENDIF.
    ENDLOOP.
    MODIFY ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order UPDATE FIELDS ( Status ) WITH upd.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    result = VALUE #( FOR r IN orders ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD deliver.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(cur).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_order.
    LOOP AT cur INTO DATA(o).
      IF o-Status = st-shipped.
        APPEND VALUE #( %tky = o-%tky Status = st-delivered ) TO upd.
      ELSE.
        APPEND VALUE #( %tky = o-%tky ) TO failed-order.
        APPEND VALUE #( %tky = o-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Deliver is allowed only for a Shipped order' ) ) TO reported-order.
      ENDIF.
    ENDLOOP.
    MODIFY ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order UPDATE FIELDS ( Status ) WITH upd.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    result = VALUE #( FOR r IN orders ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD cancel.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(cur).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_order.
    LOOP AT cur INTO DATA(o).
      IF o-Status <> st-shipped AND o-Status <> st-delivered AND o-Status <> st-cancelled.
        APPEND VALUE #( %tky = o-%tky Status = st-cancelled ) TO upd.
      ELSE.
        APPEND VALUE #( %tky = o-%tky ) TO failed-order.
        APPEND VALUE #( %tky = o-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'This order can no longer be cancelled' ) ) TO reported-order.
      ENDIF.
    ENDLOOP.
    MODIFY ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order UPDATE FIELDS ( Status ) WITH upd.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    result = VALUE #( FOR r IN orders ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY Order FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    result = VALUE #( FOR o IN orders
      ( %tky = o-%tky
        %action-pay     = COND #( WHEN o-Status = st-new                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-ship    = COND #( WHEN o-Status = st-paid OR o-Status = st-picking THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-deliver = COND #( WHEN o-Status = st-shipped                      THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-cancel  = COND #( WHEN o-Status = st-shipped OR o-Status = st-delivered OR o-Status = st-cancelled THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
      ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lhc_orderitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS calcLineAmount FOR DETERMINE ON MODIFY IMPORTING keys FOR OrderItem~calcLineAmount.
ENDCLASS.

CLASS lhc_orderitem IMPLEMENTATION.
  METHOD calcLineAmount.
    READ ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY OrderItem FIELDS ( Quantity UnitPrice ) WITH CORRESPONDING #( keys ) RESULT DATA(items).
    DATA upd TYPE TABLE FOR UPDATE zabapd_t_r_orderitem.
    LOOP AT items INTO DATA(it).
      APPEND VALUE #( %tky = it-%tky LineAmount = it-Quantity * it-UnitPrice ) TO upd.
    ENDLOOP.
    CHECK upd IS NOT INITIAL.
    MODIFY ENTITIES OF zabapd_t_r_order IN LOCAL MODE
      ENTITY OrderItem UPDATE FIELDS ( LineAmount ) WITH upd.
  ENDMETHOD.
ENDCLASS.
