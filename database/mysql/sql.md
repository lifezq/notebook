### 1.统计数据库中重复数据top10

    select field_name,count(id) as cc from tb_name group by field_name having cc>1 order by cc desc limit 10;
