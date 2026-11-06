-- ================================================================
-- PRACTICE PROGRAM: Mini Help-Desk Ticketing System
-- ================================================================
CREATE EXTENSION IF NOT EXISTS hstore;

-- ---------- Tables ----------
DROP TABLE IF EXISTS tickets CASCADE;
CREATE TABLE tickets (
    pk          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject     text NOT NULL,
    agent       text,
    priority    text NOT NULL DEFAULT 'normal',   -- low | normal | high | urgent
    status      text NOT NULL DEFAULT 'open',     -- open | closed | spam
    hours_spent numeric NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now()
);

DROP TABLE IF EXISTS closed_tickets CASCADE;
CREATE TABLE closed_tickets (
    pk          integer NOT NULL PRIMARY KEY,
    subject     text,
    agent       text,
    priority    text,
    status      text,
    hours_spent numeric,
    created_at  timestamptz
);

DROP TABLE IF EXISTS ticket_audit CASCADE;
CREATE TABLE ticket_audit (
    audit_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_pk integer,
    action    text,
    logged_at timestamptz NOT NULL DEFAULT now()
);

DROP TYPE IF EXISTS agent_summary CASCADE;
CREATE TYPE agent_summary AS (
    agent        text,
    open_tickets integer,
    avg_hours    numeric,
    details      hstore
);

-- ---------- 1) IN/OUT parameters ----------
CREATE OR REPLACE FUNCTION sla_check(
    IN  p_hours_spent   numeric,
    IN  p_sla_budget    numeric,
    OUT hours_remaining numeric,
    OUT is_breached     boolean
) AS
\$\$
BEGIN
    hours_remaining := p_sla_budget - p_hours_spent;
    is_breached := hours_remaining < 0;
END;
\$\$ LANGUAGE plpgsql;

-- ---------- 2) Volatility: IMMUTABLE (same inputs -> always same output) ----------
CREATE OR REPLACE FUNCTION priority_due_date(p_priority text, p_created timestamptz)
RETURNS timestamptz AS
\$\$
BEGIN
    RETURN CASE p_priority
        WHEN 'urgent' THEN p_created + interval '4 hours'
        WHEN 'high'   THEN p_created + interval '1 day'
        WHEN 'low'    THEN p_created + interval '5 days'
        ELSE               p_created + interval '2 days'
    END;
END;
\$\$ LANGUAGE plpgsql IMMUTABLE;

-- ---------- 3) IF statement ----------
CREATE OR REPLACE FUNCTION classify_workload(p_open_count integer)
RETURNS text AS
\$\$
BEGIN
    IF p_open_count = 0 THEN
        RETURN 'idle';
    ELSIF p_open_count <= 3 THEN
        RETURN 'light load';
    ELSE
        RETURN 'overloaded';
    END IF;
END;
\$\$ LANGUAGE plpgsql;

-- ---------- 4) CASE statement (simple form) ----------
CREATE OR REPLACE FUNCTION priority_weight(p_priority text)
RETURNS integer AS
\$\$
BEGIN
    CASE p_priority
        WHEN 'urgent' THEN RETURN 4;
        WHEN 'high'   THEN RETURN 3;
        WHEN 'normal' THEN RETURN 2;
        ELSE               RETURN 1;
    END CASE;
END;
\$\$ LANGUAGE plpgsql;

-- ---------- 5) Loop + RECORD type + exception handling ----------
CREATE OR REPLACE FUNCTION agent_summary_report()
RETURNS SETOF agent_summary AS
\$\$
DECLARE
    rw    record;
    ret   agent_summary;
    v_avg numeric;
BEGIN
    FOR rw IN
        SELECT agent,
               count(*) FILTER (WHERE status = 'open') AS open_count,
               sum(hours_spent) AS total_hours,
               count(*) AS ticket_count
        FROM tickets
        GROUP BY agent
    LOOP
        BEGIN
            v_avg := rw.total_hours / rw.ticket_count;
        EXCEPTION
            WHEN division_by_zero THEN
                v_avg := 0;
        END;

        ret.agent := rw.agent;
        ret.open_tickets := rw.open_count;
        ret.avg_hours := v_avg;
        ret.details := hstore(ARRAY[
            'workload', classify_workload(rw.open_count::integer)
        ]);
        RETURN NEXT ret;
    END LOOP;
    RETURN;
