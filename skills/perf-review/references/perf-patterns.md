# Backend Performance Anti-Pattern Catalog

Reference for perf-review §2-§5 and §8-§9. Organized by category with framework-specific
examples.

## Query Performance Patterns

### N+1 Queries

**Django/Python:**
```python
# BAD — N+1: 1 query for users + N queries for profiles
users = User.objects.all()
for user in users:
    print(user.profile.bio)  # Each access triggers a query

# GOOD — select_related (FK) or prefetch_related (M2M/reverse FK)
users = User.objects.select_related('profile').all()
```

**Rails/Ruby:**
```ruby
# BAD — N+1
@posts = Post.all
@posts.each { |post| post.author.name }

# GOOD — eager loading
@posts = Post.includes(:author).all
```

**SQLAlchemy/Python:**
```python
# BAD — lazy loading in loop
users = session.query(User).all()
for user in users:
    print(user.addresses)  # Lazy load per iteration

# GOOD — joinedload or subqueryload
users = session.query(User).options(joinedload(User.addresses)).all()
```

**Prisma/TypeScript:**
```typescript
// BAD — sequential queries in loop
const users = await prisma.user.findMany()
for (const user of users) {
  const posts = await prisma.post.findMany({ where: { authorId: user.id } })
}

// GOOD — include or nested select
const users = await prisma.user.findMany({ include: { posts: true } })
```

**TypeORM/TypeScript:**
```typescript
// BAD — lazy relations in loop
const users = await userRepo.find()
for (const user of users) {
  const posts = await user.posts  // lazy load
}

// GOOD — relations option or QueryBuilder join
const users = await userRepo.find({ relations: ['posts'] })
```

**GraphQL (any framework):**
```typescript
// BAD — resolver fetches per parent
const resolvers = {
  User: {
    posts: (parent) => db.posts.findByUserId(parent.id)  // Called N times
  }
}

// GOOD — DataLoader batches
const postLoader = new DataLoader(async (userIds) => {
  const posts = await db.posts.findByUserIds(userIds)
  return userIds.map(id => posts.filter(p => p.userId === id))
})
```

### Missing Indexes

