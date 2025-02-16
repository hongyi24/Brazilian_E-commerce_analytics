/*
支付与评价反馈（关键：用户体验优化）
*/

-- 9、支付方式对订单完成率的影响
-- 平均订单金额
select payment_type, avg(payment_value) as avg_payment
from order_payments
where payment_type != 'not_defined'
group by payment_type
-- 分期支付的平均支付金额
select payment_installments, avg(payment_value) as avg_payment
from order_payments
group by payment_installments;

-- 10、是否存在同一卖家的差评集中现象？
create table negative_Percentage as
SELECT so.seller_id,
       SUM(IF(review_score < 3, 1, 0)) / COUNT(*) AS negative_Percentage
FROM (
    SELECT o.order_id, s.seller_id
    FROM (SELECT seller_id FROM sellers) s
    RIGHT JOIN order_items o ON s.seller_id = o.seller_id
) AS so
LEFT JOIN order_reviews ore ON ore.order_id = so.order_id
GROUP BY so.seller_id
HAVING COUNT(*) > 10
ORDER BY negative_Percentage DESC
LIMIT 15;

select * from negative_Percentage;