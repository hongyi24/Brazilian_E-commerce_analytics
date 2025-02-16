/*
 一、客户行为分析（关键：复购率与客户价值）
 */
--1、高价值客户识别
--Top 100的客户（按订单总金额)
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

--Top 100的客户的地理分布
--由于一个邮政编码对应多个经纬度，所以先处理表geolocation
create table Top100_customer_geolocation as
select Top100_customer.customer_unique_id as customer_id, Top100_customer.value,
       geolocation.lat as lat, geolocation.lng as lng, concat(',',lat,lng) as lat_lng
from Top100_customer
left join (
    SELECT geolocation_zip_code_prefix, avg(geolocation_lat) as lat, avg(geolocation_lng) as lng
    from geolocation group by geolocation_zip_code_prefix
    ) as geolocation
on Top100_customer.customer_zip_code_prefix = geolocation.geolocation_zip_code_prefix;

--Top 100的客户的偏好的产品类别
create table Top100_customer_products as
select product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g,
       product_length_cm, product_height_cm, product_width_cm
from products
right join (select product_id from order_items
    right join (select * from (select customers.customer_id from Top100_customer
left join customers on Top100_customer.customer_unique_id = customers.customer_unique_id) t1 ,order_dataset od
    where t1.customer_id = od.customer_id) as odp
    on order_items.order_id = odp.order_id) as t1
on products.product_id = t1.product_id;

--购买数量最多的前20种产品类别、平均描述长度、平均照片数量、平均名称长度、 平均重量
select product_category_name, count(*) as num, avg(product_name_lenght) as name_lenght,
       avg(product_description_lenght) as description_lenght,
       avg(product_photos_qty) as photos_qty,
       avg(product_weight_g) as weight_g
from Top100_customer_products
group by product_category_name order by num desc limit 20;


--支付方式与平均订单价值（AOV）
select payment_type,avg(payment_installments),avg(payment_value)
from order_payments
right join (select * from (select customers.customer_id from Top100_customer
left join customers on Top100_customer.customer_unique_id = customers.customer_unique_id) t1 ,order_dataset od
    where t1.customer_id = od.customer_id) as odp
on order_payments.order_id = odp.order_id
group by payment_type;


--2、复购行为分析
--用户数量增长曲线
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

--计算整体复购率（至少购买2次及以上的客户占比）
select t1.times, count(*) from (select customer_unique_id, count(*) as times
from order_dataset
right join customers c on order_dataset.customer_id = c.customer_id
group by customer_unique_id) as t1
group by t1.times;

--复购客户的购买时间间隔
create table time_difference as
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
    MIN(next_order_purchase_timestamp) - MIN(order_purchase_timestamp) AS time_difference
FROM
    RankedOrders
WHERE
    rn = 1
GROUP BY
    customer_unique_id
having
    second_order_time is not null;

select time_diff, count(*)
from(select round(EXTRACT(DAY FROM time_difference) / 30,0) as time_diff from time_difference) as t1
group by t1.time_diff;

--复购订单中高频产品类别（对比首次购买）
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

select * from High_frequency_product_categories order by num desc limit 30;

--复购客户的评价评分是否显著高于单次客户？

--复购消费者的打分
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
--第一次消费的打分
create table first_score as
select avg(review_score) as avg, std(review_score) as sd from (
    select order_id
    from (
        select customer_unique_id, min(order_purchase_timestamp) as min_time
        from (select * from customers left join Order_Dataset OD on customers.customer_id = OD.customer_id) as t1
        group by customer_unique_id
    ) as t2, (select * from customers left join Order_Dataset OD on customers.customer_id = OD.customer_id) as t3
    where t2.customer_unique_id = t3.customer_unique_id and t2.min_time = t3.order_purchase_timestamp) as t4
left join order_reviews
on t4.order_id = order_reviews.order_id;