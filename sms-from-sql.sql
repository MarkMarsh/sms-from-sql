--
-- SQL to support blog https://kognitio.com/blog/sms-from-sql/
--
-- must be run as user with create external table privileges - sys is fine on a test system
--
-- create a schema for this exercise
create schema validation;
set schema validation;

-- create a table to collect messages in
create table alert_messages
(
  alert_ts timestamp,
  message varchar(1000)
);


-- create a table simulating a table that has missing data for the previous day
create table t1
(
  some_columns int,
  loaded_date date
);

insert into t1 values
--(1, current_date - interval '1' day),
(2, current_date - interval '2' day),
(3, current_date - interval '3' day),
(4, current_date - interval '4' day);


-- check table t1 to make sure it has data for the previous day and insert a message
-- into the alert_message table if not
insert into alert_messages
    select * from values (current_timestamp, 'Table t1 has no data for yesterday')
    where not exists(select * from t1 where loaded_date = current_date - interval '1' day);

select * from alert_messages;


-- publish a message on the text message SNS topic
external script using environment local_shell
receives(alert_ts timestamp, message varchar(1000))
sends(bash_output varchar(5000) character set utf8)
output 'fmt_field_separator "^"'
limit 1 threads
requires 250 MB RAM
script S'EOF(
nmessages=$(wc -l)
if [[ "${nmessages}" == "0" ]] ; then
  message="There are no alert messages for this mornings imaging"
else
  message="You have ${nmessages} message(s) in the Kognitio alert_messages table"
fi
aws sns publish --topic-arn arn:aws:sns:eu-west-1:000000000000:alert-blog-sms --message "${message}" --region eu-west-1
)EOF'
from table alert_messages;


-- publish a longer message on the email SNS topic
external script using environment local_shell
receives(alert_ts timestamp, message varchar(1000))
sends(bash_output varchar(5000) character set utf8)
output 'fmt_field_separator "^"'
limit 1 threads
requires 250 MB RAM
script S'EOF(
nmessages=0
messages=" "
while read LINE; do
  ((++nmessages))
  messages="${messages}
${LINE}"
done 
if [[ "${nmessages}" == "0" ]] ; then
  message="There are no alert messages for this mornings Kognitio imaging"
else
  message="You have ${nmessages} message(s) in the Kognitio alert_messages table:${messages}"
fi
aws sns publish --topic-arn arn:aws:sns:eu-west-1:000000000000:alert-blog-email --region eu-west-1 --message "${message}"
)EOF'
from (select * from alert_messages order by alert_ts);

