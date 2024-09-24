USE sakila;

-- 4. Film Popularity Report: Lists the most rented films by store
CREATE TABLE IF NOT EXISTS film_popularity_report AS
SELECT
    f.film_id,
    f.title AS film_title,
    s.store_id,
    COUNT(r.rental_id) AS rental_count
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN store s ON i.store_id = s.store_id
JOIN film f ON i.film_id = f.film_id
GROUP BY f.film_id, s.store_id
ORDER BY rental_count DESC;