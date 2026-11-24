-- ============================================================================
-- Project 13: Water Supply and Utility Billing Management System
-- Team      : NIRVAID JAIN (TCA2573025)
-- Course    : IBD312 - Basics Information Management (B.Tech Semester-III)
-- Engine    : MySQL 8.0+ (InnoDB)
-- ============================================================================
-- SYLLABUS ALIGNMENT (IBD312):
--   Unit 1 : Relational Databases, Data Modeling, Tables, Relational Concepts
--   Unit 2 : Simple SQL Queries, Joins, Scalar Functions, Column (Aggregate)
--            Functions & Grouping, UNION, Subqueries
--   Unit 3 : ER-to-Relational Design, Views (CO3), Integrity Rules
--            (PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT), Indexes
--   Unit 4 : Physical Implementation, Intermediate SQL, Maintaining Data
--            (INSERT/UPDATE/DELETE, Transactions: START TRANSACTION,
--            SAVEPOINT, COMMIT, ROLLBACK), Triggers (CO3), Stored Procedures
--
-- NOTE: Strictly stays within IBD312 syllabus (no CTEs, no window functions,
--       no JSON columns, no cursors, no partitioning).
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATABASE CREATION (Unit 1 & Unit 4 - Physical Implementation)
-- ============================================================================
DROP DATABASE IF EXISTS water_billing_db;
CREATE DATABASE water_billing_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE water_billing_db;

-- ============================================================================
-- SECTION 2: TABLE DEFINITIONS & INTEGRITY RULES (Unit 1 & Unit 3)
-- 12 Core Tables + 2 History Tables (Meter Replacements & Service Interruptions)
-- ============================================================================

-- 1. LOCALITY: Service zones / wards for locality-wise reporting
CREATE TABLE LOCALITY (
    locality_id      INT AUTO_INCREMENT PRIMARY KEY,
    locality_name    VARCHAR(100) NOT NULL UNIQUE,
    ward_code        VARCHAR(20)  NOT NULL UNIQUE,
    city             VARCHAR(60)  NOT NULL DEFAULT 'Noida',
    pincode          CHAR(6)      NOT NULL,
    zone_supervisor  VARCHAR(100) NOT NULL,
    CONSTRAINT chk_locality_pincode CHECK (CHAR_LENGTH(pincode) = 6)
) ENGINE=InnoDB;

