# Resource Lifecycle & Teardown Patterns

Reference for integration-review Phase 4 (resource lifecycle and teardown).

## Pattern: Acquire → Use → Release

Every resource follows this lifecycle. The integration-review checks that
the Release step exists for every Acquire step, in ALL code paths (success,
error, and cleanup/shutdown).

## TypeScript / JavaScript

### Database Connections

```
ACQUIRE: new Pool(), createConnection(), mongoose.connect(), prisma.$connect()
RELEASE: pool.end(), connection.close(), mongoose.disconnect(), prisma.$disconnect()
CHECK:   finally block, process signal handler, server.close callback
```

```bash
# Find acquisitions
grep -rn 'new Pool\|createConnection\|mongoose\.connect\|prisma\.\$connect\|createClient' --include='*.ts' --include='*.js'
# Find releases — cross-reference
grep -rn '\.end()\|\.close()\|\.disconnect()\|prisma\.\$disconnect\|\.quit()' --include='*.ts' --include='*.js'
```

### Event Listeners

```
ACQUIRE: .on(), .addEventListener(), .subscribe(), EventEmitter.addListener()
RELEASE: .off(), .removeEventListener(), .unsubscribe(), .removeListener(), .removeAllListeners()
CHECK:   useEffect cleanup return, componentWillUnmount, server shutdown, afterEach
```

```bash
# Find all listener registrations
grep -rn '\.on(\|\.addEventListener(\|\.addListener(\|\.subscribe(' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx'
# Find removals
grep -rn '\.off(\|\.removeEventListener(\|\.removeListener(\|\.removeAllListeners(\|\.unsubscribe(' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx'
```

### Timers

```
ACQUIRE: setInterval(), setTimeout() [when stored in variable for later clearing]
RELEASE: clearInterval(), clearTimeout()
CHECK:   useEffect cleanup, componentWillUnmount, server shutdown, afterEach
```

```bash
grep -rn 'setInterval\|setTimeout' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' | grep -v 'node_modules\|dist\|build'
grep -rn 'clearInterval\|clearTimeout' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx'
```

### Child Processes / PTY Sessions

```
ACQUIRE: spawn(), exec(), fork(), new PTY(), pty.spawn()
RELEASE: .kill(), .destroy(), process.kill(pid), pty.kill(), pty.destroy()
CHECK:   error handler, SIGTERM/SIGINT handler, parent process exit
```

```bash
grep -rn 'child_process\|\.spawn(\|\.exec(\|\.fork(\|new PTY\|pty\.spawn\|node-pty' --include='*.ts' --include='*.js'
grep -rn '\.kill(\|\.destroy(' --include='*.ts' --include='*.js'
```

### WebSocket Connections

```
ACQUIRE: new WebSocket(), io.connect(), ws.connect()
RELEASE: ws.close(), socket.disconnect(), ws.terminate()
CHECK:   error handler, reconnect logic, server shutdown
```

### File Handles / Streams

```
ACQUIRE: fs.open(), fs.createReadStream(), fs.createWriteStream()
RELEASE: .close(), stream.destroy(), stream.end()
CHECK:   finally block, error handler, pipeline() (auto-closes)
```

## React-Specific Patterns

### useEffect Cleanup

Every `useEffect` that acquires a resource MUST return a cleanup function:

```typescript
// CORRECT
useEffect(() => {
  const timer = setInterval(fn, 1000);
  return () => clearInterval(timer);  // ← cleanup
}, []);

// BROKEN — no cleanup
useEffect(() => {
  const timer = setInterval(fn, 1000);
  // Missing return cleanup — timer leaks on unmount
}, []);
```

```bash
# Find useEffect hooks — manually check each for cleanup return
grep -rn 'useEffect(' --include='*.tsx' --include='*.jsx' -A 10
# Look for useEffect blocks containing acquire patterns but no cleanup return
```

### Subscription Patterns

```typescript
// CORRECT
useEffect(() => {
  const sub = eventBus.subscribe('event', handler);
  return () => sub.unsubscribe();
}, []);

// BROKEN
useEffect(() => {
  eventBus.on('event', handler);
  // No off() in cleanup — handler accumulates on each re-render
}, []);
```

## Rust

### File / Resource Handles

Rust's ownership system handles most cleanup via `Drop`, but check for:

```
ACQUIRE: File::open(), TcpStream::connect(), spawn()
RELEASE: Automatic via Drop UNLESS stored in Arc/Mutex/static
CHECK:   Arc<Mutex<Resource>> — verify explicit cleanup exists
         static/lazy_static resources — verify shutdown handler
```

```bash
# Resources that escape RAII via Arc/static
grep -rn 'Arc<Mutex<\|lazy_static!\|OnceCell\|once_cell' --include='*.rs'
# Verify corresponding cleanup in shutdown/drop
```

### Tokio Tasks

```
ACQUIRE: tokio::spawn(), task::spawn_local()
RELEASE: JoinHandle.abort(), cancellation token
CHECK:   Spawned tasks should be tracked and cancelled on shutdown
```

```bash
grep -rn 'tokio::spawn\|task::spawn' --include='*.rs'
grep -rn '\.abort()\|CancellationToken\|shutdown' --include='*.rs'
```

## Python

### Context Managers (preferred)

```python
# CORRECT — automatic cleanup
with open('file') as f:
    data = f.read()

# BROKEN — manual management without cleanup
f = open('file')
data = f.read()
# f.close() missing
```

```bash
# Find open() without 'with' context manager
grep -rn '[^w]open(' --include='*.py' | grep -v 'with\|#'
# Find DB connections without context manager
grep -rn 'connect(' --include='*.py' | grep -v 'with\|#\|import'
```

### asyncio Tasks

```
ACQUIRE: asyncio.create_task(), loop.create_task()
RELEASE: task.cancel(), gather with return_exceptions=True
CHECK:   Shutdown handler cancels all tasks
```

## Test-Specific Teardown

### Jest / Vitest

```
SETUP:    beforeAll(), beforeEach()
TEARDOWN: afterAll(), afterEach()
```

Every `beforeAll` that acquires a resource needs a matching `afterAll`.
Every `beforeEach` that acquires needs a matching `afterEach`.

```bash
# Count setup vs teardown — imbalance indicates missing cleanup
grep -c 'beforeAll\|beforeEach' --include='*.test.*' --include='*.spec.*' -r .
grep -c 'afterAll\|afterEach' --include='*.test.*' --include='*.spec.*' -r .
```

### pytest

```
SETUP:    @pytest.fixture (with yield)
TEARDOWN: Code after yield in fixture, or finalizer
```

```bash
# Fixtures without yield — may be missing teardown
grep -rn '@pytest.fixture' --include='*.py' -A 5 | grep -v yield
```

## Shutdown Handler Completeness

For servers and long-running processes, verify the shutdown handler closes ALL resources:

```bash
# Find shutdown handlers
grep -rn 'SIGTERM\|SIGINT\|process\.on.*exit\|shutdown\|graceful' --include='*.ts' --include='*.js' --include='*.rs' --include='*.py'
```

Then verify each resource type opened at startup has a corresponding close in the handler:
- DB connections
- HTTP server
- WebSocket server
- Background tasks/timers
- File watchers
- Child processes
- Cache connections (Redis, etc.)
