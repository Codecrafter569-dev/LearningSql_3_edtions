drop table if exists senior_agents;
drop table if exists agents cascade;

create table agents(
agent_id integer not null primary key,
full_name text not null,
hired_on date not null default now()::date
);
CREATE TABLE senior_agents (
    team_size INTEGER NOT NULL DEFAULT 0
) INHERITS (agents);

alter table senior_agents
add constraint senior_agents_pk primary key (agent_id);

insert into agents (agent_id , full_name) values (1,'Priya N.');
insert into senior_agents (agent_id , full_name , team_size) values (2,'Marco R.',5);

select * from agents;

drop table if exists tickets cascade;

create table tickets(
ticket_id serial,
subject text not null,
status text not null default 'open',
opened_on date not null default now()::date,
primary key(ticket_id,status)
)
partition by list(status);

create table tickets_open partition of tickets
for values in ('open');
create table tickets_in_progress partition of tickets for values in ('in_progress');
create table tickets_closed partition of tickets for values in ('closed');

create index on tickets (subject);
insert into tickets (subject,status)
values ('Cannot log in','open');
insert into tickets(subject,status)
values ('Refund request','in_progress');
insert into tickets (subject,status)
values ('Password reset','closed');

select * from tickets;
select * from tickets_closed;
select * from tickets_open;
select * from tickets_in_progress;

drop table if exists ticket_events cascade;

create table ticket_events (
event_id serial,
ticket_id integer not null,
event_type text not null,
event_date date not null default now()::date,
primary key (event_id,event_date)

)
partition by range(event_date);

create table ticket_events_2026_05 partition of ticket_events for values from ('2026-05-01') to ('2026-06-01');
create table ticket_events_2026_06 partition of ticket_events for values from ('2026-06-01') to ('2026-07-01');
create table ticket_events_2026_07 partition of ticket_events for values from ('2026-07-01') to ('2026-08-01');

insert into ticket_events (ticket_id,event_type,event_date)
values 
    (1, 'created', '2026-07-01'),
    (1, 'assigned', '2026-07-02'),
    (2, 'created', '2026-06-15');
    
DROP TABLE IF EXISTS sensor_pings CASCADE;

CREATE TABLE sensor_pings (
    ping_id BIGSERIAL,
    device_id INTEGER NOT NULL,
    payload JSONB,
    PRIMARY KEY (ping_id, device_id)
)
PARTITION BY HASH (device_id);

CREATE TABLE sensor_pings_p0 PARTITION OF sensor_pings
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sensor_pings_p1 PARTITION OF sensor_pings
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sensor_pings_p2 PARTITION OF sensor_pings
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sensor_pings_p3 PARTITION OF sensor_pings
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO sensor_pings (device_id, payload) VALUES
    (101, '{"battery": 92}'),
    (102, '{"battery": 71}'),
    (103, '{"battery": 40}');

select * from sensor_pings;
select * from sensor_pings_p0;
select * from sensor_pings_p1;
select * from sensor_pings_p2;
select * from sensor_pings_p3;


create table ticket_events_2026_08 partition of ticket_events for VALUES from ('2026-08-01') to ('2026-09-01');

alter table ticket_events detach partition ticket_events_2026_05;

create table ticket_events_archive(
event_id integer not null,
ticket_id integer not null,
event_type text not null,
event_date date not null,
primary key (event_id , event_date)
);

alter table ticket_events attach partition ticket_events_archive for VALUES from  ('2000-01-01') TO ('2026-05-01');

