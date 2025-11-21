use sakila 

-- Top 5 most rented films 
WITH FilmRFM AS (
    SELECT 
        f.film_id,
        f.title,
        MAX(r.rental_date) AS last_rental_date,
        COUNT(r.rental_id) AS frequency,
        SUM(p.amount) AS monetary,
        DATEDIFF(CURRENT_DATE, MAX(r.rental_date)) AS recency_days
    FROM film f
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY f.film_id, f.title
),
RankedFilms AS (
    SELECT 
        *,
        DENSE_RANK() OVER (ORDER BY frequency DESC) AS film_rank
    FROM FilmRFM
)
SELECT 
    film_id,
    title,
    frequency AS rental_count,
    recency_days,
    monetary,
    film_rank
FROM RankedFilms
WHERE film_rank <= 5
ORDER BY film_rank;

-- top 5 paying customers

WITH CustomerRFM AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        MAX(p.payment_date) AS last_payment_date,
        COUNT(p.payment_id) AS frequency,
        SUM(p.amount) AS monetary,
        DATEDIFF(CURRENT_DATE, MAX(p.payment_date)) AS recency_days
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
RankedCustomers AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY monetary DESC) AS payment_rank
    FROM CustomerRFM
)
SELECT
    customer_id,
    customer_name,
    recency_days,
    frequency,
    monetary AS total_payment,
    payment_rank
FROM RankedCustomers
WHERE payment_rank <= 5
ORDER BY payment_rank;

-- Total Revenue Month wise 
SELECT
    DATE_FORMAT(payment_date, '%Y-%m') AS revenue_month,
    SUM(amount) AS total_revenue
FROM payment
GROUP BY DATE_FORMAT(payment_date, '%Y-%m')
ORDER BY revenue_month;

-- Top 3 Horror Films by Rental Frequency 

WITH HorrorFilmRFM AS (
    SELECT
        f.title AS film_title,
        c.name AS category_name,
        COUNT(r.rental_id) AS frequency,                 
        SUM(p.amount) AS monetary,                       
        MAX(r.rental_date) AS last_rental_date,
        DATEDIFF(CURRENT_DATE, MAX(r.rental_date)) AS recency_days, 
        DENSE_RANK() OVER (ORDER BY COUNT(r.rental_id) DESC) AS rental_rank
    FROM category c
    JOIN film_category fc ON c.category_id = fc.category_id
    JOIN film f ON fc.film_id = f.film_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    WHERE c.name = 'Horror'
    GROUP BY f.title, c.name
)
SELECT
    film_title,
    category_name,
    recency_days,
    frequency AS total_rentals,
    monetary AS total_revenue,
    rental_rank
FROM HorrorFilmRFM
WHERE rental_rank <= 3
ORDER BY rental_rank, film_title;
 
-- number of films Never rented category wise

SELECT 
    c.name AS category,
    COUNT(DISTINCT f.film_id) AS never_rented_movies
FROM film f
LEFT JOIN inventory i ON f.film_id = i.film_id
LEFT JOIN rental r ON i.inventory_id = r.inventory_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
WHERE r.rental_id IS NULL
GROUP BY c.name
ORDER BY never_rented_movies DESC;

-- Top 3 popular actors (rental)

WITH ActorRFM AS (
    SELECT
        a.actor_id,
        CONCAT(a.first_name, ' ', a.last_name) AS actor_name,
        MAX(r.rental_date) AS last_rental_date,
        COUNT(r.rental_id) AS frequency,
        SUM(p.amount) AS monetary,
        DATEDIFF(CURRENT_DATE, MAX(r.rental_date)) AS recency_days
    FROM actor a
    JOIN film_actor fa ON a.actor_id = fa.actor_id
    JOIN film f ON fa.film_id = f.film_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY a.actor_id, a.first_name, a.last_name
),
RankedActors AS (
    SELECT
        *,
        RANK() OVER (ORDER BY frequency DESC) AS actor_rank
    FROM ActorRFM
)
SELECT
    actor_id,
    actor_name,
    recency_days,
    frequency AS total_rentals,
    monetary AS total_revenue,
    actor_rank
FROM RankedActors
WHERE actor_rank <= 3
ORDER BY actor_rank, total_rentals DESC;

-- Top Most Watched film by Total Revenue in Each Category 

