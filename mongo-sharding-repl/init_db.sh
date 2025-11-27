# docker compose exec -T <service-name> mongosh --port <mongo port> --quiet <<EOF
# <mongosh commands here>
# EOF

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
EOF

docker compose exec -T shard1-a mongosh --port 27018 --quiet <<EOF
rs.initiate({_id: "shard1", members: [
{_id: 0, host: "shard1-a:27018"},
{_id: 1, host: "shard1-b:27018"},
{_id: 2, host: "shard1-c:27018"}
]});
EOF

docker compose exec -T shard2-a mongosh --port 27019 --quiet <<EOF
rs.initiate({_id: "shard2", members: [
{_id: 0, host: "shard2-a:27019"},
{_id: 1, host: "shard2-b:27019"},
{_id: 2, host: "shard2-c:27019"}
]});
EOF


retries=5
delay=5

for ((i=1; i<=retries; i++)); do
    if docker compose exec -T mongos_router mongosh --port 27020 --eval "db.adminCommand('ping')" --quiet; then
        break
    else
        echo "Попытка подключения к mongos_router $i из $retries не удалась, ждем $delay секунд..."
        sleep $delay
    fi
done

if (( i > retries )); then
    echo "Не удалось подключиться к mongos_router"
    exit 1
fi

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard( "shard1/shard1-a:27018,shard1-b:27018,shard1-c:27018");
sh.addShard( "shard2/shard2-a:27019,shard2-b:27019,shard2-c:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
EOF