**Detection signals:**
- Columns in WHERE/JOIN/ORDER BY without index in migration files
- `LIKE '%pattern'` on unindexed text columns (leading wildcard prevents index use)
- Composite WHERE with columns in different order than composite index
- Foreign key columns without indexes (common — ORMs create FK constraints but not always indexes)
- UUID primary keys without B-tree index (some DBs don't auto-index PKs)

**Framework-specific migration patterns:**
```python
# Django — check migrations for AddIndex / index_together / indexes Meta
class Meta:
    indexes = [
        models.Index(fields=['status', 'created_at']),  # Composite
    ]

# Rails — check db/migrate/ for add_index
add_index :orders, [:status, :created_at]

# Prisma — check schema.prisma for @@index
model Order {
  @@index([status, createdAt])
}
```

### Unbounded Queries

**Detection signals:**
- `.all()`, `.find({})`, `SELECT *` without `.limit()` or pagination
- List API endpoints without `?page=` or `?cursor=` parameters
- Aggregation queries on growing tables without date range filters
- `COUNT(*)` on large tables (use approximate counts or cached counts)

### Full Table Scans

**Detection signals:**
- Functions applied to indexed columns in WHERE: `WHERE LOWER(email) = ...` (use functional index or store normalized)
- Type mismatch: `WHERE string_column = 123` (implicit cast prevents index use)
- `OR` conditions on different columns (optimizer may choose scan over index merge)
- `NOT IN` / `NOT EXISTS` on large sets
- `DISTINCT` on non-indexed columns
- Missing ANALYZE/VACUUM leading to stale statistics (PostgreSQL specific)

## Memory & Allocation Patterns

### Unbounded Growth

```javascript
// BAD — event listeners not cleaned up
class Stream {
  constructor() {
    this.handlers = []
  }
  on(event, handler) {
    this.handlers.push(handler)  // Never removed
  }
}

// BAD — global cache without eviction
const cache = {}
function getUser(id) {
  if (!cache[id]) cache[id] = fetchUser(id)  // Grows forever
  return cache[id]
}

// GOOD — LRU cache with max size
import { LRUCache } from 'lru-cache'
const cache = new LRUCache({ max: 1000 })
```

### Stream Misuse

```javascript
// BAD — loads entire file into memory
const data = fs.readFileSync('large-file.csv', 'utf8')
const lines = data.split('\n')

// GOOD — stream processing
const rl = readline.createInterface({ input: fs.createReadStream('large-file.csv') })
for await (const line of rl) { /* process line */ }
```

```python
# BAD — loads entire response into memory
response = requests.get('https://large-file.example.com/data')
data = response.json()

# GOOD — stream response
response = requests.get('https://large-file.example.com/data', stream=True)
for chunk in response.iter_content(chunk_size=8192):
    process(chunk)
```

### String Concatenation in Loops

```python
# BAD — O(n²) string building
result = ""
for item in items:
    result += str(item) + ","  # Creates new string each iteration

# GOOD — join
result = ",".join(str(item) for item in items)
```

```java
// BAD — String concatenation in loop
String result = "";
for (String item : items) {
    result += item + ",";  // New String object per iteration
}

// GOOD — StringBuilder
StringBuilder sb = new StringBuilder();
for (String item : items) {
    sb.append(item).append(",");
}
```

## Algorithmic Complexity Patterns

### Nested Loop Anti-Patterns

```javascript
// BAD — O(n²) lookup
const matchedUsers = users.filter(user =>
  orders.some(order => order.userId === user.id)
)

// GOOD — O(n) with Set
const orderUserIds = new Set(orders.map(o => o.userId))
const matchedUsers = users.filter(user => orderUserIds.has(user.id))
```

```python
# BAD — O(n²) dedup
unique = []
for item in items:
    if item not in unique:  # Linear scan each time
        unique.append(item)

# GOOD — O(n) with set (preserving order)
unique = list(dict.fromkeys(items))
```

### Redundant Computation

```javascript
// BAD — expensive computation in render loop
function Component({ items }) {
  return items.map(item => {
    const sorted = [...items].sort((a, b) => a.priority - b.priority)  // Sorts N times
    return <Item key={item.id} rank={sorted.indexOf(item)} />
  })
}

// GOOD — compute once
function Component({ items }) {
  const sorted = useMemo(() =>
    [...items].sort((a, b) => a.priority - b.priority), [items]
  )
  return items.map(item => <Item key={item.id} rank={sorted.indexOf(item)} />)
}
```

## Concurrency & I/O Patterns

### Sequential Async (Waterfall)

```javascript
// BAD — sequential when independent
const users = await fetchUsers()
const orders = await fetchOrders()
const products = await fetchProducts()

// GOOD — parallel
const [users, orders, products] = await Promise.all([
  fetchUsers(), fetchOrders(), fetchProducts()
])
```

```python
# BAD — sequential async
users = await fetch_users()
orders = await fetch_orders()

# GOOD — parallel with gather
users, orders = await asyncio.gather(fetch_users(), fetch_orders())
```

### Sync I/O in Async Context

```python
# BAD — blocking call in async handler
async def handle_request(request):
    data = open('config.json').read()  # Blocks the event loop
    return Response(data)

# GOOD — async file I/O
async def handle_request(request):
    async with aiofiles.open('config.json') as f:
        data = await f.read()
    return Response(data)
```

```javascript
// BAD — sync fs in Express handler
app.get('/config', (req, res) => {
  const data = fs.readFileSync('config.json')  // Blocks event loop
  res.json(JSON.parse(data))
})

// GOOD — async
app.get('/config', async (req, res) => {
  const data = await fs.promises.readFile('config.json')
  res.json(JSON.parse(data))
})
```

### Connection Pool Issues

**Detection signals:**
- Missing pool configuration (default pool size is often 5-10, too small for concurrent apps)
- Pool `acquire` without `release` in error paths (connection leak)
- Creating new connection per request instead of using a pool
- Pool size larger than DB max_connections (causes connection refused errors)

```python
# BAD — connection per request
async def get_user(user_id):
    conn = await asyncpg.connect(DATABASE_URL)  # New connection each time
    row = await conn.fetchrow('SELECT * FROM users WHERE id = $1', user_id)
    await conn.close()
    return row

# GOOD — connection pool
pool = await asyncpg.create_pool(DATABASE_URL, min_size=5, max_size=20)
async def get_user(user_id):
    async with pool.acquire() as conn:
        return await conn.fetchrow('SELECT * FROM users WHERE id = $1', user_id)
```

### Missing Timeouts

**Detection signals:**
- HTTP client calls without timeout parameter
- Database queries without statement_timeout
- External service calls (gRPC, Redis, AMQP) without deadline/timeout
- WebSocket connections without ping/pong timeout

```javascript
// BAD — no timeout
const response = await fetch('https://external-api.com/data')

// GOOD — with timeout
const controller = new AbortController()
const timeout = setTimeout(() => controller.abort(), 5000)
const response = await fetch('https://external-api.com/data', { signal: controller.signal })
clearTimeout(timeout)
```

## Database-Specific Patterns

### Migration Performance

**Dangerous migrations** (lock tables for extended periods):
- Adding a column with a default value on a large table (PostgreSQL < 11)
- Creating an index without CONCURRENTLY (locks writes for duration)
- Adding NOT NULL constraint without default on existing table
- Renaming a column (can break active queries)

**Safe alternatives:**
```sql
-- GOOD — non-locking index creation (PostgreSQL)
CREATE INDEX CONCURRENTLY idx_orders_status ON orders(status);

-- GOOD — add nullable column first, then backfill, then add constraint
ALTER TABLE orders ADD COLUMN status text;
UPDATE orders SET status = 'pending' WHERE status IS NULL;
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
```

### Connection Management

**Detection signals:**
- Application creates connections directly instead of through a pool
- Pool min/max sizes not configured (relying on defaults)
- No connection validation/health check (stale connections cause errors)
- Missing `idle_timeout` (connections held open indefinitely)
- Transaction left open (holding a connection while doing non-DB work)

### Schema Anti-Patterns

- **EAV (Entity-Attribute-Value)**: Turns indexed column lookups into full-table scans
- **Polymorphic associations**: `type` + `id` columns without proper indexing for each type
- **JSON columns with WHERE**: `WHERE data->>'field' = 'value'` without GIN/GiST index
- **Soft deletes without partial index**: `WHERE deleted_at IS NULL` scans all rows including deleted
