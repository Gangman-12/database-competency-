-- Clean up existing objects if re-running
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS events;
DROP PROCEDURE IF EXISTS book_seats(INT, INT, INT);
DROP PROCEDURE IF EXISTS cancel_booking(INT);

-- 1. Create tables and add at least three events
CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INT REFERENCES events(event_id),
    student_number INT NOT NULL,
    num_seats INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'BOOKED' -- 'BOOKED', 'CANCELLED'
);

INSERT INTO events (event_name, available_seats) VALUES
('Tech Innovation Summit', 50),
('Career Fair 2026', 3),
('Annual Engineering Gala', 0);

-- 2. IF ELSIF ELSE report event seat capacity
DO $$
DECLARE
    v_seats INT;
    v_event_id INT := 2;
BEGIN
    SELECT available_seats INTO v_seats FROM events WHERE event_id = v_event_id;

    IF v_seats = 0 THEN
        RAISE NOTICE 'Event % is FULL.', v_event_id;
    ELSIF v_seats <= 5 THEN
        RAISE NOTICE 'Event % is NEARLY FULL (% seats left).', v_event_id, v_seats;
    ELSE
        RAISE NOTICE 'Event % HAS PLENTY OF SEATS (% seats left).', v_event_id, v_seats;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_reminder_day INT := 1;
BEGIN
    -- WHILE loop for booking reminder days
    WHILE v_reminder_day <= 3 LOOP
        RAISE NOTICE 'Booking Reminder Day #%', v_reminder_day;
        v_reminder_day := v_reminder_day + 1;
    END LOOP;

    -- Numeric FOR loop for entrance checks
    FOR check_idx IN 1..3 LOOP
        RAISE NOTICE 'Performing Entrance Check #%', check_idx;
    END LOOP;
END $$;

-- 4. Create book_seats procedure
CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id INT,
    p_student_number INT,
    p_num_seats INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_seats INT;
BEGIN
    IF p_num_seats <= 0 THEN
        RAISE EXCEPTION 'Invalid seat request: %. Must book at least 1 seat.', p_num_seats;
    END IF;

    SELECT available_seats INTO v_seats FROM events WHERE event_id = p_event_id;

    IF v_seats IS NULL THEN
        RAISE EXCEPTION 'Event ID % does not exist.', p_event_id;
    END IF;

    IF v_seats < p_num_seats THEN
        RAISE NOTICE 'Cannot book % seats for Event ID %. Only % available.', p_num_seats, p_event_id, v_seats;
    ELSE
        UPDATE events 
        SET available_seats = available_seats - p_num_seats 
        WHERE event_id = p_event_id;

        INSERT INTO bookings (event_id, student_number, num_seats, status)
        VALUES (p_event_id, p_student_number, p_num_seats, 'BOOKED');

        RAISE NOTICE 'Booking successful for Student %.', p_student_number;
    END IF;
END $$;

-- 5. Call book_seats for two valid bookings and one request exceeding available seats
CALL book_seats(1, 20240101, 2); -- Valid booking
CALL book_seats(2, 20240202, 2); -- Valid booking
CALL book_seats(3, 20240303, 1); -- Exceeds capacity (0 seats)

SELECT * FROM events;
SELECT * FROM bookings;

-- 6. Create cancel_booking procedure & call twice
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_event_id INT;
    v_seats INT;
BEGIN
    SELECT status, event_id, num_seats INTO v_status, v_event_id, v_seats
    FROM bookings WHERE booking_id = p_booking_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Booking ID % not found.', p_booking_id;
    ELSIF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking ID % is ALREADY CANCELLED. Seats not released again.', p_booking_id;
    ELSE
        UPDATE events 
        SET available_seats = available_seats + v_seats 
        WHERE event_id = v_event_id;

        UPDATE bookings 
        SET status = 'CANCELLED' 
        WHERE booking_id = p_booking_id;

        RAISE NOTICE 'Booking ID % successfully cancelled.', p_booking_id;
    END IF;
END $$;

CALL cancel_booking(1);
CALL cancel_booking(1); -- Second call will not release seats again

-- 7. Explicit cursor to display full or nearly full events
DO $$
DECLARE
    v_event RECORD;
    cur_full_events CURSOR FOR 
        SELECT event_id, event_name, available_seats 
        FROM events 
        WHERE available_seats <= 5;
BEGIN
    OPEN cur_full_events;
    LOOP
        FETCH cur_full_events INTO v_event;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full Event - ID: %, Name: %, Seats Left: %', 
                     v_event.event_id, v_event.event_name, v_event.available_seats;
    END LOOP;
    CLOSE cur_full_events;
END $$;

-- 8. Try to book zero seats and handle with EXCEPTION block
DO $$
BEGIN
    CALL book_seats(1, 20240404, 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;

-- 9. Final queries to show seat availability and booking statuses
SELECT * FROM events;
SELECT * FROM bookings;