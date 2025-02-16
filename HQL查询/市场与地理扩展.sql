/*
 四、市场与地理扩展（核心：区域机会挖掘）
 */

--7、区域渗透率分析

--按城市统计：订单量、销售额、客户数
create table Regional_permeability_1 as
select c.customer_city, sum(oi.order_item_id) as Order_volume, sum(order_item_id*(price+freight_value)) as Sales,
       count(c.customer_unique_id) as Num_customers
from customers c
left join Order_Dataset OD on c.customer_id = OD.customer_id
left join order_items oi on OD.order_id = oi.order_id
group by c.customer_city
order by Num_customers desc
limit 30;

--低渗透率但高增长潜力的区域（如订单量少但客单价高）
create table Regional_permeability_2 as
select c.customer_city, sum(order_item_id*(price+freight_value)) as Sales, count(c.customer_unique_id) as Num_customers
from customers c
left join Order_Dataset OD on c.customer_id = OD.customer_id
left join order_items oi on OD.order_id = oi.order_id
group by c.customer_city
having count(c.customer_unique_id) <20
order by Sales desc
limit 10;

select * from Regional_permeability_2;

--8、跨区域销售分析
create table Cross_regional_sales as
WITH geolocation_lat_lng AS (
    SELECT geolocation_zip_code_prefix, geolocation_state
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix, geolocation_state
)
select g1.geolocation_state as customer_state, g2.geolocation_state as seller_state, t1.freight_cost
from (
    select customer_zip_code_prefix, seller_zip_code_prefix, freight_value*order_item_id as freight_cost
    from order_items oi
    left join Order_Dataset OD on oi.order_id = OD.order_id
    left join customers c on c.customer_id = Od.customer_id
    left join sellers s on oi.seller_id = s.seller_id
    ) as t1
left join geolocation_lat_lng g1 on g1.geolocation_zip_code_prefix = t1.customer_zip_code_prefix
left join geolocation_lat_lng g2 on g2.geolocation_zip_code_prefix = t1.seller_zip_code_prefix;

--卖家与客户不在同一州的订单占比
select (sum(`if`(customer_state != seller_state,1,0)) / count(*)) as proportion
from Cross_regional_sales where seller_state is not null; -- 0.6368185737269229的订单是非同一个州

--跨州订单的物流成本是否显著更高？
select round(avg(`if`(customer_state != seller_state,1,0) * freight_cost),2) as Cross_freight_cost,
       round(avg(`if`(customer_state == seller_state,1,0) * freight_cost),2) as Same_freight_cost
from Cross_regional_sales where seller_state is not null;-- 17.742218280870947， 5.825033474319637