drop table if exists volcanoes;
drop table if exists eruption_events;

create table volcanoes(
volcano_id serial primary key,
name text,
country text,
elevation_m int
);

create table eruption_events(
event_id serial primary key,
volcano_id int,
eruption_date date,
vei_scale int
);

insert into volcanoes values
(1, 'Krakatoa', 'Indonesia', 813),
(2, 'Etna', 'Italy', 3357),
(3, 'Yellowstone Caldera', 'USA', 2805);

insert into eruption_events values
(1, 1, '2020-04-11', 2),
(2, 1, '2022-08-03', 4),
(3, 1, '2025-01-15', 3),
(4, 2, '2021-02-16', 1),
(5, 2, '2023-07-04', 2),
(6, 2, '2024-12-25', 3),
(7, 3, '2019-11-01', 1),
(8, 3, '2025-06-10', 2);

-- LATERAL JOIN: For e


select v.name as volcano ,v.country , e.eruption_date , e.vei_scale  from volcanoes v cross join lateral(
select eruption_date , vei_scale
from eruption_events 
where volcano_id = v.volcano_id order by vei_scale desc limit 2
) e order by v.name , e.vei_scale desc;




create table chess_players(
player_id serial primary key,
username text,
elo_rating int

);

create table chess_games(
game_id serial primary key,
player_id int,
opponent text,
result text,
played_on date,
elo_change int
);


insert into chess_players values
(1, 'MagnusBot', 2850),
(2, 'HiddenKnight99', 2100),
(3, 'QueenSacrifice', 1780);

insert into chess_games values
(1,  1, 'AlphaChess', 'win',  '2026-01-01',  +12),
(2,  1, 'DeepBlue2',  'loss', '2026-02-15',  -8),
(3,  1, 'Stockfish',  'draw', '2026-03-20',  +2),
(4,  1, 'Human2000',  'win',  '2026-05-01',  +5),
(5,  2, 'RookMaster', 'loss', '2026-01-10',  -15),
(6,  2, 'PawnStorm',  'win',  '2026-04-05',  +10),
(7,  2, 'EndGame99',  'draw', '2026-06-01',  +1),
(8,  3, 'IronDefense','win',  '2026-03-01',  +20),
(9,  3, 'GambitKing', 'loss', '2026-05-15',  -12),
(10, 3, 'TrapSetter', 'win',  '2026-06-20',  +18);

select 
p.username,
p.elo_rating,
g.opponent,
g.result,
g.played_on,
g.elo_change
from chess_players p cross join lateral(
select opponent , result , played_on , elo_change from chess_games where player_id = p.player_id order by played_on desc limit 3
) g order by p.username , g.played_on desc;


