--SCENARIO 1 UNIVERSITY LIBRARY BOOK LOANS
DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;
DROP PROCEDURE IF EXISTS borrow_book(INT, INT, INT);
DROP PROCEDURE IF EXISTS return_book(INT);
--QUESTION 1
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);
CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES books(book_id),
    student_number INT NOT NULL,
    quantity INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ISSUED' -- 'ISSUED', 'RETURNED'
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 5),
('Operating Systems Concepts', 1),
('Computer Networks', 0);
DO $$
--QUESTION 2
DECLARE
    v_copies INT;
    v_book_id INT := 1; -- Check first book
BEGIN
    SELECT available_copies INTO v_copies FROM books WHERE book_id = v_book_id;
    
    IF v_copies = 0 THEN
        RAISE NOTICE 'Book is unavailable.', v_book_id;
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Book is low on copies (Copies: %).', v_book_id, v_copies;
    ELSE
        RAISE NOTICE 'Book % is sufficiently stocked (Copies: %).', v_book_id, v_copies;
    END IF;
END $$;
--QUESTION 3
DO $$
DECLARE
    v_reminder_count INT := 1;
BEGIN
    -- WHILE loop for overdue reminders
    WHILE v_reminder_count <= 3 LOOP
        RAISE NOTICE 'Overdue Reminder #%', v_reminder_count;
        v_reminder_count := v_reminder_count + 1;
    END LOOP;

    -- FOR loop for library shelf numbers
    FOR shelf_no IN 1..3 LOOP
        RAISE NOTICE 'Checking Library Shelf #%', shelf_no;
    END LOOP;
END $$;
--QUESTION 4
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INT,
    p_student_number INT,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid loan quantity: %. Quantity must be greater than zero.', p_quantity;
    END IF;

    SELECT available_copies INTO v_available FROM books WHERE book_id = p_book_id;

    IF v_available IS NULL THEN
        RAISE EXCEPTION 'Book ID % does not exist.', p_book_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE NOTICE 'Cannot borrow % copies of Book ID %. Only % available.', p_quantity, p_book_id, v_available;
    ELSE
        UPDATE books 
        SET available_copies = available_copies - p_quantity 
        WHERE book_id = p_book_id;

        INSERT INTO book_loans (book_id, student_number, quantity, status)
        VALUES (p_book_id, p_student_number, p_quantity, 'ISSUED');

        RAISE NOTICE 'Loan recorded successfully for Student %.', p_student_number;
    END IF;
END $$;
-- QUESTION 5
CALL borrow_book(1, 22001122, 2); -- Valid loan
CALL borrow_book(2, 22003344, 1); -- Valid loan
CALL borrow_book(3, 22005566, 2); -- Exceeds availability (0 available)


SELECT * FROM books;
SELECT * FROM book_loans;
--QUESTION 6
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_book_id INT;
    v_quantity INT;
BEGIN
    SELECT status, book_id, quantity INTO v_status, v_book_id, v_quantity
    FROM book_loans WHERE loan_id = p_loan_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Loan ID % not found.', p_loan_id;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan ID % has ALREADY been returned. No stock restored.', p_loan_id;
    ELSE
        UPDATE books 
        SET available_copies = available_copies + v_quantity 
        WHERE book_id = v_book_id;

        UPDATE book_loans 
        SET status = 'RETURNED' 
        WHERE loan_id = p_loan_id;

        RAISE NOTICE 'Loan ID % successfully returned.', p_loan_id;
    END IF;
END $$;

CALL return_book(1);
CALL return_book(1);
--QUESTION 7
DO $$
DECLARE
    v_book_record RECORD;
    cur_low_stock CURSOR FOR 
        SELECT book_id, title, available_copies 
        FROM books 
        WHERE available_copies <= 2;
BEGIN
    OPEN cur_low_stock;
    LOOP
        FETCH cur_low_stock INTO v_book_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Stock Book: ID %, Title: %, Copies Left: %', 
                     v_book_record.book_id, v_book_record.title, v_book_record.available_copies;
    END LOOP;
    CLOSE cur_low_stock;
END $$;
--QUESTION 8
DO $$
BEGIN
    CALL borrow_book(1, 22007788, 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;
--QUESTION 9
SELECT * FROM books;
SELECT * FROM book_loans;