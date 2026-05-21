/*=========================================================
    SPRINGBROOK LATEST SERVICE CODE QUERY
===========================================================
    Originally Written By: Teo Espero
    Original Base Code:   05/19/2026
    Revision Date:        05/21/2026

    PURPOSE:
    Pulls accounts with qualifying BILLING
    transactions, finds the latest matching
    service rate record, attaches service
    description and latest rate amount, and
    formats the output for reporting.

    SAMPLE FILTERS:

    @StartDate:
        '2025-07-01'

    @AccountNoFilter:
        '%'                          = all accounts
        '025138-000'                 = exact account
        '025138%,025139%'            = multiple series
        '025138-000,026000-000'      = multiple exact
        '%138%'                      = contains

    @ServiceCodeFilter:
        '%'                          = all service codes
        'SF01'                       = exact
        'SF%'                        = series
        'SB%,SW%,SF%'               = multiple series
        'SF01,SW01,SB01'            = multiple exact
        '%W%'                        = contains

    AREA LOGIC:
        Billing Cycle 1-4  = MARINA
        Billing Cycle 5-10 = ORD
        Else               = UNKNOWN

    RATE LOGIC:
        Latest rate amount comes from:
            ub_service_detail.minimum

        Latest version determined by:
            highest revision_no

    DATE FORMAT:
        MM/DD/YYYY

    NOTE:
        Leading wildcards work but are slower.
        SQL Server is powerful, not psychic.
