-- Duplicate order validation
select order_id,
count(*) as total_orders
from ecommerce_shipping_delivery_performance
group by order_id
having count(*) > 1;

select order_date,warehouse_location,destination_city,destination_pincode,carrier,product_category,product_weight_kg,dispatch_date,promised_delivery_date,
count(*) as total_orders
from ecommerce_shipping_delivery_performance
group by order_date,warehouse_location,destination_city,destination_pincode,carrier,product_category,product_weight_kg,dispatch_date,promised_delivery_date
having count(*) > 1;

-- NULL identification
select
sum(order_id IS null) as null_order_id,
sum(order_date is null) as null_order_date,
sum(warehouse_location is null) as null_warehouse_location,
sum(destination_city is null) as null_destination_city,
sum(destination_pincode is null) as null_destination_pincode,
sum(carrier is null) as null_carrier,
sum(product_category is null) as null_product_category,
sum(product_weight_kg is null) as null_product_weight_kg,
sum(dispatch_date is null) as null_dispatch_date,
sum(promised_delivery_date is null) as null_promised_delivery_date,
sum(actual_delivery_date is null) as null_actual_delivery_date,
sum(delivery_status is null) as null_delivery_status,
sum(delivery_attempts is null) as null_delivery_attempts,
sum(route_distance_km is null ) as null_route_distance_km,
sum(shipping_cost_inr is null) as null_shipping_cost_inr
from ecommerce_shipping_delivery_performance;

-- Date format and range validation
select
min(order_date) as min_order , max(order_date) as max_order,
min(dispatch_date) as min_dispatch_date , max(dispatch_date) as max_dispatch_date,
min(promised_delivery_date) as min_promised_date , max(promised_delivery_date) as max_promised_date,
min(actual_delivery_date) as min_actual_date, max(actual_delivery_date) as max_actual_date
from ecommerce_shipping_delivery_performance;

-- Orders outside the expected year
select 
count(*) as order_outside_2025
from ecommerce_shipping_delivery_performance
where year(order_date) <> 2025;

-- Numeric range validation
SELECT MIN(product_weight_kg) AS min_wt, MAX(product_weight_kg) AS max_wt,
       MIN(route_distance_km) AS min_km, MAX(route_distance_km) AS max_km,
       MIN(shipping_cost_inr) AS min_cost, MAX(shipping_cost_inr) AS max_cost,
       MIN(delivery_attempts) AS min_att, MAX(delivery_attempts) AS max_att
FROM ecommerce_shipping_delivery_performance;

SELECT COUNT(*) AS invalid_rows
FROM ecommerce_shipping_delivery_performance
WHERE product_weight_kg <= 0 OR route_distance_km <= 0
   OR shipping_cost_inr <= 0 OR delivery_attempts NOT BETWEEN 0 AND 3;

-- Is heavy weight plausible per category?
SELECT product_category, MIN(product_weight_kg) AS min_kg,
       MAX(product_weight_kg) AS max_kg, COUNT(*) AS orders
FROM ecommerce_shipping_delivery_performance GROUP BY product_category ORDER BY max_kg DESC;

-- Status vs attempts
SELECT delivery_status, delivery_attempts, COUNT(*) AS orders
FROM ecommerce_shipping_delivery_performance
GROUP BY delivery_status, delivery_attempts
ORDER BY delivery_status, delivery_attempts;

-- Order date vs dispatch date
select 
count(*) as dispatch_before_order
from ecommerce_shipping_delivery_performance 
where dispatch_date < order_date;

SELECT DATEDIFF(dispatch_date, order_date) AS dispatch_days, COUNT(*) AS orders
FROM ecommerce_shipping_delivery_performance
GROUP BY DATEDIFF(dispatch_date, order_date)
ORDER BY dispatch_days;

-- Dispatch date vs delivery date
select
datediff(actual_delivery_date,dispatch_date) as transit_days,
count(*) as orders
from ecommerce_shipping_delivery_performance
where actual_delivery_date is not null
group by datediff(actual_delivery_date,dispatch_date)
order by transit_days ;

-- Actual vs promised delivery
SELECT CASE
         WHEN actual_delivery_date IS NULL THEN 'Not delivered (excluded)'
         WHEN actual_delivery_date < promised_delivery_date THEN 'Early'
         WHEN actual_delivery_date = promised_delivery_date THEN 'On time'
         ELSE 'Late'
       END AS delivery_vs_promise,
       COUNT(*) AS orders
FROM ecommerce_shipping_delivery_performance
GROUP BY delivery_vs_promise;

-- Promise made before dispatch? (impossible SLA)
SELECT COUNT(*) AS promise_before_dispatch FROM ecommerce_shipping_delivery_performance WHERE promised_delivery_date < dispatch_date;

