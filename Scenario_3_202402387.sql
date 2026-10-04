-- Clean up existing objects
DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;
DROP PROCEDURE IF EXISTS allocate_room(INT, INT);
DROP PROCEDURE IF EXISTS check_out(INT);

-- 1. Create tables and insert data
CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(10) NOT NULL,
    available_beds INT NOT NULL CHECK (available_beds >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number INT,
    room_id INT REFERENCES hostel_rooms(room_id),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' -- 'ACTIVE', 'COMPLETED'
);

INSERT INTO hostel_rooms (room_number, available_beds) VALUES
('BlockA-101', 4),
('BlockA-102', 1),
('BlockB-201', 0);

-- 2. IF ELSIF ELSE status report
DO $$
DECLARE
    v_beds INT;
    v_room_id INT := 2;
BEGIN
    SELECT available_beds INTO v_beds FROM hostel_rooms WHERE room_id = v_room_id;

    IF v_beds = 0 THEN
        RAISE NOTICE 'Room % is FULL.', v_room_id;
    ELSIF v_beds = 1 THEN
        RAISE NOTICE 'Room % HAS ONE SPACE LEFT.', v_room_id;
    ELSE
        RAISE NOTICE 'Room % HAS SEVERAL SPACES AVAILABLE (% beds).', v_room_id, v_beds;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_day INT := 1;
BEGIN
    -- WHILE loop
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Hostel Inspection Day #%', v_day;
        v_day := v_day + 1;
    END LOOP;

    -- FOR loop
    FOR check_idx IN 1..3 LOOP
        RAISE NOTICE 'Executing Room Check #%', check_idx;
    END LOOP;
END $$;

-- 4. Create allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number INT,
    p_room_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_beds INT;
BEGIN
    IF p_student_number IS NULL THEN
        RAISE EXCEPTION 'Student number cannot be NULL or empty.';
    END IF;

    SELECT available_beds INTO v_beds FROM hostel_rooms WHERE room_id = p_room_id;

    IF v_beds IS NULL THEN
        RAISE EXCEPTION 'Room ID % does not exist.', p_room_id;
    END IF;

    IF v_beds < 1 THEN
        RAISE NOTICE 'Cannot allocate Bed in Room %. Room is FULL.', p_room_id;
    ELSE
        UPDATE hostel_rooms 
        SET available_beds = available_beds - 1 
        WHERE room_id = p_room_id;

        INSERT INTO allocations (student_number, room_id, status)
        VALUES (p_student_number, p_room_id, 'ACTIVE');

        RAISE NOTICE 'Student % allocated to Room % successfully.', p_student_number, p_room_id;
    END IF;
END $$;

-- 5. Call procedure for 2 valid allocations and 1 full room allocation
CALL allocate_room(20240001, 1);
CALL allocate_room(20240002, 2);
CALL allocate_room(20240003, 3); -- Full room request

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. Create check_out procedure & call twice
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_room_id INT;
BEGIN
    SELECT status, room_id INTO v_status, v_room_id
    FROM allocations WHERE allocation_id = p_allocation_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Allocation ID % not found.', p_allocation_id;
    ELSIF v_status = 'COMPLETED' THEN
        RAISE NOTICE 'Allocation ID % is ALREADY COMPLETED. No space freed.', p_allocation_id;
    ELSE
        UPDATE hostel_rooms 
        SET available_beds = available_beds + 1 
        WHERE room_id = v_room_id;

        UPDATE allocations 
        SET status = 'COMPLETED' 
        WHERE allocation_id = p_allocation_id;

        RAISE NOTICE 'Allocation ID % checked out successfully.', p_allocation_id;
    END IF;
END $$;

CALL check_out(1);
CALL check_out(1); -- Second call will not free another space

-- 7. Explicit cursor to display full or nearly full rooms
DO $$
DECLARE
    v_room RECORD;
    cur_full_rooms CURSOR FOR 
        SELECT room_id, room_number, available_beds 
        FROM hostel_rooms 
        WHERE available_beds <= 1;
BEGIN
    OPEN cur_full_rooms;
    LOOP
        FETCH cur_full_rooms INTO v_room;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full Room - ID: %, Number: %, Available Beds: %', 
                     v_room.room_id, v_room.room_number, v_room.available_beds;
    END LOOP;
    CLOSE cur_full_rooms;
END $$;

-- 8. Exception block for blank student number
DO $$
BEGIN
    CALL allocate_room(NULL, 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;

-- 9. Final query
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;