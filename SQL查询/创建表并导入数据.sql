create table customers(
    customer_id  text comment '每个订单都有唯一的customer_id',
    customer_unique_id  text comment '客户的唯一标识符',
    customer_zip_code_prefix  text comment '客户邮政编码的前 5 位数字',
    customer_city  text comment '客户城市名称',
    customer_state  text comment '客户状态'
)
comment '此数据集包含有关客户及其位置的信息。使用它来识别订单数据集中的唯一客户并查找订单交付位置。';

create table geolocation (
    geolocation_zip_code_prefix  text comment '客户邮政编码的前 5 位数字',
    geolocation_lat double comment '纬度',
    geolocation_lng double comment '经度',
    geolocation_city  text comment '城市名称',
    geolocation_state  text comment '州'
)
comment '此数据集包含巴西邮政编码及其纬度/液化天然气坐标信息。使用它来绘制地图并查找卖家和客户之间的距离。';

create table Order_Items(
    order_id  text comment '订单唯一标识符',
    order_item_id int comment 'Sequential Number （序列号） 标识同一订单中包含的项目数',
    product_id  text comment '商品唯一标识符',
    seller_id  text comment '卖家唯一标识符',
    shipping_limit_date date comment '显示卖家将订单处理给物流合作伙伴的发货限制日期',
    price float comment '商品价格',
    freight_value float comment 'item 运费价值 item （如果一个订单有多个商品，则运费价值将在商品之间拆分）'
)
comment '此数据集包含有关每个订单中购买的商品的数据。';

create table Order_Payments(
    order_id  text comment '订单的唯一标识符',
    payment_sequential int comment '客户可以使用多种付款方式支付订单。如果他这样做，将创建一个序列来容纳所有付款',
    payment_type  text comment '客户选择的付款方式',
    payment_installments int comment '客户选择的分期付款数',
    payment_value float comment '交易价值'
)
comment '此数据集包含有关订单付款选项的数据.';

create table Order_Reviews(
    review_id  text comment '唯一评价标识符',
    order_id  text comment '唯一订单标识符',
    review_score int comment '备注，范围从 1 到 5 不等，由客户在满意度调查中提供',
    review_comment_title  text comment '客户留下的评论的评论标题（葡萄牙语）',
    review_comment_message  text comment '客户留下的评论中的葡萄牙语评论消息',
    review_creation_date date comment '显示向客户发送满意度调查的日期',
    review_answer_timestamp date comment '显示满意度调查答案时间戳'
)
comment '此数据集包含有关客户所做评论的数据';

create table Order_Dataset(
    order_id  text comment '订单的唯一标识符',
    customer_id  text comment 'key 添加到 Customer 数据集中。每个订单都有唯一的customer_id',
    order_status  text comment '对订单状态（已送达、已发货等）的引用',
    order_purchase_timestamp date comment '显示购买时间戳',
    order_approved_at date comment '显示付款批准时间戳',
    order_delivered_carrier_date date comment '显示订单过帐时间戳。当它被处理给物流合作伙伴时。',
    order_delivered_customer_date date comment '向客户显示实际订单交货日期',
    order_estimated_delivery_date date comment '显示在购买时通知客户的预计交货日期。'
)
comment '这是核心数据集。从每个订单中，您可能会找到所有其他信息。';

create table Products (
    product_id  text comment '唯一商品标识码',
    product_category_name  text comment '产品的根类别（葡萄牙语）',
    product_name_lenght int comment '从产品名称中提取的字符数',
    product_description_lenght int comment '从产品描述中提取的字符数',
    product_photos_qty int comment '产品发布照片数量',
    product_weight_g int comment '产品重量以克为单位',
    product_length_cm int comment '产品长度以厘米为单位',
    product_height_cm int comment '商品高度以厘米为单位',
    product_width_cm int comment '产品宽度以厘米为单位'
)
comment '此数据集包括有关 Olist 销售的产品的数据。';

create table Sellers (
    seller_id  text comment '卖家唯一标识符',
    seller_zip_code_prefix  text comment '卖家邮政编码的前 5 位数字',
    seller_city  text comment '卖家城市名称',
    seller_state  text comment '卖家状态'
)
comment '此数据集包括有关履行在 Olist 下的订单的卖家的数据。使用它来查找卖家位置并确定哪个卖家配送了每件商品。';

create table Category_Name_Translation(
    product_category_name  text comment '葡萄牙语的类别名称',
    product_category_name_english  text comment '英文类别名称'
)
comment '将 product_category_name 翻译成英文。';
show tables ;


LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_customers_dataset.csv' INTO TABLE customers FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_geolocation_dataset.csv' INTO TABLE geolocation  FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_order_items_dataset.csv' INTO TABLE Order_Items FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_order_payments_dataset.csv' INTO TABLE Order_Payments FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_order_reviews_dataset.csv' INTO TABLE Order_Reviews FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_orders_dataset.csv' INTO TABLE Order_Dataset FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_products_dataset.csv' INTO TABLE Products FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/olist_sellers_dataset.csv' INTO TABLE Sellers  FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'F:/kaggle/archive/product_category_name_translation.csv' INTO TABLE Category_Name_Translation FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
