USE sakila;

-- 1. Daily Rentals Report: Shows daily rentals by store
CREATE TABLE IF NOT EXISTS daily_rentals_report AS
SELECT
    r.rental_date AS rental_date,
    s.store_id AS store_id,
    COUNT(r.rental_id) AS total_rentals
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN store s ON i.store_id = s.store_id
GROUP BY r.rental_date, s.store_id;

