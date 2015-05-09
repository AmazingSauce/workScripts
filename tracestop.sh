tail -fn0 /EMC/backend/log_shared/EMCSystemLogFile.log | \
while read line ; do
        echo "$line" | egrep -i "replication.*operating normally"
        if [ $? = 0 ]
        then
                kill -9 20537
        fi
done
