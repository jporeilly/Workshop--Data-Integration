USE sakila;

-- 5. Staff Performance Report: Shows the number of rentals processed by each staff member
CREATE TABLE IF NOT EXISTS staff_performance_report AS
SELECT
    s.staff_id,
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    COUNT(r.rental_id) AS rentals_processed
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
GROUP BY s.staff_id
ORDER BY rentals_processed DESC;