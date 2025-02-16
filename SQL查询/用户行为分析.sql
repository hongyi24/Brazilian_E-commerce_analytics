/*
一、客户行为分析（关键：复购率与客户价值）
*/

-- 1、高价值客户识别

-- Top 100的客户（按订单总金额)
create table Top100_customer  AS
SELECT
    c.customer_unique_id,c.customer_zip_code_prefix,c.customer_city,
    SUM(oit_total.total_order_value) AS value,
    COUNT(*) AS order_count
FROM
    customers c
right JOIN (
    SELECT
        o.order_id,
        o.customer_id,
        oit.product_id,
        oit.total_order_item_value,
        oit.total_freight_value,
        oit.total_order_value
    FROM
        Order_Dataset o
    right JOIN (
        SELECT
            order_id,
            product_id,
            order_item_id * price AS total_order_item_value,
            order_item_id * freight_value AS total_freight_value,
            order_item_id * price + order_item_id * freight_value AS total_order_value
        FROM
            order_items
    ) AS oit ON o.order_id = oit.order_id
) AS oit_total ON c.customer_id = oit_total.customer_id
GROUP BY
    c.customer_unique_id, c.customer_zip_code_prefix,c.customer_city
ORDER BY
     value desc
limit 100;

-- Top 100的客户的地理分布

-- 由于一个邮政编码对应多个经纬度，所以先处理表geolocation

create table Top100_customer_geolocation as
select Top100_customer.customer_unique_id as customer_id, Top100_customer.value,
       geolocation.lat as lat, geolocation.lng as lng, concat(',',lat,lng) as lat_lng
from Top100_customer
left join (
    SELECT geolocation_zip_code_prefix, avg(geolocation_lat) as lat, avg(geolocation_lng) as lng
    from geolocation group by geolocation_zip_code_prefix
    ) as geolocation
on Top100_customer.customer_zip_code_prefix = geolocation.geolocation_zip_code_prefix;

-- Top 100的客户的偏好的产品类别

CREATE TABLE Top100_customer_products AS
SELECT
    p.product_category_name,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM
    products p
RIGHT JOIN (
    SELECT
        oi.product_id
    FROM
        order_items oi
    RIGHT JOIN (
        SELECT
            od.order_id
        FROM
            (SELECT
                c.customer_id
             FROM
                Top100_customer t100
             LEFT JOIN
                customers c
             ON
                t100.customer_unique_id = c.customer_unique_id
            ) t1
        JOIN
            order_dataset od
        ON
            t1.customer_id = od.customer_id
    ) odp
    ON
        oi.order_id = odp.order_id
) t1
ON
    p.product_id = t1.product_id;

SELECT * FROM Top100_customer_products;

-- 购买数量最多的前20种产品类别、平均描述长度、平均照片数量、平均名称长度、 平均重量
CREATE TABLE Top20_product as
select product_category_name, count(*) as num, avg(product_name_lenght) as name_lenght,
       avg(product_description_lenght) as description_lenght,
       avg(product_photos_qty) as photos_qty,
       avg(product_weight_g) as weight_g
from Top100_customer_products
group by product_category_name order by num desc limit 20;


-- 支付方式与平均订单价值（AOV）
CREATE TABLE Payment_method_order_value as
SELECT
    op.payment_type,
    AVG(op.payment_installments) AS avg_installments,
    AVG(op.payment_value) AS avg_payment_value
FROM
    order_payments op
RIGHT JOIN (
    SELECT
        od.order_id
    FROM
        (SELECT
            c.customer_id
         FROM
            Top100_customer t100
         LEFT JOIN
            customers c
         ON
            t100.customer_unique_id = c.customer_unique_id
        ) t1
    JOIN
        order_dataset od
    ON
        t1.customer_id = od.customer_id
) odp
ON
    op.order_id = odp.order_id
GROUP BY
    op.payment_type;

-- 2、复购行为分析

-- 用户数量增长曲线
create table customers_new_sum as
SELECT
    purchase_date,
    daily_new_users,
    SUM(daily_new_users) OVER (ORDER BY purchase_date) AS cumulative_new_users
FROM (
    SELECT
        DATE(OD.order_purchase_timestamp) AS purchase_date,
        COUNT(DISTINCT customers.customer_unique_id) AS daily_new_users
    FROM
        customers
    LEFT JOIN
        Order_Dataset OD
    ON
        customers.customer_id = OD.customer_id
    GROUP BY
        DATE(OD.order_purchase_timestamp)
) AS daily_users
ORDER BY
    purchase_date;
SELECT * FROM customers_new_sum

-- 计算整体复购率（至少购买2次及以上的客户占比）
CREATE TABLE repurchase_rate as
select t1.times, count(*) from (select customer_unique_id, count(*) as times
from order_dataset
right join customers c on order_dataset.customer_id = c.customer_id
group by customer_unique_id) as t1
group by t1.times;

