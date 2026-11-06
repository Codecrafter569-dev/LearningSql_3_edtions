select category, count(*) from posts group by category order by category;

select category , count(*) over (partition by category) from posts order by category;

select category , count(*) over (partition by category) , count(*) over () from posts order by category;

select distinct category , count(*) over (partition by category) , count(*) over() from posts order by category;

select distinct category , count(*) over w1 , count(*) over W2 from posts WINDOW w1 as (partition by category) , W2 as () order by category;


select * from generate_series(10,30);

select category , row_number() over w from posts window w as (partition by category) order by category;

select category , row_number() over w , title from posts window w as (partition by category order by title) order by category;

\x  

select category , row_number() over w , title , first_value(title) over w from posts window w as (partition by category order by category) order by category;

select category , row_number() over w , title , last_value(title) over w from posts window w as (partition by category order by category) order by category;

\x

select pk , title , author , rank() over () from posts;

select pk , title , author , rank() over(order by author) from posts;

select pk , title , author , rank() over(partition by author order by author) from posts;

select pk , title , author , dense_rank() over (order by author) from posts order by category;

select x from generate_series(1,20) as x;

select x , lag(x) over w from (select generate_series(1,5) as x) V window w as (order by x);

select x , lag(x,3) over w from (select generate_series(1,10) as x) V window w as (order by x);

select x , lead(x) over w from (select generate_series(1,10) as x) V window w as (order by x);

select x , lead(x,3) over w from(select generate_series(1,10) as x) C window w as (order by x);


select x , cume_dist() over w from (select generate_series(1,10) as x) V window w as (order by x);

select x , ntile(2) over w from (select generate_series(1,24) as x) V window w as (order by x);

select x , ntile(3) over w from(select generate_series(1,24) as x) V window w as (order by x);

select distinct category , count(*) over (partition by category) from posts order by category;

select distinct category , count(*) over w1 from posts window w1 as (partition by category RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
order by category;

select x from (select generate_series(1,10) as x) V window w as (order by x);

select x , sum(x) over (order by x) from generate_series(1,5) as x;

select x ,sum(x) over w from(select generate_series(1,5) as x) V window w as (order by x ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW);



