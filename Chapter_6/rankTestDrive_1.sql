drop table if exists exam_scores;

create table exam_scores(
student text,
score int
);
insert into exam_scores values
('Ravi', 95),
('Meera', 95),
('John', 88),
('Sara', 80);

select student,score , rank()  over (order by score desc) as rnk from exam_scores;


-- reuse exam_scores from above
SELECT student, score,
    RANK()       OVER (ORDER BY score DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rnk
FROM exam_scores;
-- Ravi 1/1, Meera 1/1, John 3/2, Sara 4/3

