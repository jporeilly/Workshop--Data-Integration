USE sakila;

-- 3. Revenue by Category and Month: Shows monthly revenue by film category
CREATE TABLE IF NOT EXISTS revenue_by_category_month AS
SELECT
    c.name AS category,
    DATE_FORMAT(p.payment_date, '%Y-%m') AS month,
    SUM(p.amount) AS total_revenue
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
GROUP BY c.name, DATE_FORMAT(p.payment_date, '%Y-%m');