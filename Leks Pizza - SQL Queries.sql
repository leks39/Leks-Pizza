-- Importing data from Excel
-- Creating Table 1 - delivery info 
CREATE TABLE delivery_info(
    delivery_id int,
    rider_name varchar(50),
    location_type varchar(50),
    distance_km float,
    order_time varchar(50),
    deliverytime_mins int,
    delivery_location varchar(50)
);

-- Creating Table 2 - order info
CREATE TABLE order_info(
    order_id int,
    order_channel varchar(50),
    order_date varchar(50),
    pizza_size varchar(50),
    pizza_type varchar(50),
    side_order varchar(50),
    order_amount float,
    tip float,
    payment_method varchar(50)
);

-- Creating Table 3 - pizza info
CREATE TABLE pizza_info (
    pizza_type  varchar(50),
    menu_name varchar(50),
    category varchar(50),
    ingredients varchar(250)
);

-- Question 1 - Calculate total sales , total qunatity sold and average order price for each month in 2020 (DateTime Conversion, Aliases, Round Function, Sub-Queries)
-- First step in answering this question is converting the order_date column in order_review table from varchar to datetime data type
Update order_info
Set order_date = str_to_date(order_date, "%m/%d/%Y");

Select *, Round(Month_Sales/Month_Quantity,2) as Average_Ticket
From (Select monthname(order_date) as Month_Name, Round(SUM(order_amount ),2) as Month_Sales, count(order_id) as Month_Quantity
From order_info
Group By Month_Name
Order By FIELD(Month_Name,'January','February','March', 'April', 'May','June', 
'July', 'August', 'September', 'October', 'November', 'December'))a;

-- Question 2 - Rank Days of week in terms of sales and quantity sold numbers. (DateTime, Rank)
Select dayname(order_date) as Day_of_Week , Round(Sum(order_amount),2) as Day_Sales, count(order_id) as Day_Quantity,
  rank() over (Order By Sum(order_amount) Desc) as Sales_Rank
From order_info
Group By Day_of_Week;

-- Question 3 - Ranking Driver by Total Sales, Total Quantity,  Total Tip, % Tip, Average Delivery Time (Generated Columns, Joins)
-- First step is to create a new column for tip percentage by updating the table using generated columns

Alter Table order_info
Add Column tip_percent float Generated Always as ((tip/order_amount)*100);

Select d.rider_name as Rider_Name , Round(Sum(o.order_amount),2) as Sales_Amount, count(o.order_id) as No_of_Orders, 
Round(avg(d.deliverytime_mins),2) as Avg_Delivery_Time, round(sum(o.tip),2) as Total_Tips,
round(tip_percent,2) as Tip_Percent
From delivery_info as d 
join order_info as o ON delivery_id = order_id
Group by Rider_Name
Order by Sales_Amount Desc;


-- Question 4 - Divide deliveries into different time periods (Datetime conversion, Case When Statements)
-- First step in answering this question is converting the order_time column in delivery_info table from varchar to datetime data type
Update delivery_info
Set order_time = TIME_FORMAT(order_time, '%H:%i');

Select order_period, count(order_period) as period_quantity
From (Select delivery_id, rider_name,location_type, deliverytime_mins,
       Case When order_time < '13:00'  then 'Early Orders'
       When order_time > '13:00' and order_time < '17:00' then 'Lunch Orders'
       When order_time > '17:00' and order_time < '21:00' then 'Dinner Orders'
       Else 'Late Orders'
       End as 'Order_Period'
From delivery_info) as period
Group by order_period
Order by period_quantity Desc;

-- Question 5 - percentage ofsales for each order period (With Clause , Percentage of Total)
with total as 
    ( select count(delivery_id) as total
    from delivery_info )