-- 2. CUSTOMER: Registered water utility consumers
CREATE TABLE CUSTOMER (
    customer_id      INT AUTO_INCREMENT PRIMARY KEY,
    full_name        VARCHAR(100) NOT NULL,
    phone            VARCHAR(15)  NOT NULL UNIQUE,
    email            VARCHAR(100) UNIQUE,
    address_line     VARCHAR(200) NOT NULL,
    locality_id      INT          NOT NULL,
    customer_type    VARCHAR(20)  NOT NULL DEFAULT 'DOMESTIC',
    registered_on    DATE         NOT NULL,
    status           VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT fk_customer_locality
        FOREIGN KEY (locality_id) REFERENCES LOCALITY(locality_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_customer_type
        CHECK (customer_type IN ('DOMESTIC', 'COMMERCIAL', 'INDUSTRIAL')),
    CONSTRAINT chk_customer_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'))
) ENGINE=InnoDB;

-- 3. TARIFF: Consumption rate plans and late-payment penalty rules
CREATE TABLE TARIFF (
    tariff_id            INT AUTO_INCREMENT PRIMARY KEY,
    tariff_name          VARCHAR(60)   NOT NULL UNIQUE,
    customer_type        VARCHAR(20)   NOT NULL,
    rate_per_kl          DECIMAL(8,2)  NOT NULL,
    fixed_monthly_charge DECIMAL(8,2)  NOT NULL DEFAULT 50.00,
    late_penalty_rate    DECIMAL(5,2)  NOT NULL DEFAULT 5.00,
    free_limit_kl        INT           NOT NULL DEFAULT 0,
    effective_from       DATE          NOT NULL,
    is_active            TINYINT       NOT NULL DEFAULT 1,
    CONSTRAINT chk_tariff_customer_type
        CHECK (customer_type IN ('DOMESTIC', 'COMMERCIAL', 'INDUSTRIAL')),
    CONSTRAINT chk_tariff_rates
        CHECK (rate_per_kl >= 0 AND fixed_monthly_charge >= 0
               AND late_penalty_rate >= 0 AND free_limit_kl >= 0),
    CONSTRAINT chk_tariff_active
        CHECK (is_active IN (0, 1))
) ENGINE=InnoDB;

-- 4. SERVICE_CONNECTION: Water supply connection assigned to a customer
CREATE TABLE SERVICE_CONNECTION (
    connection_id     INT AUTO_INCREMENT PRIMARY KEY,
    connection_no     VARCHAR(30) NOT NULL UNIQUE,
    customer_id       INT         NOT NULL,
    locality_id       INT         NOT NULL,
    tariff_id         INT         NOT NULL,
    pipe_diameter_mm  INT         NOT NULL DEFAULT 15,
    connection_date   DATE        NOT NULL,
    connection_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT fk_conn_customer
        FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_conn_locality
        FOREIGN KEY (locality_id) REFERENCES LOCALITY(locality_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_conn_tariff
        FOREIGN KEY (tariff_id) REFERENCES TARIFF(tariff_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_conn_pipe
        CHECK (pipe_diameter_mm IN (15, 20, 25, 40, 50)),
    CONSTRAINT chk_conn_status
        CHECK (connection_status IN ('ACTIVE', 'DISCONNECTED', 'SUSPENDED'))
) ENGINE=InnoDB;

-- 5. WATER_METER: Physical meter installed on a service connection
CREATE TABLE WATER_METER (
    meter_id          INT AUTO_INCREMENT PRIMARY KEY,
    meter_serial_no   VARCHAR(40) NOT NULL UNIQUE,
    connection_id     INT         NOT NULL,
    manufacturer      VARCHAR(60) NOT NULL,
    installed_on      DATE        NOT NULL,
    removed_on        DATE        NULL,
    initial_reading   INT         NOT NULL DEFAULT 0,
    meter_status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT fk_meter_connection
        FOREIGN KEY (connection_id) REFERENCES SERVICE_CONNECTION(connection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_meter_reading_init CHECK (initial_reading >= 0),
    CONSTRAINT chk_meter_dates CHECK (removed_on IS NULL OR removed_on >= installed_on),
    CONSTRAINT chk_meter_status
        CHECK (meter_status IN ('ACTIVE', 'FAULTY', 'REPLACED'))
) ENGINE=InnoDB;

-- 6. METER_REPLACEMENT_HISTORY: Tracks physical meter replacements
-- Note: Distinct old/new meter validation is enforced via trigger
--       (trg_before_meter_replacement_insert) to comply with MySQL 8.0 FK rules.
CREATE TABLE METER_REPLACEMENT_HISTORY (
    replacement_id      INT AUTO_INCREMENT PRIMARY KEY,
    connection_id       INT          NOT NULL,
    old_meter_id        INT          NOT NULL,
    new_meter_id        INT          NOT NULL,
    replacement_date    DATE         NOT NULL,
    old_final_reading   INT          NOT NULL,
    new_initial_reading INT          NOT NULL DEFAULT 0,
    reason              VARCHAR(150) NOT NULL,
    replaced_by         VARCHAR(80)  NOT NULL,
    CONSTRAINT fk_repl_conn
        FOREIGN KEY (connection_id) REFERENCES SERVICE_CONNECTION(connection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_repl_old_meter
        FOREIGN KEY (old_meter_id) REFERENCES WATER_METER(meter_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_repl_new_meter
        FOREIGN KEY (new_meter_id) REFERENCES WATER_METER(meter_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_repl_readings CHECK (old_final_reading >= 0 AND new_initial_reading >= 0)
) ENGINE=InnoDB;

-- 7. METER_READING: Monthly water meter readings (in kiloliters / KL)
CREATE TABLE METER_READING (
    reading_id       INT AUTO_INCREMENT PRIMARY KEY,
    connection_id    INT         NOT NULL,
    meter_id         INT         NOT NULL,
    billing_month    CHAR(7)     NOT NULL, -- Format: 'YYYY-MM'
    reading_date     DATE        NOT NULL,
    previous_reading INT         NOT NULL,
    current_reading  INT         NOT NULL,
    units_consumed   INT         NOT NULL DEFAULT 0,
    reading_status   VARCHAR(20) NOT NULL DEFAULT 'VERIFIED',
    recorded_by      VARCHAR(80) NOT NULL,
    CONSTRAINT fk_reading_conn
        FOREIGN KEY (connection_id) REFERENCES SERVICE_CONNECTION(connection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reading_meter
        FOREIGN KEY (meter_id) REFERENCES WATER_METER(meter_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_reading_conn_month UNIQUE (connection_id, billing_month),
    CONSTRAINT chk_reading_values
        CHECK (previous_reading >= 0 AND current_reading >= previous_reading AND units_consumed >= 0),
    CONSTRAINT chk_reading_status
        CHECK (reading_status IN ('PENDING', 'VERIFIED', 'CORRECTED'))
) ENGINE=InnoDB;

-- 8. BILL: Monthly utility bill header (one bill per connection per month)
CREATE TABLE BILL (
    bill_id          INT AUTO_INCREMENT PRIMARY KEY,
    bill_number      VARCHAR(30)   NOT NULL UNIQUE,
    connection_id    INT           NOT NULL,
    reading_id       INT           NOT NULL UNIQUE,
    tariff_id        INT           NOT NULL,
    billing_month    CHAR(7)       NOT NULL,
    bill_date        DATE          NOT NULL,
    due_date         DATE          NOT NULL,
    units_billed     INT           NOT NULL,
    total_amount     DECIMAL(10,2) NOT NULL,
    amount_paid      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    bill_status      VARCHAR(20)   NOT NULL DEFAULT 'UNPAID',
    CONSTRAINT fk_bill_conn
        FOREIGN KEY (connection_id) REFERENCES SERVICE_CONNECTION(connection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_bill_reading
        FOREIGN KEY (reading_id) REFERENCES METER_READING(reading_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_bill_tariff
        FOREIGN KEY (tariff_id) REFERENCES TARIFF(tariff_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_bill_conn_month UNIQUE (connection_id, billing_month),
    CONSTRAINT chk_bill_dates CHECK (due_date >= bill_date),
    CONSTRAINT chk_bill_amounts CHECK (units_billed >= 0 AND total_amount >= 0 AND amount_paid >= 0),
    CONSTRAINT chk_bill_status
        CHECK (bill_status IN ('UNPAID', 'PARTIAL', 'PAID', 'OVERDUE', 'CANCELLED'))
) ENGINE=InnoDB;

-- 9. BILL_DETAIL: Itemized bill components (water charge, fixed fee, penalty, adjustments)
CREATE TABLE BILL_DETAIL (
    detail_id        INT AUTO_INCREMENT PRIMARY KEY,
    bill_id          INT           NOT NULL,
    charge_type      VARCHAR(30)   NOT NULL,
    description      VARCHAR(150)  NOT NULL,
    amount           DECIMAL(10,2) NOT NULL, -- Can be negative for downward corrections
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_detail_bill
        FOREIGN KEY (bill_id) REFERENCES BILL(bill_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_detail_type
        CHECK (charge_type IN ('WATER_CHARGE', 'FIXED_CHARGE', 'LATE_PENALTY', 'CORRECTION_ADJUSTMENT'))
) ENGINE=InnoDB;

-- 10. PAYMENT: Customer bill payments, refunds, and financial adjustments
CREATE TABLE PAYMENT (
    payment_id       INT AUTO_INCREMENT PRIMARY KEY,
    bill_id          INT           NOT NULL,
    payment_date     DATE          NOT NULL,
    amount           DECIMAL(10,2) NOT NULL,
    payment_type     VARCHAR(20)   NOT NULL DEFAULT 'PAYMENT',
    payment_mode     VARCHAR(20)   NOT NULL,
    reference_no     VARCHAR(60)   NOT NULL UNIQUE,
    remarks          VARCHAR(150)  NULL,
    CONSTRAINT fk_payment_bill
        FOREIGN KEY (bill_id) REFERENCES BILL(bill_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT chk_payment_type
        CHECK (payment_type IN ('PAYMENT', 'REFUND', 'ADJUSTMENT')),
    CONSTRAINT chk_payment_mode
        CHECK (payment_mode IN ('UPI', 'NETBANKING', 'CARD', 'CASH', 'CHEQUE', 'AUTO_REFUND'))
) ENGINE=InnoDB;

-- 11. COMPLAINT: Customer complaints (leakage, low pressure, faulty meter, billing)
CREATE TABLE COMPLAINT (
    complaint_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer_id      INT          NOT NULL,
    connection_id    INT          NOT NULL,
    complaint_type   VARCHAR(30)  NOT NULL,
    description      VARCHAR(250) NOT NULL,
    filed_date       DATE         NOT NULL,
    resolved_date    DATE         NULL,
    priority         VARCHAR(10)  NOT NULL DEFAULT 'MEDIUM',
    complaint_status VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    CONSTRAINT fk_complaint_customer
        FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_complaint_conn
        FOREIGN KEY (connection_id) REFERENCES SERVICE_CONNECTION(connection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_complaint_type
        CHECK (complaint_type IN ('LEAKAGE', 'LOW_PRESSURE', 'NO_SUPPLY', 'FAULTY_METER', 'BILLING_ISSUE')),
    CONSTRAINT chk_complaint_priority
        CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT chk_complaint_status
        CHECK (complaint_status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    CONSTRAINT chk_complaint_dates
        CHECK (resolved_date IS NULL OR resolved_date >= filed_date)
) ENGINE=InnoDB;

-- 12. MAINTENANCE_REQUEST: Work orders dispatched to resolve complaints or scheduled upkeep
CREATE TABLE MAINTENANCE_REQUEST (
    request_id        INT AUTO_INCREMENT PRIMARY KEY,
    complaint_id      INT           NULL,
    connection_id     INT           NOT NULL,
    assigned_team     VARCHAR(80)   NOT NULL,
    scheduled_date    DATE          NOT NULL,
    completed_date    DATE          NULL,
    maintenance_cost  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    work_status       VARCHAR(20)   NOT NULL DEFAULT 'SCHEDULED',
    work_notes        VARCHAR(200)  NULL,
    CONSTRAINT fk_maint_complaint
        FOREIGN KEY (complaint_id) REFERENCES COMPLAINT(complaint_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_maint_conn
        FOREIGN KEY (connection_id) REFERENCES SERVICE_CONNECTION(connection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_maint_cost CHECK (maintenance_cost >= 0),
    CONSTRAINT chk_maint_status
        CHECK (work_status IN ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT chk_maint_dates
        CHECK (completed_date IS NULL OR completed_date >= scheduled_date)
) ENGINE=InnoDB;

-- 13. SERVICE_INTERRUPTION: History of planned & unplanned water supply interruptions
CREATE TABLE SERVICE_INTERRUPTION (
    interruption_id   INT AUTO_INCREMENT PRIMARY KEY,
    locality_id       INT          NOT NULL,
    start_time        DATETIME     NOT NULL,
    end_time          DATETIME     NULL,
    interruption_type VARCHAR(20)  NOT NULL,
    reason            VARCHAR(200) NOT NULL,
    CONSTRAINT fk_interrupt_locality
        FOREIGN KEY (locality_id) REFERENCES LOCALITY(locality_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_interrupt_type
        CHECK (interruption_type IN ('PLANNED_MAINTENANCE', 'PIPE_BURST', 'POWER_OUTAGE', 'EMERGENCY')),
    CONSTRAINT chk_interrupt_time
        CHECK (end_time IS NULL OR end_time >= start_time)
) ENGINE=InnoDB;

-- 14. AUDIT_LOG: Automatic audit trail for readings, bills, payments, and complaints
CREATE TABLE AUDIT_LOG (
    log_id           INT AUTO_INCREMENT PRIMARY KEY,
    table_name       VARCHAR(50)  NOT NULL,
    record_id        INT          NOT NULL,
    action_type      VARCHAR(20)  NOT NULL,
    action_details   VARCHAR(300) NOT NULL,
    logged_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_action
        CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE', 'BILL_GENERATED', 'CORRECTION', 'REFUND'))
) ENGINE=InnoDB;

-- ============================================================================
-- SECTION 3: INDEXES (Unit 3 - Indexes for Fast Retrieval & Reporting)
-- ============================================================================
CREATE INDEX idx_customer_locality      ON CUSTOMER(locality_id);
CREATE INDEX idx_conn_customer          ON SERVICE_CONNECTION(customer_id);
CREATE INDEX idx_conn_locality          ON SERVICE_CONNECTION(locality_id);
CREATE INDEX idx_meter_conn_status      ON WATER_METER(connection_id, meter_status);
CREATE INDEX idx_reading_month_units    ON METER_READING(billing_month, units_consumed);
CREATE INDEX idx_bill_status_due        ON BILL(bill_status, due_date);
CREATE INDEX idx_bill_month             ON BILL(billing_month);
CREATE INDEX idx_payment_bill_date      ON PAYMENT(bill_id, payment_date);
CREATE INDEX idx_complaint_status_type  ON COMPLAINT(complaint_status, complaint_type);
CREATE INDEX idx_interrupt_locality     ON SERVICE_INTERRUPTION(locality_id, start_time);
CREATE INDEX idx_audit_table_record     ON AUDIT_LOG(table_name, record_id);

-- ============================================================================
-- SECTION 4: TRIGGERS (CO3 - Triggers & Unit 4 - Maintaining Data)
-- ============================================================================
DELIMITER //

-- Trigger 1: Ensure old_meter_id and new_meter_id are distinct on meter replacement
CREATE TRIGGER trg_before_meter_replacement_insert
BEFORE INSERT ON METER_REPLACEMENT_HISTORY
FOR EACH ROW
BEGIN
    IF NEW.old_meter_id = NEW.new_meter_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid replacement: old_meter_id and new_meter_id must be different.';
    END IF;
END //

-- Trigger 2: Auto-calculate units_consumed and validate meter readings on INSERT
CREATE TRIGGER trg_before_meter_reading_insert
BEFORE INSERT ON METER_READING
FOR EACH ROW
BEGIN
    IF NEW.current_reading < NEW.previous_reading THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid meter reading: current_reading cannot be less than previous_reading.';
    END IF;
    SET NEW.units_consumed = NEW.current_reading - NEW.previous_reading;
END //

-- Trigger 3: Recompute units_consumed and log reading corrections on UPDATE
CREATE TRIGGER trg_before_meter_reading_update
BEFORE UPDATE ON METER_READING
FOR EACH ROW
BEGIN
    IF NEW.current_reading < NEW.previous_reading THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid correction: current_reading cannot be less than previous_reading.';
    END IF;
    SET NEW.units_consumed = NEW.current_reading - NEW.previous_reading;
END //

CREATE TRIGGER trg_after_meter_reading_update
AFTER UPDATE ON METER_READING
FOR EACH ROW
BEGIN
    IF OLD.current_reading <> NEW.current_reading THEN
        INSERT INTO AUDIT_LOG (table_name, record_id, action_type, action_details)
        VALUES (
            'METER_READING',
            NEW.reading_id,
            'CORRECTION',
            CONCAT('Reading corrected from ', OLD.current_reading,
                   ' to ', NEW.current_reading,
                   ' KL (Units: ', OLD.units_consumed, ' -> ', NEW.units_consumed, ' KL)')
        );
    END IF;
END //

-- Trigger 4: Log every payment or refund transaction into AUDIT_LOG
CREATE TRIGGER trg_after_payment_insert
AFTER INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (table_name, record_id, action_type, action_details)
    VALUES (
        'PAYMENT',
        NEW.payment_id,
        IF(NEW.payment_type = 'REFUND', 'REFUND', 'INSERT'),
        CONCAT(NEW.payment_type, ' of Rs. ', NEW.amount,
               ' for Bill #', NEW.bill_id, ' via ', NEW.payment_mode,
               ' (Ref: ', NEW.reference_no, ')')
    );
END //

-- Trigger 5: Log complaint status updates into AUDIT_LOG
CREATE TRIGGER trg_after_complaint_update
AFTER UPDATE ON COMPLAINT
FOR EACH ROW
BEGIN
    IF OLD.complaint_status <> NEW.complaint_status THEN
        INSERT INTO AUDIT_LOG (table_name, record_id, action_type, action_details)
        VALUES (
            'COMPLAINT',
            NEW.complaint_id,
            'UPDATE',
            CONCAT('Complaint status changed from ', OLD.complaint_status,
                   ' to ', NEW.complaint_status)
        );
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 5: STORED PROCEDURES & TRANSACTION MANAGEMENT (Unit 4)
-- ============================================================================
DELIMITER //

-- Procedure 1: Calculate & generate a consumption-based monthly bill
-- Applies tariff rate, free limit, fixed monthly charge, and overdue penalty
-- if the connection has any prior unpaid/overdue bills.
CREATE PROCEDURE sp_generate_monthly_bill (
    IN p_reading_id INT,
    IN p_bill_date  DATE
)
BEGIN
    DECLARE v_connection_id      INT;
    DECLARE v_tariff_id          INT;
    DECLARE v_billing_month      CHAR(7);
    DECLARE v_units              INT;
    DECLARE v_rate_per_kl        DECIMAL(8,2);
    DECLARE v_fixed_charge       DECIMAL(8,2);
    DECLARE v_penalty_rate       DECIMAL(5,2);
    DECLARE v_free_limit         INT;
    DECLARE v_billable_units     INT;
    DECLARE v_water_charge       DECIMAL(10,2);
    DECLARE v_prior_overdue_amt  DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_penalty_amount     DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_total_amount       DECIMAL(10,2);
    DECLARE v_bill_id            INT;
    DECLARE v_existing_bill      INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Check if a bill already exists for this reading
    SELECT COUNT(*) INTO v_existing_bill
    FROM BILL
    WHERE reading_id = p_reading_id;

    IF v_existing_bill > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Bill already generated for this meter reading.';
    END IF;

    -- Fetch reading and connection tariff details
    SELECT mr.connection_id, mr.billing_month, mr.units_consumed,
           sc.tariff_id, t.rate_per_kl, t.fixed_monthly_charge,
           t.late_penalty_rate, t.free_limit_kl
    INTO v_connection_id, v_billing_month, v_units,
         v_tariff_id, v_rate_per_kl, v_fixed_charge,
         v_penalty_rate, v_free_limit
    FROM METER_READING mr
    INNER JOIN SERVICE_CONNECTION sc ON mr.connection_id = sc.connection_id
    INNER JOIN TARIFF t ON sc.tariff_id = t.tariff_id
    WHERE mr.reading_id = p_reading_id;

    -- Calculate billable units after applying free limit
    IF v_units > v_free_limit THEN
        SET v_billable_units = v_units - v_free_limit;
    ELSE
        SET v_billable_units = 0;
    END IF;

    SET v_water_charge = ROUND(v_billable_units * v_rate_per_kl, 2);

    -- Check for prior unpaid/overdue balance on this connection to apply penalty
    SELECT IFNULL(SUM(total_amount - amount_paid), 0.00)
    INTO v_prior_overdue_amt
    FROM BILL
    WHERE connection_id = v_connection_id
      AND bill_status IN ('UNPAID', 'PARTIAL', 'OVERDUE')
      AND due_date < p_bill_date;

    IF v_prior_overdue_amt > 0 THEN
        SET v_penalty_amount = ROUND(v_prior_overdue_amt * (v_penalty_rate / 100.0), 2);
    END IF;

    SET v_total_amount = ROUND(v_water_charge + v_fixed_charge + v_penalty_amount, 2);

    -- Insert Bill Header
    INSERT INTO BILL (
        bill_number, connection_id, reading_id, tariff_id,
        billing_month, bill_date, due_date, units_billed,
        total_amount, amount_paid, bill_status
    )
    VALUES (
        CONCAT('BILL-', REPLACE(v_billing_month, '-', ''), '-', LPAD(v_connection_id, 4, '0')),
        v_connection_id, p_reading_id, v_tariff_id,
        v_billing_month, p_bill_date, DATE_ADD(p_bill_date, INTERVAL 15 DAY),
        v_units, v_total_amount, 0.00, 'UNPAID'
    );

    SET v_bill_id = LAST_INSERT_ID();

    -- Insert Itemized Bill Details
    INSERT INTO BILL_DETAIL (bill_id, charge_type, description, amount)
    VALUES (
        v_bill_id, 'WATER_CHARGE',
        CONCAT('Water consumption: ', v_billable_units, ' billable KL @ Rs. ', v_rate_per_kl, '/KL'),
        v_water_charge
    );

    INSERT INTO BILL_DETAIL (bill_id, charge_type, description, amount)
    VALUES (
        v_bill_id, 'FIXED_CHARGE',
        'Monthly fixed meter & service maintenance fee',
        v_fixed_charge
    );

    IF v_penalty_amount > 0 THEN
        INSERT INTO BILL_DETAIL (bill_id, charge_type, description, amount)
        VALUES (
            v_bill_id, 'LATE_PENALTY',
            CONCAT('Late payment penalty @ ', v_penalty_rate, '% on prior overdue Rs. ', v_prior_overdue_amt),
            v_penalty_amount
        );
    END IF;

    INSERT INTO AUDIT_LOG (table_name, record_id, action_type, action_details)
    VALUES (
        'BILL', v_bill_id, 'BILL_GENERATED',
        CONCAT('Generated Bill #', v_bill_id, ' for ', v_billing_month,
               ' | Units: ', v_units, ' KL | Total: Rs. ', v_total_amount)
    );

    COMMIT;
END //

-- Procedure 2: Record a customer payment and update bill balance/status safely
CREATE PROCEDURE sp_record_payment (
    IN p_bill_id      INT,
    IN p_payment_date DATE,
    IN p_amount       DECIMAL(10,2),
    IN p_payment_mode VARCHAR(20),
    IN p_reference_no VARCHAR(60)
)
BEGIN
    DECLARE v_total_amount  DECIMAL(10,2);
    DECLARE v_amount_paid   DECIMAL(10,2);
    DECLARE v_new_paid      DECIMAL(10,2);
    DECLARE v_balance_due   DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Lock the bill row to prevent concurrent payment anomalies
    SELECT total_amount, amount_paid
    INTO v_total_amount, v_amount_paid
    FROM BILL
    WHERE bill_id = p_bill_id
    FOR UPDATE;

    SET v_balance_due = v_total_amount - v_amount_paid;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment amount must be greater than zero.';
    END IF;

    IF p_amount > v_balance_due THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment exceeds outstanding balance due on this bill.';
    END IF;

    INSERT INTO PAYMENT (bill_id, payment_date, amount, payment_type, payment_mode, reference_no, remarks)
    VALUES (p_bill_id, p_payment_date, p_amount, 'PAYMENT', p_payment_mode, p_reference_no, 'Regular bill payment');

    SET v_new_paid = ROUND(v_amount_paid + p_amount, 2);

    UPDATE BILL
    SET amount_paid = v_new_paid,
        bill_status = IF(v_new_paid >= v_total_amount, 'PAID', 'PARTIAL')
    WHERE bill_id = p_bill_id;

    COMMIT;
END //

-- Procedure 3 (ADVANCED CHALLENGE):
-- Atomically handles meter-reading correction, bill recalculation, and payment
-- adjustment/refund WITHOUT creating duplicate bills or inconsistent ledger rows.
CREATE PROCEDURE sp_correct_reading_and_recalculate_bill (
    IN p_reading_id                INT,
    IN p_corrected_current_reading INT,
    IN p_correction_date           DATE,
    IN p_reason                    VARCHAR(150)
)
BEGIN
    DECLARE v_prev_reading      INT;
    DECLARE v_new_units         INT;
    DECLARE v_bill_id           INT;
    DECLARE v_tariff_id         INT;
    DECLARE v_old_total         DECIMAL(10,2);
    DECLARE v_amount_paid       DECIMAL(10,2);
    DECLARE v_rate_per_kl       DECIMAL(8,2);
    DECLARE v_fixed_charge      DECIMAL(8,2);
    DECLARE v_free_limit        INT;
    DECLARE v_existing_penalty  DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_billable_units    INT;
    DECLARE v_new_water_charge  DECIMAL(10,2);
    DECLARE v_new_total         DECIMAL(10,2);
    DECLARE v_delta_amount      DECIMAL(10,2);
    DECLARE v_refund_amount     DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_new_status        VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Lock the meter reading row
    SELECT previous_reading
    INTO v_prev_reading
    FROM METER_READING
    WHERE reading_id = p_reading_id
    FOR UPDATE;

    IF p_corrected_current_reading < v_prev_reading THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Corrected reading cannot be less than previous reading.';
    END IF;

    -- 2. Lock the associated bill row (prevents duplicate or racing recalculations)
    SELECT b.bill_id, b.tariff_id, b.total_amount, b.amount_paid,
           t.rate_per_kl, t.fixed_monthly_charge, t.free_limit_kl
    INTO v_bill_id, v_tariff_id, v_old_total, v_amount_paid,
         v_rate_per_kl, v_fixed_charge, v_free_limit
    FROM BILL b
    INNER JOIN TARIFF t ON b.tariff_id = t.tariff_id
    WHERE b.reading_id = p_reading_id
    FOR UPDATE;

    -- 3. Update METER_READING in place (trigger recalculates units_consumed & logs audit)
    UPDATE METER_READING
    SET current_reading = p_corrected_current_reading,
        reading_status  = 'CORRECTED'
    WHERE reading_id = p_reading_id;

    SET v_new_units = p_corrected_current_reading - v_prev_reading;

    -- 4. Recalculate bill total preserving any originally applied late penalty
    SELECT IFNULL(SUM(amount), 0.00)
    INTO v_existing_penalty
    FROM BILL_DETAIL
    WHERE bill_id = v_bill_id
      AND charge_type = 'LATE_PENALTY';

    IF v_new_units > v_free_limit THEN
        SET v_billable_units = v_new_units - v_free_limit;
    ELSE
        SET v_billable_units = 0;
    END IF;

    SET v_new_water_charge = ROUND(v_billable_units * v_rate_per_kl, 2);
    SET v_new_total        = ROUND(v_new_water_charge + v_fixed_charge + v_existing_penalty, 2);
    SET v_delta_amount     = ROUND(v_new_total - v_old_total, 2);

    -- 5. Record exact adjustment delta in BILL_DETAIL (keeps SUM(BILL_DETAIL) = BILL.total_amount)
    IF v_delta_amount <> 0.00 THEN
        INSERT INTO BILL_DETAIL (bill_id, charge_type, description, amount)
        VALUES (
            v_bill_id,
            'CORRECTION_ADJUSTMENT',
            CONCAT('Reading correction adjustment (', p_reason, '): New units = ', v_new_units, ' KL'),
            v_delta_amount
        );
    END IF;

    -- 6. Reconcile payments & issue automatic refund if customer overpaid
    IF v_amount_paid > v_new_total THEN
        SET v_refund_amount = ROUND(v_amount_paid - v_new_total, 2);

        INSERT INTO PAYMENT (
            bill_id, payment_date, amount, payment_type, payment_mode, reference_no, remarks
        )
        VALUES (
            v_bill_id,
            p_correction_date,
            v_refund_amount,
            'REFUND',
            'AUTO_REFUND',
            CONCAT('REF-B', v_bill_id, '-R', p_reading_id, '-', UUID_SHORT()),
            CONCAT('Auto-refund for meter reading correction: ', p_reason)
        );

        SET v_amount_paid = v_new_total;
        SET v_new_status  = 'PAID';
    ELSEIF v_amount_paid = v_new_total THEN
        SET v_new_status = 'PAID';
    ELSEIF v_amount_paid > 0 THEN
        SET v_new_status = 'PARTIAL';
    ELSE
        SET v_new_status = 'UNPAID';
    END IF;

    -- 7. Update the existing BILL row in place (zero duplicate bills!)
    UPDATE BILL
    SET units_billed = v_new_units,
        total_amount = v_new_total,
        amount_paid  = v_amount_paid,
        bill_status  = v_new_status
    WHERE bill_id = v_bill_id;

    -- 8. Log complete financial reconciliation in AUDIT_LOG
    INSERT INTO AUDIT_LOG (table_name, record_id, action_type, action_details)
    VALUES (
        'BILL', v_bill_id, 'CORRECTION',
        CONCAT('Recalculated Bill #', v_bill_id, ': Old=Rs.', v_old_total,
               ', New=Rs.', v_new_total, ', Delta=Rs.', v_delta_amount,
               ', Refund=Rs.', v_refund_amount, ', Status=', v_new_status)
    );

    COMMIT;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 6: VIEWS (Unit 3 & CO3 - Views in Databases)
-- ============================================================================

-- View 1: Complete customer, connection, locality, tariff, and active meter overview
CREATE VIEW vw_customer_connections AS
SELECT
    c.customer_id,
    c.full_name,
    c.customer_type,
    l.locality_name,
    l.ward_code,
    sc.connection_id,
    sc.connection_no,
    sc.connection_status,
    t.tariff_name,
    t.rate_per_kl,
    wm.meter_serial_no
FROM CUSTOMER c
INNER JOIN SERVICE_CONNECTION sc ON c.customer_id = sc.customer_id
INNER JOIN LOCALITY l            ON sc.locality_id = l.locality_id
INNER JOIN TARIFF t              ON sc.tariff_id = t.tariff_id
LEFT JOIN WATER_METER wm         ON sc.connection_id = wm.connection_id
                                 AND wm.meter_status = 'ACTIVE';

-- View 2: Outstanding bills with balance due
CREATE VIEW vw_outstanding_bills AS
SELECT
    b.bill_id,
    b.bill_number,
    c.full_name,
    l.locality_name,
    b.billing_month,
    b.due_date,
    b.total_amount,
    b.amount_paid,
    (b.total_amount - b.amount_paid) AS balance_due,
    b.bill_status
FROM BILL b
INNER JOIN SERVICE_CONNECTION sc ON b.connection_id = sc.connection_id
INNER JOIN CUSTOMER c            ON sc.customer_id = c.customer_id
INNER JOIN LOCALITY l            ON sc.locality_id = l.locality_id
WHERE b.bill_status IN ('UNPAID', 'PARTIAL', 'OVERDUE');

-- View 3: Locality-wise consumption and revenue summary
CREATE VIEW vw_locality_consumption_revenue AS
SELECT
    l.locality_id,
    l.locality_name,
    l.ward_code,
    COUNT(DISTINCT sc.connection_id)                  AS total_connections,
    IFNULL(SUM(b.units_billed), 0)                    AS total_units_kl,
    IFNULL(SUM(b.total_amount), 0.00)                 AS total_billed_rs,
    IFNULL(SUM(b.amount_paid), 0.00)                  AS total_collected_rs,
    IFNULL(SUM(b.total_amount - b.amount_paid), 0.00) AS total_pending_rs
FROM LOCALITY l
LEFT JOIN SERVICE_CONNECTION sc ON l.locality_id = sc.locality_id
LEFT JOIN BILL b                ON sc.connection_id = b.connection_id
GROUP BY l.locality_id, l.locality_name, l.ward_code;

-- View 4: Active leakage & maintenance complaint tracker
CREATE VIEW vw_active_maintenance_complaints AS
SELECT
    cp.complaint_id,
    c.full_name,
    l.locality_name,
    cp.complaint_type,
    cp.priority,
    cp.filed_date,
    cp.complaint_status,
    mr.request_id,
    mr.assigned_team,
    mr.scheduled_date,
    mr.work_status
FROM COMPLAINT cp
INNER JOIN CUSTOMER c             ON cp.customer_id = c.customer_id
INNER JOIN SERVICE_CONNECTION sc  ON cp.connection_id = sc.connection_id
INNER JOIN LOCALITY l             ON sc.locality_id = l.locality_id
LEFT JOIN MAINTENANCE_REQUEST mr  ON cp.complaint_id = mr.complaint_id
WHERE cp.complaint_status IN ('OPEN', 'IN_PROGRESS');

-- ============================================================================
-- SECTION 7: SAMPLE DATA POPULATION (Unit 4 - Maintaining Data)
-- ============================================================================

-- 7.1 Localities
INSERT INTO LOCALITY (locality_name, ward_code, city, pincode, zone_supervisor) VALUES
('Sector 15 Residential', 'WARD-01', 'Noida', '201301', 'Rajesh Sharma'),
('Sector 62 Tech Park',   'WARD-02', 'Noida', '201309', 'Meena Verma'),
('Indirapuram Greens',    'WARD-03', 'Ghaziabad', '201014', 'Anil Kapoor'),
('Okhla Industrial Area', 'WARD-04', 'New Delhi', '110020', 'Suresh Nair');

-- 7.2 Tariffs
INSERT INTO TARIFF (tariff_name, customer_type, rate_per_kl, fixed_monthly_charge, late_penalty_rate, free_limit_kl, effective_from) VALUES
('Domestic Standard',   'DOMESTIC',   12.00,  50.00,  5.00, 5, '2026-01-01'),
('Commercial Regular',  'COMMERCIAL', 28.00, 150.00,  8.00, 0, '2026-01-01'),
('Industrial Heavy',    'INDUSTRIAL', 45.00, 400.00, 10.00, 0, '2026-01-01');

-- 7.3 Customers
INSERT INTO CUSTOMER (full_name, phone, email, address_line, locality_id, customer_type, registered_on) VALUES
('Aarav Mehta',         '9810011101', 'aarav.mehta@example.com',    'B-104, Sector 15',       1, 'DOMESTIC',   '2025-04-10'),
('Priya Singh',         '9810011102', 'priya.singh@example.com',    'C-209, Sector 15',       1, 'DOMESTIC',   '2025-05-12'),
('Apex Cafe & Bakery',  '9810011103', 'billing@apexcafe.example',   'Plot 12, Sector 62',     2, 'COMMERCIAL', '2025-06-01'),
('Rohan Deshmukh',      '9810011104', 'rohan.d@example.com',        'Flat 502, Indirapuram',  3, 'DOMESTIC',   '2025-07-18'),
('Kaveri Textiles Ltd', '9810011105', 'ops@kaveritextiles.example', 'Unit 8, Okhla Phase II', 4, 'INDUSTRIAL', '2025-03-22'),
('Neha Gupta',          '9810011106', 'neha.gupta@example.com',     'A-45, Indirapuram',      3, 'DOMESTIC',   '2025-08-05');

-- 7.4 Service Connections
INSERT INTO SERVICE_CONNECTION (connection_no, customer_id, locality_id, tariff_id, pipe_diameter_mm, connection_date) VALUES
('CONN-1001', 1, 1, 1, 15, '2025-04-12'),
('CONN-1002', 2, 1, 1, 15, '2025-05-15'),
('CONN-1003', 3, 2, 2, 25, '2025-06-05'),
('CONN-1004', 4, 3, 1, 15, '2025-07-20'),
('CONN-1005', 5, 4, 3, 50, '2025-03-25'),
('CONN-1006', 6, 3, 1, 15, '2025-08-08');

-- 7.5 Water Meters (includes one replaced meter on CONN-1002)
INSERT INTO WATER_METER (meter_serial_no, connection_id, manufacturer, installed_on, removed_on, initial_reading, meter_status) VALUES
('WM-2025-001', 1, 'Kranti',  '2025-04-12', NULL,         0, 'ACTIVE'),
('WM-2025-002', 2, 'Kranti',  '2025-05-15', '2026-09-20', 0, 'REPLACED'),
('WM-2026-009', 2, 'Itron',   '2026-09-20', NULL,         0, 'ACTIVE'),
('WM-2025-003', 3, 'Itron',   '2025-06-05', NULL,         0, 'ACTIVE'),
('WM-2025-004', 4, 'Zenner',  '2025-07-20', NULL,         0, 'ACTIVE'),
('WM-2025-005', 5, 'Zenner',  '2025-03-25', NULL,         0, 'ACTIVE'),
('WM-2025-006', 6, 'Kranti',  '2025-08-08', NULL,         0, 'ACTIVE');

-- 7.6 Meter Replacement History
INSERT INTO METER_REPLACEMENT_HISTORY (
    connection_id, old_meter_id, new_meter_id, replacement_date,
    old_final_reading, new_initial_reading, reason, replaced_by
) VALUES
(2, 2, 3, '2026-09-20', 410, 0, 'Dial stuck / faulty impeller', 'Tech Team A - Vikram');

-- 7.7 Monthly Meter Readings (Oct 2026 & Nov 2026)
-- Trigger automatically computes units_consumed = current_reading - previous_reading
INSERT INTO METER_READING (connection_id, meter_id, billing_month, reading_date, previous_reading, current_reading, recorded_by) VALUES
-- October 2026
(1, 1, '2026-10', '2026-10-31', 120, 145, 'Reader-01'), -- 25 KL (Domestic normal)
(2, 3, '2026-10', '2026-10-31',   0,  30, 'Reader-01'), -- 30 KL (Domestic normal)
(3, 4, '2026-10', '2026-10-31', 500, 620, 'Reader-02'), -- 120 KL (Commercial)
(4, 5, '2026-10', '2026-10-31', 210, 295, 'Reader-03'), -- 85 KL (Unusually high domestic -> leak!)
(5, 6, '2026-10', '2026-10-31', 900,1250, 'Reader-04'), -- 350 KL (Industrial)
(6, 7, '2026-10', '2026-10-31',  80, 102, 'Reader-03'), -- 22 KL (Domestic normal)
-- November 2026 (reading_id 7 has an intentional over-reading error to test correction!)
(1, 1, '2026-11', '2026-11-23', 145, 205, 'Reader-01'), -- Misread as 205 (60 KL), actual is 170 (25 KL)
(2, 3, '2026-11', '2026-11-23',  30,  58, 'Reader-01'), -- 28 KL
(3, 4, '2026-11', '2026-11-23', 620, 750, 'Reader-02'); -- 130 KL

-- 7.8 Generate October 2026 Bills via Stored Procedure
CALL sp_generate_monthly_bill(1, '2026-11-01');
CALL sp_generate_monthly_bill(2, '2026-11-01');
CALL sp_generate_monthly_bill(3, '2026-11-01');
CALL sp_generate_monthly_bill(4, '2026-11-01');
CALL sp_generate_monthly_bill(5, '2026-11-01');
CALL sp_generate_monthly_bill(6, '2026-11-01');

-- 7.9 Record Payments for October Bills (leaving Bill #2 unpaid to trigger late penalty in Nov)
CALL sp_record_payment(1, '2026-11-05', 290.00,  'UPI',        'UPI-20261105-001');
CALL sp_record_payment(3, '2026-11-06', 3510.00, 'NETBANKING', 'NEFT-20261106-003');
CALL sp_record_payment(4, '2026-11-07', 500.00,  'CARD',       'CARD-20261107-004'); -- Partial payment
CALL sp_record_payment(5, '2026-11-08', 16150.00,'NETBANKING', 'RTGS-20261108-005');
CALL sp_record_payment(6, '2026-11-09', 254.00,  'UPI',        'UPI-20261109-006');

-- Mark Bill #2 as OVERDUE since due date (2026-11-16) has passed
UPDATE BILL
SET bill_status = 'OVERDUE'
WHERE bill_id = 2 AND bill_status = 'UNPAID';

-- 7.10 Generate November 2026 Bills (Bill #8 for CONN-1002 will automatically include 5% late penalty!)
CALL sp_generate_monthly_bill(7, '2026-11-24'); -- CONN-1001: 60 KL -> Rs. 710.00
CALL sp_generate_monthly_bill(8, '2026-11-24'); -- CONN-1002: 28 KL + 5% penalty on Oct overdue
CALL sp_generate_monthly_bill(9, '2026-11-24'); -- CONN-1003: 130 KL

-- Customer 1 pays the over-billed November Bill #7 in full (Rs. 710.00)
CALL sp_record_payment(7, '2026-11-24', 710.00, 'UPI', 'UPI-20261124-007');

-- 7.11 DEMONSTRATE ADVANCED CHALLENGE:
-- Correct reading_id = 7 from 205 down to 170 (25 KL instead of 60 KL).
-- Atomically updates METER_READING, adds negative CORRECTION_ADJUSTMENT in BILL_DETAIL,
-- recalculates BILL #7 from Rs. 710 to Rs. 290, issues automatic REFUND of Rs. 420 in PAYMENT,
-- and logs everything in AUDIT_LOG with ZERO duplicate bills!
CALL sp_correct_reading_and_recalculate_bill(
    7, 170, '2026-11-24', 'Digit transposition error verified on photo inspection'
);

-- 7.12 Complaints, Maintenance Requests & Service Interruptions
INSERT INTO COMPLAINT (customer_id, connection_id, complaint_type, description, filed_date, resolved_date, priority, complaint_status) VALUES
(4, 4, 'LEAKAGE',       'Underground main line leakage near gate causing spike in meter reading', '2026-11-02', NULL,         'HIGH',   'IN_PROGRESS'),
(2, 2, 'LOW_PRESSURE',  'Very low water pressure during morning supply hours',                    '2026-11-10', '2026-11-12', 'MEDIUM', 'RESOLVED'),
(6, 6, 'LEAKAGE',       'Joint valve dripping near meter chamber',                                '2026-11-20', NULL,         'HIGH',   'OPEN');

INSERT INTO MAINTENANCE_REQUEST (complaint_id, connection_id, assigned_team, scheduled_date, completed_date, maintenance_cost, work_status, work_notes) VALUES
(1, 4, 'Pipeline Repair Squad 1', '2026-11-04', NULL,         2500.00, 'IN_PROGRESS', 'Excavation started; replacing 15mm elbow joint'),
(2, 2, 'Pressure Valve Team 2',   '2026-11-11', '2026-11-12',  450.00, 'COMPLETED',   'Cleared silt blockage in distribution valve'),
(3, 6, 'Pipeline Repair Squad 1', '2026-11-25', NULL,          600.00, 'SCHEDULED',   'Scheduled valve gasket replacement');

INSERT INTO SERVICE_INTERRUPTION (locality_id, start_time, end_time, interruption_type, reason) VALUES
(1, '2026-10-18 06:00:00', '2026-10-18 11:30:00', 'PLANNED_MAINTENANCE', 'Overhead storage tank cleaning'),
(3, '2026-11-03 14:00:00', '2026-11-03 19:00:00', 'PIPE_BURST',          'Main feeder line burst near Indirapuram Gate 2'),
(2, '2026-11-15 09:00:00', '2026-11-15 12:00:00', 'POWER_OUTAGE',        'Booster pump substation shutdown');

-- Update a complaint status to demonstrate trg_after_complaint_update
UPDATE COMPLAINT
SET complaint_status = 'IN_PROGRESS'
WHERE complaint_id = 3;

-- ============================================================================
-- SECTION 8: SYLLABUS-ALIGNED SQL QUERIES & REPORTS (Unit 2 & Unit 3)
-- ============================================================================

-- 8.1 Simple SQL Queries & Scalar Functions (Unit 2: UPPER, CONCAT, DATEDIFF, ROUND)
SELECT
    b.bill_number,
    UPPER(c.full_name) AS customer_name,
    b.billing_month,
    b.due_date,
    DATEDIFF('2026-11-24', b.due_date) AS days_past_due,
    ROUND(b.total_amount - b.amount_paid, 2) AS outstanding_balance
FROM BILL b
INNER JOIN SERVICE_CONNECTION sc ON b.connection_id = sc.connection_id
INNER JOIN CUSTOMER c            ON sc.customer_id = c.customer_id
WHERE b.bill_status IN ('UNPAID', 'PARTIAL', 'OVERDUE')
ORDER BY days_past_due DESC;

-- 8.2 Retrieving Data from Multiple Tables (Unit 2: JOINs) - Meter Replacement History
SELECT
    sc.connection_no,
    c.full_name,
    wm_old.meter_serial_no AS old_meter,
    wm_new.meter_serial_no AS new_meter,
    mrh.replacement_date,
    mrh.old_final_reading,
    mrh.reason
FROM METER_REPLACEMENT_HISTORY mrh
INNER JOIN SERVICE_CONNECTION sc ON mrh.connection_id = sc.connection_id
INNER JOIN CUSTOMER c            ON sc.customer_id = c.customer_id
INNER JOIN WATER_METER wm_old    ON mrh.old_meter_id = wm_old.meter_id
INNER JOIN WATER_METER wm_new    ON mrh.new_meter_id = wm_new.meter_id;

-- 8.3 Column (Aggregate) Functions & Grouping (Unit 2: SUM, COUNT, AVG, GROUP BY, HAVING)
-- Locality-wise Consumption and Revenue Report
SELECT * FROM vw_locality_consumption_revenue
ORDER BY total_billed_rs DESC;

-- Tariff-wise Revenue & Average Consumption Report (HAVING filter)
SELECT
    t.tariff_name,
    COUNT(b.bill_id)                   AS bills_issued,
    SUM(b.units_billed)                AS total_units_kl,
    ROUND(AVG(b.units_billed), 2)      AS avg_units_per_bill,
    SUM(b.total_amount)                AS total_billed_rs,
    SUM(b.amount_paid)                 AS total_collected_rs
FROM TARIFF t
INNER JOIN BILL b ON t.tariff_id = b.tariff_id
GROUP BY t.tariff_id, t.tariff_name
HAVING SUM(b.total_amount) > 500.00
ORDER BY total_billed_rs DESC;

-- 8.4 Subqueries (Unit 2): Identify Unusually High Consumption
-- Flags readings exceeding 1.5x the average consumption of their customer category
SELECT
    mr.reading_id,
    mr.billing_month,
    sc.connection_no,
    c.full_name,
    c.customer_type,
    mr.units_consumed,
    (
        SELECT ROUND(AVG(mr2.units_consumed), 2)
        FROM METER_READING mr2
        INNER JOIN SERVICE_CONNECTION sc2 ON mr2.connection_id = sc2.connection_id
        INNER JOIN CUSTOMER c2            ON sc2.customer_id = c2.customer_id
        WHERE c2.customer_type = c.customer_type
    ) AS category_avg_kl
FROM METER_READING mr
INNER JOIN SERVICE_CONNECTION sc ON mr.connection_id = sc.connection_id
INNER JOIN CUSTOMER c            ON sc.customer_id = c.customer_id
WHERE mr.units_consumed > 1.5 * (
    SELECT AVG(mr3.units_consumed)
    FROM METER_READING mr3
    INNER JOIN SERVICE_CONNECTION sc3 ON mr3.connection_id = sc3.connection_id
    INNER JOIN CUSTOMER c3            ON sc3.customer_id = c3.customer_id
    WHERE c3.customer_type = c.customer_type
)
ORDER BY mr.units_consumed DESC;

-- 8.5 UNION Query (Unit 2): Unified Financial Ledger (Bills vs. Payments & Refunds)
SELECT
    b.bill_date        AS txn_date,
    b.bill_number      AS ref_code,
    'BILL_ISSUED'      AS txn_type,
    b.total_amount     AS amount_rs
FROM BILL b
WHERE b.connection_id = 1
UNION ALL
SELECT
    p.payment_date     AS txn_date,
    p.reference_no     AS ref_code,
    p.payment_type     AS txn_type,
    IF(p.payment_type = 'REFUND', -p.amount, p.amount) AS amount_rs
FROM PAYMENT p
INNER JOIN BILL b ON p.bill_id = b.bill_id
WHERE b.connection_id = 1
ORDER BY txn_date, txn_type;

-- 8.6 Verify Advanced Billing Correction Reconciliation (Bill #7 & Audit Trail)
SELECT
    b.bill_id,
    b.bill_number,
    b.units_billed,
    b.total_amount,
    (SELECT SUM(bd.amount) FROM BILL_DETAIL bd WHERE bd.bill_id = b.bill_id) AS detail_sum,
    b.amount_paid,
    (SELECT SUM(IF(p.payment_type = 'REFUND', -p.amount, p.amount))
     FROM PAYMENT p WHERE p.bill_id = b.bill_id) AS net_payment_ledger,
    b.bill_status
FROM BILL b
WHERE b.bill_id = 7;

SELECT * FROM AUDIT_LOG ORDER BY log_id;