USE sakila;

-- 2. Top Customers by Payments: Lists top-paying customers
CREATE TABLE IF NOT EXISTS top_customers_by_payments AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(p.amount) AS total_payment
FROM customer c
JOIN payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id
ORDER BY total_payment DESC
LIMIT 10;