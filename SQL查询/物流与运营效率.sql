/*
三、物流与运营效率（关键：成本与时效）
*/

-- 5、运费成本分析

create table Percentage_of_shipping_costs as
select geolocation_state, avg(t3.Percentage_of_shipping_costs) as avg_Percentage_of_shipping_costs
from(
    select customer_zip_code_prefix, t2.Percentage_of_shipping_costs
    from (
        select customer_id, t1.Percentage_of_shipping_costs
        from (select order_id, freight_value/(price+freight_value) as Percentage_of_shipping_costs from order_items) as t1
        left join Order_Dataset
        on t1.order_id = Order_Dataset.order_id
             ) as t2
    left join customers
    on customers.customer_id = t2.customer_id
        ) as t3
left join geolocation
on t3.customer_zip_code_prefix = geolocation.geolocation_zip_code_prefix
group by geolocation_state
order by avg_Percentage_of_shipping_costs desc;

-- 运费最高的Top 100订单特征（如距离、产品重量/体积）
-- 距离
CREATE TABLE Top100_distance AS
WITH geolocation_lat_lng AS (
    SELECT geolocation_zip_code_prefix, AVG(geolocation_lat) AS lat, AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
)
SELECT
    t2.Percentage_of_shipping_costs,
    6371 * 2 * ASIN(
        SQRT(
            POWER(SIN((RADIANS(g2.lat) - RADIANS(g1.lat)) / 2), 2) +
            COS(RADIANS(g1.lat)) * COS(RADIANS(g2.lat)) *
            POWER(SIN((RADIANS(g2.lng) - RADIANS(g1.lng)) / 2), 2)
        )
    ) AS distance_km
FROM (
    SELECT
        customer_id,
        t1.Percentage_of_shipping_costs,
        t1.seller_id
    FROM (
        SELECT
            order_id,
            seller_id,
            freight_value / (price + freight_value) AS Percentage_of_shipping_costs
        FROM order_items
        ORDER BY freight_value / (price + freight_value) DESC
        LIMIT 100
    ) AS t1
    LEFT JOIN Order_Dataset ON Order_Dataset.order_id = t1.order_id
) AS t2
LEFT JOIN customers c ON c.customer_id = t2.customer_id
LEFT JOIN sellers s ON s.seller_id = t2.seller_id
LEFT JOIN geolocation_lat_lng g1 ON g1.geolocation_zip_code_prefix = c.customer_zip_code_prefix
LEFT JOIN geolocation_lat_lng g2 ON g2.geolocation_zip_code_prefix = s.seller_zip_code_prefix;

CREATE TABLE Top100_distance_1 as
select distance_km, avg(Percentage_of_shipping_costs) from Top100_distance group by distance_km; -- 相关分析


-- 体积
create table Top100_volume as
select t1.Percentage_of_shipping_costs, product_weight_g, product_length_cm * product_height_cm * product_width_cm as volume
from (
        SELECT product_id, freight_value / (price + freight_value) AS Percentage_of_shipping_costs
        FROM order_items
        ORDER BY freight_value / (price + freight_value) DESC
        LIMIT 100
         ) as t1
left join products
on Products.product_id = t1.product_id;

-- 6、配送时效与客户满意度

-- 延迟订单的客户评分是否显著更低？
SELECT
    review_score,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS delivery_difference
FROM
    Order_Dataset
LEFT JOIN
    order_reviews o
    ON Order_Dataset.order_id = o.order_id
WHERE
    order_delivered_customer_date IS NOT NULL
    AND review_score IS NOT NULL;

--实际上比预估时间提前7天还未送达，就会给差评
SELECT AVG(delivery_difference)
FROM (
    SELECT
        review_score,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS delivery_difference
    FROM
        Order_Dataset
    LEFT JOIN
        order_reviews o
    ON Order_Dataset.order_id = o.order_id
    WHERE
        order_delivered_customer_date IS NOT NULL
        AND review_score IS NOT NULL
) AS subquery
WHERE review_score < 4;

-- 延迟订单的地理分布（城市）
CREATE TABLE delayed_orders_state AS
SELECT
    customer_state,
    AVG(t1.delivery_difference) AS delivery_difference
FROM (
    SELECT
        customer_id,
        DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS delivery_difference
    FROM Order_Dataset
    WHERE DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) > -7
) AS t1
LEFT JOIN customers c
    ON t1.customer_id = c.customer_id
GROUP BY customer_state
ORDER BY delivery_difference DESC;