Select order_period, count(order_period) as period_quantity, round(count(order_period)/t.total*100,2) as percent_of_total
From (Select delivery_id, rider_name,location_type, deliverytime_mins,
       Case When order_time < '13:00'  then 'Early Orders'
       When order_time > '13:00' and order_time < '17:00' then 'Lunch Orders'
       When order_time > '17:00' and order_time < '21:00' then 'Dinner Orders'
       Else 'Late Orders'
       End as 'Order_Period'
From delivery_info) as period, total as t
Group by order_period
Order by period_quantity Desc;

-- Questions 6 - rank the top selling pizzas , also rank by category (join, row number() )
-- Top selling pizzas
Select o.pizza_type, p.category, count(o.pizza_type) as quantity_sold
From order_info as o
Join pizza_info as p
ON o.pizza_type = p.pizza_type
Group by pizza_type
Order by quantity_sold desc
Limit 10;

-- Top selling 3 pizzas by in each category
with pizza_sales as (Select o.pizza_type, p.menu_name, p.category, count(o.pizza_type) as quantity_sold,
row_number() over (partition by category order by count(o.pizza_type) desc) as category_rank
from order_info as o
join pizza_info as p on o.pizza_type = p.pizza_type
Group by pizza_type, category
order by category)

Select *
From pizza_sales
Where category_rank <= 3;

-- Question 7 - Top selling locations by order amount and quantity , delivery time etc
Select d.delivery_location, Round(Sum(o.order_amount),2) as location_sales,count(o.order_id) as location_orders,
round(avg(d.distance_km),2) as average_distance, round(avg(d.deliverytime_mins),2) as average_delivery_time
From delivery_info as d
Join order_info as o ON d.delivery_id = o.order_id
Group by delivery_location
Order by location_sales desc;

-- Question 8 - Most popular pizza sizes and their proportion of quantity sold
with total as
  (select count(pizza_size) as total
  from order_info)
  Select pizza_size, count(pizza_size) as no_of_pizzas, round(count(pizza_size)/t.total*100,2) as size_proportion
From order_info, total as t
Group By pizza_size
Order by no_of_pizzas desc;

-- Question 9 - Percentage of deliveries that are late (late delivery is delivery > 30 mins)
-- First step is to create a column grouping deliveries using Case Statement
-- Second step is to get count of each category of delivery speed
-- Third step is getting proportion of each delivery category using with clause
-- Last step is filtering for late deliveries using having clause (having is used instead of where becasue of group by)

  with total_deliveries as
  (select count(delivery_id) as total_orders from delivery_info)
Select delivery_speed, round(delivery_count/td.total_orders*100,2) as delivery_percent
From( 
Select delivery_speed, count(delivery_speed) as delivery_count
From (
Select *,
Case when deliverytime_mins <= 10 then 'Fast Delivery'
When deliverytime_mins > 10 and deliverytime_mins <=30 then 'Standard Delivery'
Else 'Late Delivery'
End as 'delivery_speed'
From delivery_info)ds
Group by delivery_speed
Order by delivery_count desc)dc, total_deliveries as td
Having delivery_speed = 'Late Delivery';

-- Question 10 Rank Driver by the number of early, standard and late deliveries made
Select rider_name, count(delivery_speed) as no_of_deliveries
From(
Select *,
Case when deliverytime_mins < 10 then 'Fast Delivery'
When deliverytime_mins > 10 and deliverytime_mins < 30 then 'Standard Delivery'
Else 'Late Delivery'
End as 'delivery_speed'
From delivery_info)ds
Where delivery_speed = 'Fast Delivery'
group by delivery_speed, rider_name
Order by no_of_deliveries Desc;

-- No of deliveries by location that are 30% above the average order amount
with big_order as (
Select *
From order_info
Where order_amount > 
(Select round(avg(order_amount),2) * 1.3
From order_info))

Select d.delivery_location, count(bo.order_id) as big_orders
From big_order as bo
Join delivery_info as d
on bo.order_id = d.delivery_id
Group by d.delivery_location
Order by big_orders desc;