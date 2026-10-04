-- Clean up existing objects
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;
DROP PROCEDURE IF EXISTS reserve_workstations(INT, VARCHAR, INT);
DROP PROCEDURE IF EXISTS cancel_reservation(INT);

-- 1. Create tables and insert data
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100) NOT NULL,
    num_workstations INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED' -- 'CONFIRMED', 'CANCELLED'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('ICT371 Practical A', 30),
('ICT371 Practical B', 5),
('ICT211 Lab', 0);

-- 2. IF ELSIF ELSE report capacity
DO $$
DECLARE
    v_workstations INT;
    v_session_id INT := 2;
BEGIN
    SELECT available_workstations INTO v_workstations FROM lab_sessions WHERE session_id = v_session_id;
    
    IF v_workstations = 0 THEN
        RAISE NOTICE 'Session % is FULL.', v_session_id;
    ELSIF v_workstations <= 5 THEN
        RAISE NOTICE 'Session % is NEARLY FULL (% workstations left).', v_session_id, v_workstations;
    ELSE
        RAISE NOTICE 'Session % HAS ENOUGH WORKSTATIONS (% workstations left).', v_session_id, v_workstations;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    -- WHILE loop
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder #%', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    -- FOR loop
    FOR check_no IN 1..3 LOOP
        RAISE NOTICE 'Performing workstation check #%', check_no;
    END LOOP;
END $$;

-- 4. Create reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer_name VARCHAR,
    p_num_workstations INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_num_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid workstation request quantity: %. Must be greater than 0.', p_num_workstations;
    END IF;

    SELECT available_workstations INTO v_available FROM lab_sessions WHERE session_id = p_session_id;

    IF v_available < p_num_workstations THEN
        RAISE NOTICE 'Cannot reserve % workstations for Session %. Only % available.', 
                     p_num_workstations, p_session_id, v_available;
    ELSE
        UPDATE lab_sessions 
        SET available_workstations = available_workstations - p_num_workstations 
        WHERE session_id = p_session_id;

        INSERT INTO reservations (session_id, lecturer_name, num_workstations, status)
        VALUES (p_session_id, p_lecturer_name, p_num_workstations, 'CONFIRMED');

        RAISE NOTICE 'Reservation successful for Dr/Mr/Ms %.', p_lecturer_name;
    END IF;
END $$;

-- 5. Call procedure for 2 valid and 1 excessive request
CALL reserve_workstations(1, 'Dr. Banda', 10);
CALL reserve_workstations(2, 'Mr. Phiri', 3);
CALL reserve_workstations(3, 'Mrs. Tembo', 5); -- Exceeds capacity

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. Create cancel_reservation procedure & call twice
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_session_id INT;
    v_num INT;
BEGIN
    SELECT status, session_id, num_workstations INTO v_status, v_session_id, v_num
    FROM reservations WHERE reservation_id = p_reservation_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Reservation ID % not found.', p_reservation_id;
    ELSIF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation ID % is ALREADY cancelled. Workstations not released.', p_reservation_id;
    ELSE
        UPDATE lab_sessions 
        SET available_workstations = available_workstations + v_num 
        WHERE session_id = v_session_id;

        UPDATE reservations 
        SET status = 'CANCELLED' 
        WHERE reservation_id = p_reservation_id;

        RAISE NOTICE 'Reservation ID % successfully cancelled.', p_reservation_id;
    END IF;
END $$;

CALL cancel_reservation(1);
CALL cancel_reservation(1); -- Second call does not release workstations again

-- 7. Explicit cursor for sessions with few workstations
DO $$
DECLARE
    v_session RECORD;
    cur_few_workstations CURSOR FOR 
        SELECT session_id, session_name, available_workstations 
        FROM lab_sessions 
        WHERE available_workstations <= 5;
BEGIN
    OPEN cur_few_workstations;
    LOOP
        FETCH cur_few_workstations INTO v_session;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Workstations - Session ID: %, Name: %, Available: %', 
                     v_session.session_id, v_session.session_name, v_session.available_workstations;
    END LOOP;
    CLOSE cur_few_workstations;
END $$;

-- 8. Exception block for zero workstations
DO $$
BEGIN
    CALL reserve_workstations(1, 'Dr. Mulenga', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;

-- 9. Final query
SELECT * FROM lab_sessions;
SELECT * FROM reservations;