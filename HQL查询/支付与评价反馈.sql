/*
 五、支付与评价反馈（关键：用户体验优化）
 */

--9、支付方式对订单完成率的影响
--平均订单金额
select payment_type, avg(payment_value) as avg_payment
from order_payments
where payment_type != 'not_defined'
group by payment_type
--分期支付的平均支付金额
select payment_installments, avg(payment_value) as avg_payment
from order_payments
group by payment_installments;

--10、是否存在同一卖家的差评集中现象？
create table negative_Percentage as
select so.seller_id, sum(`if`(review_score<3,1,0))/count(*) as negative_Percentage
from (
    select o.order_id, s.seller_id from (select seller_id from sellers)  s
    right join order_items o on  s.seller_id = o.seller_id
         ) as so
left join order_reviews ore on ore.order_id = so.order_id
group by so.seller_id
having count(*) > 10
order by negative_Percentage desc
limit 15;

select * from negative_Percentage;