-- 复购客户的购买时间间隔
CREATE TABLE time_difference AS
WITH RankedOrders AS (
    SELECT
        c.customer_unique_id,
        OD.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY OD.order_purchase_timestamp ASC
        ) AS rn,
        LEAD(OD.order_purchase_timestamp, 1) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY OD.order_purchase_timestamp ASC
        ) AS next_order_purchase_timestamp
    FROM
        order_dataset OD
    LEFT JOIN
        customers c
    ON
        OD.customer_id = c.customer_id
)
SELECT
    customer_unique_id,
    MIN(order_purchase_timestamp) AS first_order_time,
    MIN(next_order_purchase_timestamp) AS second_order_time,
    TIMESTAMPDIFF(MONTH, MIN(order_purchase_timestamp), MIN(next_order_purchase_timestamp)) AS time_difference_months
FROM
    RankedOrders
WHERE
    rn = 1
GROUP BY
    customer_unique_id
HAVING
    second_order_time IS NOT NULL;

CREATE TABLE time_difference_months as
SELECT time_difference_months, COUNT(*) FROM time_difference GROUP BY time_difference_months;


-- 复购订单中高频产品类别（对比首次购买）
create table High_frequency_product_categories as
WITH RankedOrders AS (
    SELECT
        c.customer_unique_id,
        OD.order_purchase_timestamp,
        OD.order_id,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY OD.order_purchase_timestamp ASC
        ) AS rn,
        LEAD(OD.order_purchase_timestamp, 1) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY OD.order_purchase_timestamp ASC
        ) AS next_order_purchase_timestamp
    FROM
        order_dataset OD
    LEFT JOIN
        customers c
    ON
        OD.customer_id = c.customer_id
)
select product_category_name,count(*) as num
from (select product_id
    from(select order_id
    from (SELECT
        customer_unique_id,
        MIN(next_order_purchase_timestamp) AS second_order_time
        FROM
            RankedOrders
        WHERE
            rn = 1
        GROUP BY
            customer_unique_id
        having
            second_order_time is not null) as t1
    left join RankedOrders
    on t1.customer_unique_id = RankedOrders.customer_unique_id and t1.second_order_time = RankedOrders.next_order_purchase_timestamp
    ) as t2
    left join order_items
    on t2.order_id = order_items.order_id) as t3
left join products
on t3.product_id = Products.product_id
group by product_category_name;

CREATE TABLE High_frequency_product_categories_top30
select * from High_frequency_product_categories WHERE High_frequency_product_categories.product_category_name is not NULL
order by num desc limit 30;

-- 复购客户的评价评分是否显著高于单次客户？

-- 做一个方差分析
-- 复购消费者的打分
create table second_score as
WITH RankedOrders AS (
    SELECT
        c.customer_unique_id,
        OD.order_purchase_timestamp,
        OD.order_id,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY OD.order_purchase_timestamp ASC
        ) AS rn,
        LEAD(OD.order_purchase_timestamp, 1) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY OD.order_purchase_timestamp ASC
        ) AS next_order_purchase_timestamp
    FROM
        order_dataset OD
    LEFT JOIN
        customers c
    ON
        OD.customer_id = c.customer_id
)
select avg(review_score) as avg, std(review_score) as sd
from (select order_id
    from (SELECT
        customer_unique_id,
        MIN(next_order_purchase_timestamp) AS second_order_time
        FROM
            RankedOrders
        WHERE
            rn = 1
        GROUP BY
            customer_unique_id
        having
            second_order_time is not null) as t1
    left join RankedOrders
    on t1.customer_unique_id = RankedOrders.customer_unique_id and t1.second_order_time = RankedOrders.next_order_purchase_timestamp
) as t2
left join order_reviews
on t2.order_id = Order_Reviews.order_id;
-- 第一次消费的打分
create table first_score as
SELECT
    AVG(review_score) AS avg,
    STD(review_score) AS sd
FROM (
    SELECT t3.order_id
    FROM (
        SELECT
            c.customer_unique_id,
            MIN(OD.order_purchase_timestamp) AS min_time
        FROM
            customers c
        LEFT JOIN
            Order_Dataset OD ON c.customer_id = OD.customer_id
        GROUP BY
            c.customer_unique_id
    ) AS t2
    JOIN (
        SELECT
            c2.customer_unique_id,
            OD2.order_id,
            OD2.order_purchase_timestamp
        FROM
            customers c2
        LEFT JOIN
            Order_Dataset OD2 ON c2.customer_id = OD2.customer_id
    ) AS t3
    ON t2.customer_unique_id = t3.customer_unique_id
    AND t2.min_time = t3.order_purchase_timestamp
) AS t4
LEFT JOIN
    order_reviews
ON
    t4.order_id = order_reviews.order_id;
