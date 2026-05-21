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
=========================================================*/

DECLARE @StartDate DATE = '2025-07-01';

DECLARE @AccountNoFilter VARCHAR(200) = '%';

-- Shared filter used for BOTH:
-- 1. ub_bill_detail.service_code
-- 2. ub_service_rate.service_code
DECLARE @ServiceCodeFilter VARCHAR(200)
    = 'SB%, SW%, SF%';


/*=========================================================
    BILLING ACCOUNTS
===========================================================
    Finds accounts with BILLING transactions
    from selected start date through today.

    Service code filter comes from:
        @ServiceCodeFilter
=========================================================*/
WITH BilledAccounts AS (
    SELECT
        BD.cust_no,
        BD.cust_sequence,
        MAX(BD.tran_date)
            AS latest_transaction_date

    FROM [Springbrook0].[dbo].[ub_bill_detail] BD

    WHERE
        BD.tran_type = 'BILLING'

        AND BD.tran_date >= @StartDate

        AND BD.tran_date <
            DATEADD(
                DAY,
                1,
                CAST(GETDATE() AS DATE)
            )

        AND (
            @ServiceCodeFilter IS NULL
            OR @ServiceCodeFilter = '%'
            OR EXISTS (
                SELECT 1
                FROM STRING_SPLIT(
                    REPLACE(
                        @ServiceCodeFilter,
                        ' ',
                        ''
                    ),
                    ','
                ) F
                WHERE BD.service_code
                    LIKE F.value
            )
        )

    GROUP BY
        BD.cust_no,
        BD.cust_sequence
),

/*=========================================================
    LATEST SERVICE RATE
===========================================================
    Keeps latest service rate record
    per account using ROW_NUMBER().

    Service code filter comes from:
        @ServiceCodeFilter
=========================================================*/
LatestServiceRate AS (
    SELECT
        SR.ub_service_rate_id,
        SR.cust_no,
        SR.cust_sequence,
        SR.service_number,
        SR.service_code,

        SR.rate_connect_date,
        SR.rate_final_date,
        SR.last_bill_date,
        SR.last_date,
        SR.active,

        BA.latest_transaction_date,

        ROW_NUMBER() OVER (
            PARTITION BY
                SR.cust_no,
                SR.cust_sequence
            ORDER BY
                ISNULL(
                    SR.rate_connect_date,
                    '1900-01-01'
                ) DESC,

                ISNULL(
                    SR.last_bill_date,
                    '1900-01-01'
                ) DESC,

                ISNULL(
                    SR.last_date,
                    '1900-01-01'
                ) DESC,

                SR.ub_service_rate_id DESC
        ) AS rn

    FROM
        [Springbrook0].[dbo].[ub_service_rate] SR

    INNER JOIN
        BilledAccounts BA
            ON BA.cust_no =
                SR.cust_no
            AND BA.cust_sequence =
                SR.cust_sequence

    WHERE
        (
            @ServiceCodeFilter IS NULL
            OR @ServiceCodeFilter = '%'
            OR EXISTS (
                SELECT 1
                FROM STRING_SPLIT(
                    REPLACE(
                        @ServiceCodeFilter,
                        ' ',
                        ''
                    ),
                    ','
                ) F
                WHERE SR.service_code
                    LIKE F.value
            )
        )

        AND (
            SR.rate_final_date >=
                @StartDate
            OR SR.rate_final_date
                IS NULL
        )
),

/*=========================================================
    LATEST SERVICE DETAIL
===========================================================
    Gets latest rate amount from:
        ub_service_detail.minimum

    Latest version determined by:
        highest revision_no
=========================================================*/
LatestServiceDetail AS (
    SELECT
        USD.ub_service_id,
        USD.unit_size,

        USD.minimum
            AS latest_rate_amount,

        USD.effective_date,
        USD.revision_no,

        ROW_NUMBER() OVER (
            PARTITION BY
                USD.ub_service_id
            ORDER BY
                USD.revision_no DESC,

                ISNULL(
                    USD.effective_date,
                    '1900-01-01'
                ) DESC,

                USD.ub_service_detail_id DESC
        ) AS rn

    FROM
        [Springbrook0].[dbo].[ub_service_detail] USD
)


/*=========================================================
    FINAL RESULTS
=========================================================*/
SELECT
    CASE
        WHEN MAST.billing_cycle
            BETWEEN 1 AND 4
            THEN 'MARINA'

        WHEN MAST.billing_cycle
            BETWEEN 5 AND 10
            THEN 'ORD'

        ELSE 'UNKNOWN'
    END AS area,

    ACCT.formatted_account_no
        AS account_no,

    MAST.billing_cycle,

    L.lot_no,
    L.no_of_units,

    L.[description]
        AS lot_comments,

    SR.service_code,

    US.description
        AS service_rate_description,

    LSD.latest_rate_amount,

    LSD.revision_no
        AS latest_rate_revision_no,

    CONVERT(
        VARCHAR(10),
        LSD.effective_date,
        101
    ) AS latest_rate_effective_date,

    CONVERT(
        VARCHAR(10),
        MAST.connect_date,
        101
    ) AS connect_date,

    CONVERT(
        VARCHAR(10),
        MAST.final_date,
        101
    ) AS final_date,

    CONVERT(
        VARCHAR(10),
        SR.rate_connect_date,
        101
    ) AS rate_connect_date,

    CONVERT(
        VARCHAR(10),
        SR.rate_final_date,
        101
    ) AS rate_final_date,

    CONVERT(
        VARCHAR(10),
        SR.latest_transaction_date,
        101
    ) AS latest_transaction_date

FROM
    LatestServiceRate SR

INNER JOIN
    [Springbrook0].[dbo].[ub_master] MAST
        ON MAST.cust_no =
            SR.cust_no
        AND MAST.cust_sequence =
            SR.cust_sequence

INNER JOIN
    [Springbrook0].[dbo].[lot] L
        ON L.lot_no =
            MAST.lot_no

LEFT JOIN
    [Springbrook0].[dbo].[ub_service] US
        ON US.service_code =
            SR.service_code

LEFT JOIN
    LatestServiceDetail LSD
        ON LSD.ub_service_id =
            US.ub_service_id
        AND LSD.rn = 1

CROSS APPLY (
    SELECT
        RIGHT(
            '000000'
            + CAST(
                SR.cust_no
                AS VARCHAR(6)
            ),
            6
        )
        + '-'
        + RIGHT(
            '000'
            + CAST(
                SR.cust_sequence
                AS VARCHAR(3)
            ),
            3
        )
        AS formatted_account_no
) ACCT

WHERE
    -- Latest service rate only
    SR.rn = 1

    -- Account number filter
    AND (
        @AccountNoFilter IS NULL
        OR @AccountNoFilter = '%'
        OR EXISTS (
            SELECT 1
            FROM STRING_SPLIT(
                REPLACE(
                    @AccountNoFilter,
                    ' ',
                    ''
                ),
                ','
            ) F
            WHERE ACCT.formatted_account_no
                LIKE F.value
        )
    )

ORDER BY
    area,
    account_no;

/*=========================================================
    END OF QUERY

    Should unexpected results appear,
    first blame the data.

    Experience suggests this is often
    an excellent starting point.
=========================================================*/