-- How late are the late ones?
SELECT DATEDIFF(actual_delivery_date, promised_delivery_date) AS delay_days, COUNT(*) AS orders
FROM ecommerce_shipping_delivery_performance WHERE actual_delivery_date > promised_delivery_date
GROUP BY delay_days ORDER BY delay_days;

-- total orders
SELECT COUNT(*) AS total_orders FROM ecommerce_shipping_delivery_performance;

SELECT delivery_status, COUNT(*) AS orders,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM ecommerce_shipping_delivery_performance), 2) AS pct_of_orders
FROM ecommerce_shipping_delivery_performance GROUP BY delivery_status ORDER BY orders DESC;

-- On-time delivery
SELECT
    COUNT(*) AS Total_Delivered_Orders,

    SUM(CASE
        WHEN actual_delivery_date <= promised_delivery_date
        THEN 1 ELSE 0
    END) AS On_Time_Deliveries,
	CAST(
        100.0 * SUM(CASE
            WHEN actual_delivery_date <= promised_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS On_Time_Delivery_Percentage
FROM ecommerce_shipping_delivery_performance
WHERE delivery_status = 'Delivered';

-- Average Delivery Time
SELECT
    AVG(
        CAST(
            DATEDIFF(
                actual_delivery_date,
                dispatch_date
            ) AS DECIMAL(10,2)
        )
    ) AS Average_Delivery_Time_Days
FROM ecommerce_shipping_delivery_performance
WHERE delivery_status = 'Delivered'
  AND dispatch_date IS NOT NULL
  AND actual_delivery_date IS NOT NULL;
  
  -- Late Delivery %
  SELECT
    COUNT(*) AS Total_Delivered_Orders,

    SUM(CASE
        WHEN actual_delivery_date > promised_delivery_date
        THEN 1 ELSE 0
    END) AS Late_Deliveries,

    CAST(
        100.0 * SUM(CASE
            WHEN actual_delivery_date > promised_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Late_Delivery_Percentage
FROM ecommerce_shipping_delivery_performance
WHERE delivery_status = 'Delivered';

/* Business Questions */
-- Which pincodes have the highest late delivery rate?
select 
destination_pincode, destination_city,
count(*) as Total_orders,
sum(case when actual_delivery_date > promised_delivery_date
			then 1 else 0 end) as late_delivery,
Round(
	100.0 * sum(case when actual_delivery_date > promised_delivery_date
			then 1 else 0 end)/count(*),2) as late_delivery_rate
from ecommerce_shipping_delivery_performance
group by destination_pincode, destination_city
order by late_delivery_rate desc;

-- Which carrier has the best on-time delivery rate?
select carrier,
count(*) as toal_orders,
sum(case when actual_delivery_date <= promised_delivery_date 
			then 1 else 0 end) as Ontime_delivery,
round(
	100.0 * sum(case when actual_delivery_date <= promised_delivery_date 
			then 1 else 0 end) / count(*) ,2) as ontime_delivery_rate
from ecommerce_shipping_delivery_performance
where delivery_status = 'Delivered'
group by carrier
order by ontime_delivery_rate desc;

-- Which product category experiences the most delays? group by, case, avg
select product_category,
count(*) as total_product,
round(
	avg(
		datediff(actual_delivery_date,promised_delivery_date)
        ),2
        ) as avg_delivery_delays
from ecommerce_shipping_delivery_performance
where delivery_status = 'Delivered'
AND actual_delivery_date > promised_delivery_date
group by product_category;

-- Does product weight affect delivery time? case, avg, group by
select *
from ecommerce_shipping_delivery_performance;
select
case 
	when product_weight_kg <= 2 
    then 'lightweight' 
    when product_weight_kg <= 5
    then 'medium'
    when product_weight_kg <= 15
    then 'heavy'
    else 'Extra heavy'
    end as weight_category,
    count(*) as total_orders,
    round(
		avg(
        datediff(actual_delivery_date,dispatch_date)
        ),2
        ) as avg_delivery_delay
	from ecommerce_shipping_delivery_performance
	where delivery_status = 'Delivered'
    group by 
    case
    when product_weight_kg <= 2 
    then 'lightweight' 
    when product_weight_kg <= 5
    then 'medium'
    when product_weight_kg <= 15
    then 'heavy'
    else 'Extra heavy'
    end 
    order by avg_delivery_delay desc;
    
-- Which warehouse has the highest average dispatch time? GROUP BY, AVG, DATEDIFF, JOIN
select warehouse_location,
count(*) as total_orders,
round(
avg(
	datediff(dispatch_date, order_date)
    ),2
    ) as avg_dispatch_days
from ecommerce_shipping_delivery_performance
group by warehouse_location
order by avg_dispatch_days desc;

-- Which routes have consistently late deliveries? GROUP BY, HAVING, CASE, Aggregation
select warehouse_location,
destination_city,
destination_pincode,
count(*) as total_deliveries,
sum(case when actual_delivery_date > promised_delivery_date 
			then 1 else 0 end) as late_orders,
round (
	100.0 * sum(case when actual_delivery_date > promised_delivery_date 
			then 1 else 0 end) / count(*) ,2
            ) as late_delivery_rate
from ecommerce_shipping_delivery_performance
where delivery_status = 'Delivered'
group by warehouse_location,
destination_city,
destination_pincode 
having count(*) >= 10
order by late_delivery_rate DESC;

-- What is the average delivery time by city? AVG, GROUP BY, DATEDIFF
select destination_city,
count(*) as total_deliveries,
round(
avg(
datediff(actual_delivery_date, promised_delivery_date)
),2
) as avg_delivery_delays
from ecommerce_shipping_delivery_performance
where delivery_status = 'Delivered'
group by destination_city
order by avg_delivery_delays desc;

-- Which carrier has the highest delivery failure rate? Conditional aggregation, CASE, GROUP BY
select carrier,
count(*) as completed_shipments,
sum(case when delivery_status = 'Failed'
			then 1 else 0 end) as failed_orders,
round(
	100 * sum(case when delivery_status = 'Failed'
			then 1 else 0 end) / count(*) ,2 
            ) as failure_rate
from ecommerce_shipping_delivery_performance
where delivery_status in ( 'Delivered' , 'Failed' , 'returned')
group by carrier
order by failure_rate desc;

-- Which months have the highest delivery delays? Date functions, MONTH, YEAR, GROUP BY, AVG
select 
year(actual_delivery_date) as delivery_year,
month(actual_delivery_date) as delivery_month,
count(*) as total_deliveries,
sum(case when actual_delivery_date > promised_delivery_date 
			then 1 else 0 end) as late_delivery,
 ROUND(
        AVG(CASE
            WHEN actual_delivery_date >
                 promised_delivery_date
            THEN DATEDIFF(
                actual_delivery_date,
                promised_delivery_date
            )
        END), 2
    ) AS average_delay_days

FROM ecommerce_shipping_delivery_performance
WHERE delivery_status = 'Delivered'
GROUP BY
    YEAR(actual_delivery_date),
    MONTH(actual_delivery_date)
ORDER BY
    delivery_year,
    delivery_month;

-- Which Tier 2 cities need last-mile optimization? Multiple aggregations, CASE, GROUP BY, CTE
-- We need to evaluate multiple factors: 1. On-time delivery rate. 2. Late delivery rate. 3. Delivery failure rate. 4. Average delivery time. 5. Average route distance. 6. Delivery volume.
WITH city_performance AS
(
    SELECT
        destination_city,

        COUNT(*) AS total_orders,

        SUM(CASE
            WHEN delivery_status = 'Delivered'
            THEN 1 ELSE 0
        END) AS delivered_orders,

        SUM(CASE
            WHEN delivery_status = 'Failed'
            THEN 1 ELSE 0
        END) AS failed_orders,

        SUM(CASE
            WHEN delivery_status = 'Returned to Origin'
            THEN 1 ELSE 0
        END) AS rto_orders,

        SUM(CASE
            WHEN delivery_status = 'Delivered'
             AND actual_delivery_date > promised_delivery_date
            THEN 1 ELSE 0
        END) AS late_orders,

        AVG(CASE
            WHEN delivery_status = 'Delivered'
            THEN CAST(
                DATEDIFF(
                    actual_delivery_date,
                    dispatch_date
                ) AS DECIMAL(10,2)
            )
        END) AS average_delivery_days

    FROM ecommerce_shipping_delivery_performance
    GROUP BY destination_city
)

SELECT
    destination_city,
    total_orders,
    delivered_orders,
    failed_orders,
    rto_orders,
    late_orders,

    CAST(
        100.0 * late_orders /
        NULLIF(delivered_orders, 0)
        AS DECIMAL(10,2)
    ) AS late_delivery_rate,

    CAST(
        100.0 * (failed_orders + rto_orders) /
        NULLIF(total_orders, 0)
        AS DECIMAL(10,2)
    ) AS unsuccessful_shipment_rate,

    average_delivery_days

FROM city_performance
WHERE total_orders >= 20
ORDER BY
    late_delivery_rate DESC,
    unsuccessful_shipment_rate DESC;