WITH MovieRFMByCategory AS (
    SELECT
        c.name AS category_name,
        f.film_id,
        f.title,
        COUNT(r.rental_id) AS frequency,
        SUM(p.amount) AS monetary,
        MAX(r.rental_date) AS last_rental_date,
        DATEDIFF(CURRENT_DATE, MAX(r.rental_date)) AS recency_days,
        ROW_NUMBER() OVER (
            PARTITION BY c.name 
            ORDER BY SUM(p.amount) DESC
        ) AS rn
    FROM category c
    JOIN film_category fc ON c.category_id = fc.category_id
    JOIN film f ON fc.film_id = f.film_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY c.name, f.film_id, f.title
)

SELECT
    category_name,
    film_id,
    title,
    recency_days,
    frequency,
    monetary AS total_revenue
FROM MovieRFMByCategory
WHERE rn = 1
ORDER BY total_revenue DESC;

-- Revenue by Each City

WITH CityRFM AS (
    SELECT 
        ci.city,
        COUNT(p.payment_id) AS frequency,
        SUM(p.amount) AS monetary,
        MAX(p.payment_date) AS last_payment_date,
        DATEDIFF(CURRENT_DATE, MAX(p.payment_date)) AS recency_days
    FROM payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN store s ON i.store_id = s.store_id
    JOIN address a ON s.address_id = a.address_id
    JOIN city ci ON a.city_id = ci.city_id
    GROUP BY ci.city
)
SELECT
    city,
    recency_days,
    frequency,
    monetary AS total_revenue
FROM CityRFM
ORDER BY monetary DESC;

-- Combine both staff and store performance on the basis of payment Handeling 

WITH StaffRFM AS (
    SELECT
        s.staff_id,
        s.first_name AS staff_name,
        st.store_id,
        COUNT(p.payment_id) AS frequency,
        SUM(p.amount) AS monetary,
        MAX(p.payment_date) AS last_payment_date,
        DATEDIFF(CURRENT_DATE, MAX(p.payment_date)) AS recency_days
    FROM staff s
    JOIN store st ON s.store_id = st.store_id
    JOIN payment p ON s.staff_id = p.staff_id
    GROUP BY s.staff_id, s.first_name, st.store_id
),
StoreTotals AS (
    SELECT 
        st.store_id,
        SUM(p.amount) AS total_amount
    FROM store st
    JOIN staff s ON st.store_id = s.store_id
    JOIN payment p ON s.staff_id = p.staff_id
    GROUP BY st.store_id
)
SELECT
    sr.store_id,
    sr.staff_name,
    sr.recency_days,
    sr.frequency AS staff_payment_count,
    sr.monetary AS staff_total,
    st.total_amount AS store_total
FROM StaffRFM sr
JOIN StoreTotals st ON sr.store_id = st.store_id
ORDER BY sr.monetary DESC;

-- Personalized Movie Recommendations Based on Each Customer’s Favorite Genre

WITH customer_genre_rentals AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        cat.category_id,
        cat.name AS genre,
        COUNT(*) AS rental_count
    FROM customer c
    JOIN rental r ON c.customer_id = r.customer_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category cat ON fc.category_id = cat.category_id
    GROUP BY c.customer_id, customer_name, cat.category_id, cat.name
),
favorite_genre_per_customer AS (
    SELECT customer_id, customer_name, category_id, genre
    FROM (
        SELECT *,
               RANK() OVER (PARTITION BY customer_id ORDER BY rental_count DESC) AS genre_rank
        FROM customer_genre_rentals
    ) ranked
    WHERE genre_rank = 1
),
films_in_fav_genre AS (
    SELECT f.film_id, f.title, fc.category_id
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
),
customer_watched_films AS (
    SELECT DISTINCT r.customer_id, i.film_id
    FROM rental r
    JOIN inventory i ON r.inventory_id = i.inventory_id
),
recommendations AS (
    SELECT 
        fg.customer_id, 
        fg.customer_name, 
        fg.genre, 
        f.title AS recommended_movie
    FROM favorite_genre_per_customer fg
    JOIN films_in_fav_genre f 
        ON fg.category_id = f.category_id  
    LEFT JOIN customer_watched_films cw
        ON fg.customer_id = cw.customer_id 
       AND f.film_id = cw.film_id
    WHERE cw.film_id IS NULL 
   
)
SELECT *
FROM recommendations
ORDER BY customer_name, recommended_movie;