END;
\$\$ LANGUAGE plpgsql;

-- ---------- 6) SECURITY DEFINER ----------
CREATE SCHEMA IF NOT EXISTS helpdesk;

CREATE OR REPLACE FUNCTION helpdesk.public_agent_summary()
RETURNS SETOF agent_summary AS
\$\$
    SELECT * FROM agent_summary_report();
\$\$ LANGUAGE sql
SECURITY DEFINER;
-- GRANT EXECUTE ON FUNCTION helpdesk.public_agent_summary() TO support_readonly;

-- ---------- 7) Rules: DO ALSO (audit every new/deleted ticket) ----------
CREATE OR REPLACE RULE r_ticket_audit_insert AS
    ON INSERT TO tickets
    DO ALSO
        INSERT INTO ticket_audit (ticket_pk, action)
        VALUES (NEW.pk, 'created');

CREATE OR REPLACE RULE r_ticket_delete_audit AS
    ON DELETE TO tickets
    DO ALSO
        INSERT INTO ticket_audit (ticket_pk, action)
        VALUES (OLD.pk, 'deleted');

-- ---------- 8) Rules: DO INSTEAD (route closed tickets straight to archive) ----------
CREATE OR REPLACE RULE r_ticket_insert_closed AS
    ON INSERT TO tickets
    WHERE NEW.status = 'closed'
    DO INSTEAD
        INSERT INTO closed_tickets
        VALUES (NEW.pk, NEW.subject, NEW.agent, NEW.priority,
                NEW.status, NEW.hours_spent, NEW.created_at);

-- ---------- 9) Rules: DO INSTEAD NOTHING (drop spam silently) ----------
CREATE OR REPLACE RULE r_ticket_insert_spam AS
    ON INSERT TO tickets
    WHERE NEW.status = 'spam'
    DO INSTEAD NOTHING;

-- ---------- 10) DELETE/UPDATE sync pattern (helper function + unconditional rule) ----------
CREATE OR REPLACE FUNCTION move_ticket_to_closed(
    p_pk          integer,
    p_subject     text,
    p_agent       text,
    p_priority    text,
    p_status      text,
    p_hours_spent numeric,
    p_created_at  timestamptz,
    p_old_pk      integer
) RETURNS void AS
\$\$
BEGIN
    IF p_status = 'closed' THEN
        DELETE FROM tickets WHERE pk = p_old_pk;
        INSERT INTO closed_tickets
        VALUES (p_pk, p_subject, p_agent, p_priority, p_status, p_hours_spent, p_created_at);
    END IF;
END;
\$\$ LANGUAGE plpgsql;

CREATE OR REPLACE RULE r_ticket_update_close AS
    ON UPDATE TO tickets
    DO ALSO
        SELECT move_ticket_to_closed(
            NEW.pk, NEW.subject, NEW.agent, NEW.priority,
            NEW.status, NEW.hours_spent, NEW.created_at, OLD.pk
        );

-- ================================================================
-- DEMO
-- ================================================================
INSERT INTO tickets (subject, agent, priority, hours_spent) VALUES
    ('Cannot log in', 'Riya', 'urgent', 1.5),
    ('Slow dashboard', 'Riya', 'normal', 3),
    ('Typo on invoice', 'Sam', 'low', 0.5);

INSERT INTO tickets (subject, agent, priority, status, hours_spent) VALUES
    ('Test ticket - ignore', 'Sam', 'low', 'spam', 0);              -- dropped

INSERT INTO tickets (subject, agent, priority, status, hours_spent) VALUES
    ('Password reset (already done)', 'Sam', 'normal', 'closed', 0.2);  -- straight to archive

SELECT * FROM tickets;
SELECT * FROM closed_tickets;
SELECT * FROM ticket_audit;

-- Close an open ticket via UPDATE -> auto-moved to the archive
UPDATE tickets SET status = 'closed', hours_spent = 2 WHERE subject = 'Slow dashboard';
SELECT * FROM tickets;
SELECT * FROM closed_tickets;

-- Exercise the other functions
SELECT * FROM sla_check(6, 4);
SELECT priority_due_date('urgent', now());
SELECT classify_workload(5);
SELECT priority_weight('high');
SELECT * FROM agent_summary_report();
SELECT * FROM helpdesk.public_agent_summary();
