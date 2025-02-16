/*
二、销售与产品分析（核心：增长机会与库存优化）
*/

-- 3、销售趋势与季节性
create table month_order_tend as
select
    year(order_purchase_timestamp) as years,
    month(order_purchase_timestamp) as months,
    sum(t1.total_order_value) as sum_value,
    sum(t1.order_item_id) as order_num,
    sum(t1.total_order_value) / sum(t1.order_item_id) as avg_value
from (
    select
        order_id,
        product_id,
        order_item_id,
        order_item_id * price + order_item_id * freight_value AS total_order_value
    from order_items
) as t1
left join order_dataset
on t1.order_id = order_dataset.order_id
group by year(order_purchase_timestamp), month(order_purchase_timestamp)
order by years, months;

-- 环比增长率
CREATE TABLE month_growth_rate as
SELECT
    STR_TO_DATE(CONCAT(t1.years, '-', LPAD(t1.months, 2, '0'), '-01'), '%Y-%m-%d') AS order_month,
    t1.sum_value,
    COALESCE(t1.sum_value - t2.sum_value, 0) / t2.sum_value * 100 AS mom_growth_rate
FROM
    month_order_tend t1
LEFT JOIN
    month_order_tend t2
ON
    t1.years = t2.years AND t1.months = t2.months + 1  -- 连接前一个月
WHERE
    (t1.years = 2017 AND t1.months >= 1) OR (t1.years = 2018 AND t1.months <= 8)
ORDER BY
    t1.years, t1.months;


-- 销售额排名前10的产品类别及占比
create table Top10_produce as
select
    Products.product_category_name,
    sum(t1.total_order_value) as total_order_value
from (
    select
        order_id,
        product_id,
        order_item_id,
        order_item_id * price + order_item_id * freight_value AS total_order_value
    from order_items
) as t1
left join Products
on t1.product_id = Products.product_id
group by Products.product_category_name
order by total_order_value desc
limit 10;

-- 4、滞销与热销产品分析
create table Top_during as
WITH monthly_sales AS (
    SELECT
        ps.product_category_name,
        SUM(p.order_item_id) AS total_sales,
        YEAR(p.order_purchase_timestamp) AS years,
        MONTH(p.order_purchase_timestamp) AS months
    FROM Products ps
    RIGHT JOIN (
        SELECT
            oi.order_id,
            oi.product_id,
            oi.order_item_id,
            od.order_purchase_timestamp
        FROM Order_Items oi
        LEFT JOIN Order_Dataset od
        ON oi.order_id = od.order_id
    ) AS p
    ON ps.product_id = p.product_id
    WHERE p.order_purchase_timestamp BETWEEN '2017-08-01' AND '2018-08-31'  -- 限制时间范围
    GROUP BY ps.product_category_name, YEAR(p.order_purchase_timestamp), MONTH(p.order_purchase_timestamp)
),
sales_trends AS (
    SELECT
        product_category_name,
        months,
        total_sales,
        LAG(total_sales) OVER (PARTITION BY product_category_name ORDER BY months) AS prev_sales
    FROM monthly_sales
)
SELECT
    product_category_name,
    SUM(total_sales) AS total_sales_during_period
FROM sales_trends
WHERE total_sales < prev_sales  -- 持续下降的月份
GROUP BY product_category_name
ORDER BY total_sales_during_period ASC
limit 15;



-- 销量增长最快的Top 10产品类别
create table Top_growth as
WITH monthly_sales AS (
    SELECT
        ps.product_category_name,
        SUM(p.order_item_id) AS total_sales,
        YEAR(p.order_purchase_timestamp) AS years,
        MONTH(p.order_purchase_timestamp) AS months
    FROM Products ps
    RIGHT JOIN (
        SELECT
            oi.order_id,
            oi.product_id,
            oi.order_item_id,
            od.order_purchase_timestamp
        FROM Order_Items oi
        LEFT JOIN Order_Dataset od
        ON oi.order_id = od.order_id
    ) AS p
    ON ps.product_id = p.product_id
    WHERE p.order_purchase_timestamp BETWEEN '2017-08-01' AND '2018-08-31'  -- 限制时间范围
    GROUP BY ps.product_category_name, YEAR(p.order_purchase_timestamp), MONTH(p.order_purchase_timestamp)
),
sales_trends AS (
    SELECT
        product_category_name,
        months,
        total_sales,
        LAG(total_sales) OVER (PARTITION BY product_category_name ORDER BY months) AS prev_sales
    FROM monthly_sales
),
growth AS (
    SELECT
        product_category_name,
        months,
        total_sales,
        total_sales - COALESCE(prev_sales, 0) AS sales_growth  -- 计算每月销量增长量
    FROM sales_trends
    WHERE total_sales > COALESCE(prev_sales, 0)  -- 只选择销量增长的月份
),
top_10_growth_categories AS (
    SELECT
        product_category_name,
        SUM(sales_growth) AS total_growth
    FROM growth
    GROUP BY product_category_name
    ORDER BY total_growth DESC  -- 按销量增长量降序排列
    LIMIT 10  -- 选择销量增长最快的Top 10产品类别
)
SELECT
    g.product_category_name,
    g.months,
    g.total_sales
FROM growth g
JOIN top_10_growth_categories t ON g.product_category_name = t.product_category_name
ORDER BY g.product_category_name, g.months;


-- 结合评价数据，分析滞销产品的差评率是否显著高于热销产品
create table review as
SELECT
    t1.product_category_name,
    SUM(t1.order_item_id) AS num,
    SUM(CASE WHEN review_score > 3 THEN 1 ELSE 0 END) AS great,
    SUM(CASE WHEN review_score < 3 THEN 1 ELSE 0 END) AS bad,
    SUM(CASE WHEN review_score = 3 THEN 1 ELSE 0 END) AS mid
FROM Order_Reviews
LEFT JOIN (
    SELECT
        order_id,
        order_item_id,
        product_category_name
    FROM order_items
    LEFT JOIN Products P
    ON Order_Items.product_id = P.product_id
) AS t1
ON Order_Reviews.order_id = t1.order_id
GROUP BY t1.product_category_name
ORDER BY num DESC;


create table Hot_Product_Reviews as
select sum(num) as sum_num, sum(great) as sum_great, sum(bad) as sum_bad, sum(mid) as sum_mid,
       sum(great)+sum(bad)+sum(mid) as sum_review
from(select * from review
     where num is not null
     order by num desc
     limit 10) as t1;

create table dead_stock_Product_Reviews as
select sum(num) as sum_num, sum(great) as sum_great, sum(bad) as sum_bad, sum(mid) as sum_mid,
       sum(great)+sum(bad)+sum(mid) as sum_review
from(select * from review
     where num is not null
     order by num asc
     limit 10) as t1;