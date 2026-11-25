{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

/*
Selling a quantity-tracked Inventory item should relieve inventory at cost, as QuickBooks does
automatically (Dr Cost of Goods Sold / Cr Inventory Asset). Seed scenario:
  item 9601 "Widget": purchase_cost 6, unit_price 10, asset 96001, COGS 96002, income 96003
  bill 96101:    buy 10 @ 6  = 60
  invoice 96201: sell 3 @ 10 = 30
Expected (as in QuickBooks): COGS 18 Dr, Inventory Asset 42 Dr (60 - 18).
Returns a row for each account whose net debit differs.
*/

with expected as (

    select '96002' as account_id, 18 as expected_net_debit
    union all
    select '96001' as account_id, 42 as expected_net_debit
),

actual as (

    select
        account_id,
        sum(case when transaction_type = 'debit' then amount else -amount end) as actual_net_debit
    from {{ ref('quickbooks__general_ledger') }}
    where account_id in ('96001', '96002')
    group by 1
)

select
    expected.account_id,
    expected.expected_net_debit,
    coalesce(actual.actual_net_debit, 0) as actual_net_debit
from expected
left join actual
    on expected.account_id = actual.account_id
where abs(expected.expected_net_debit - coalesce(actual.actual_net_debit, 0)) > 0.01
