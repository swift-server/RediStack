# ``RediStack/RedisCommand``

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

## Command Definitions

Commands that are directly supported by **RediStack** will use the same spelling and naming as found in Redis,
and are defined as static functions.

For the full list of Redis commands, reference the [Redis Command documentation](https://redis.io/commands).

Some commands are available directly as extensions on ``RedisClient``.

## Custom Commands

If a command is not directly supported by **RediStack**, you can write your own extension on ``RedisCommand`` and use
the various initializers.

While the `ResultType` of the command is a concrete Swift type, such as an enum, it needs to first be parsed from
the raw ``RESPValue`` Redis response, which is done with the `mapValueToResult` closure of ``init(keyword:arguments:mapValueToResult:)``.

For types conforming to ``RESPValueConvertible``, this done automatically with the `init(keyword:arguments)` initializer.

## Topics

### Command components

- ``keyword``
- ``arguments``

### Creating a custom command

- ``init(keyword:arguments:mapValueToResult:)``

### Connection Commands

- ``echo(_:)``
- ``ping(with:)``
- ``auth(with:)``
- ``select(database:)``

### Hash Commands

- ``hdel(_:from:)-4s5f6``
- ``hdel(_:from:)-8zyjq``
- ``hexists(_:in:)``
- ``hget(_:from:)``
- ``hgetall(from:)``
- ``hincrby(_:field:in:)``
- ``hincrbyfloat(_:field:in:)``
- ``hkeys(in:)``
- ``hlen(of:)``
- ``hmget(_:from:)-az2q``
- ``hmget(_:from:)-52q0x``
- ``hset(_:to:in:)``
- ``hmset(_:in:)``
- ``hsetnx(_:to:in:)``
- ``hstrlen(of:in:)``
- ``hvals(in:)``
- ``hscan(_:startingFrom:matching:count:)``

### Key Commands

- ``del(_:)``
- ``exists(_:)-5g9rq``
- ``exists(_:)-9qli9``
- ``expire(_:after:)``
- ``ttl(_:)``
- ``pttl(_:)``
- ``keys(matching:)``
- ``scan(startingFrom:matching:count:)``

### List Commands

- ``blpop(from:timeout:)-64l4w``
- ``blpop(from:timeout:)-5y458``
- ``blpop(from:timeout:)-881zh``
- ``brpop(from:timeout:)-3uers``
- ``brpop(from:timeout:)-235os``
- ``brpop(from:timeout:)-906qk``
- ``brpoplpush(from:to:timeout:)``
- ``lindex(_:from:)``
- ``linsert(_:into:before:)``
- ``linsert(_:into:after:)``
- ``llen(of:)``
- ``lpop(from:)``
- ``lpush(_:into:)-9wnpn``
- ``lpush(_:into:)-6vdyu``
- ``lpushx(_:into:)``
- ``lrange(from:firstIndex:lastIndex:)``
- ``lrange(from:indices:)-947k1``
- ``lrange(from:indices:)-555up``
- ``lrange(from:fromIndex:)``
- ``lrange(from:upToIndex:)``
- ``lrange(from:throughIndex:)``
- ``lrem(_:from:count:)``
- ``lset(index:to:in:)``
- ``ltrim(_:before:after:)``
- ``ltrim(_:keepingIndices:)-594fr``
- ``ltrim(_:keepingIndices:)-9k7s6``
- ``ltrim(_:keepingIndices:)-9gvv8``
- ``ltrim(_:keepingIndices:)-243g``
- ``ltrim(_:keepingIndices:)-3q1zz``
- ``rpop(from:)``
- ``rpoplpush(from:to:)``
- ``rpush(_:into:)-9k27q``
- ``rpush(_:into:)-97xay``
- ``rpushx(_:into:)``

### Pub/Sub Commands

- ``publish(_:to:)``
- ``pubsubChannels(matching:)``
- ``pubsubNumpat()``
- ``pubsubNumsub(forChannels:)``

### Server Commands

- ``swapdb(_:with:)``

### Set Commands

- ``sadd(_:to:)-2hh4m``
- ``sadd(_:to:)-4sxtr``
- ``scard(of:)``
- ``sdiff(of:)-67ekq``
- ``sdiff(of:)-3f66d``
- ``sdiffstore(as:sources:)``
- ``sinter(of:)-7pqph``
- ``sinter(of:)-90a5u``
- ``sinterstore(as:sources:)``
- ``sismember(_:of:)``
- ``smembers(of:)``
- ``smove(_:from:to:)``
- ``spop(from:max:)``
- ``srandmember(from:max:)``
- ``srem(_:from:)-2n6ud``
- ``srem(_:from:)-21xah``
- ``sunion(of:)-2gx4``
- ``sunion(of:)-3baqs``
- ``sunionstore(as:sources:)``
- ``sscan(_:startingFrom:matching:count:)``

### SortedSet Commands

- ``bzpopmin(from:timeout:)-7ht1z``
- ``bzpopmin(from:timeout:)-5lf0y``
- ``bzpopmin(from:timeout:)-97ikd``
- ``bzpopmax(from:timeout:)-9f01n``
- ``bzpopmax(from:timeout:)-6c5lj``
- ``bzpopmax(from:timeout:)-79p3g``
- ``zadd(_:to:inserting:returning:)-4yuz4``
- ``zadd(_:to:inserting:returning:)-1evtg``
- ``zadd(_:to:inserting:returning:)-1drwk``
- ``zcount(of:withScoresBetween:)``
- ``zcount(of:withMaximumScoreOf:)``
- ``zcount(of:withMinimumScoreOf:)``
- ``zcount(of:withScores:)-6b7ne``
- ``zcount(of:withScores:)-6bujq``
- ``zcard(of:)``
- ``zincrby(_:in:by:)``
- ``zinterstore(as:sources:weights:aggregateMethod:)``
- ``zlexcount(of:withValuesBetween:)``
- ``zlexcount(of:withMinimumValueOf:)``
- ``zlexcount(of:withMaximumValueOf:)``
- ``zpopmax(from:)``
- ``zpopmax(from:max:)``
- ``zpopmin(from:)``
- ``zpopmin(from:max:)``
- ``zrange(from:firstIndex:lastIndex:returning:)``
- ``zrange(from:indices:returning:)-95y9o``
- ``zrange(from:indices:returning:)-4pd8n``
- ``zrange(from:fromIndex:returning:)``
- ``zrange(from:throughIndex:returning:)``
- ``zrange(from:upToIndex:returning:)``
- ``zrangebylex(from:withValuesBetween:limitBy:)``
- ``zrangebylex(from:withMaximumValueOf:limitBy:)``
- ``zrangebylex(from:withMinimumValueOf:limitBy:)``
- ``zrevrangebylex(from:withValuesBetween:limitBy:)``
- ``zrevrangebylex(from:withMaximumValueOf:limitBy:)``
- ``zrevrangebylex(from:withMinimumValueOf:limitBy:)``
- ``zrangebyscore(from:withScoresBetween:limitBy:returning:)``
- ``zrangebyscore(from:withScores:limitBy:returning:)-4ukbv``
- ``zrangebyscore(from:withScores:limitBy:returning:)-phw``
- ``zrangebyscore(from:withMaximumScoreOf:limitBy:returning:)``
- ``zrangebyscore(from:withMinimumScoreOf:limitBy:returning:)``
- ``zrank(of:in:)``
- ``zrem(_:from:)-86osv``
- ``zrem(_:from:)-1ey05``
- ``zremrangebylex(from:withValuesBetween:)``
- ``zremrangebylex(from:withMaximumValueOf:)``
- ``zremrangebylex(from:withMinimumValueOf:)``
- ``zremrangebyrank(from:firstIndex:lastIndex:)``
- ``zremrangebyrank(from:throughIndex:)``
- ``zremrangebyrank(from:upToIndex:)``
- ``zremrangebyrank(from:fromIndex:)``
- ``zremrangebyrank(from:indices:)-2mwa6``
- ``zremrangebyrank(from:indices:)-9svqd``
- ``zremrangebyscore(from:withScoresBetween:)``
- ``zremrangebyscore(from:withScores:)-4lm7a``
- ``zremrangebyscore(from:withScores:)-1t3ww``
- ``zremrangebyscore(from:withMaximumScoreOf:)``
- ``zremrangebyscore(from:withMinimumScoreOf:)``
- ``zrevrange(from:firstIndex:lastIndex:returning:)``
- ``zrevrange(from:fromIndex:returning:)``
- ``zrevrange(from:upToIndex:returning:)``
- ``zrevrange(from:throughIndex:returning:)``
- ``zrevrange(from:indices:returning:)-3ikhd``
- ``zrevrange(from:indices:returning:)-3t0hk``
- ``zrevrangebyscore(from:withScoresBetween:limitBy:returning:)``
- ``zrevrangebyscore(from:withScores:limitBy:returning:)-2vp67``
- ``zrevrangebyscore(from:withScores:limitBy:returning:)-3jdpl``
- ``zrevrangebyscore(from:withMaximumScoreOf:limitBy:returning:)``
- ``zrevrangebyscore(from:withMinimumScoreOf:limitBy:returning:)``
- ``zrevrank(of:in:)``
- ``zscore(of:in:)``
- ``zunionstore(as:sources:weights:aggregateMethod:)``
- ``zscan(_:startingFrom:matching:count:)``

### String Commands

- ``append(_:to:)``
- ``decr(_:)``
- ``decrby(_:by:)``
- ``get(_:)``
- ``incr(_:)``
- ``incrby(_:by:)``
- ``incrbyfloat(_:by:)``
- ``mget(_:)-9m30p``
- ``mget(_:)-6kz3i``
- ``mset(_:)``
- ``msetnx(_:)``
- ``psetex(_:to:expirationInMilliseconds:)``
- ``set(_:to:)``
- ``set(_:to:onCondition:expiration:)``
- ``setex(_:to:expirationInSeconds:)``
- ``setnx(_:to:)``
- ``strln(_:)``
