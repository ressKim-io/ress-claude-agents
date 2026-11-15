---
name: rust-crdt-sync
description: "Rust CRDT 협업 편집 동기화 — yrs·automerge·loro 선택, 문서당 actor, y-sync·awareness, 메시지 단위 권한 필터, update log·snapshot·compaction, 수렴성 테스트. Use when Rust 로 실시간 동시 편집 서버를 만들거나 CRDT 라이브러리와 저장 구조를 고를 때."
---

# Rust CRDT Sync — 실시간 동시 편집 서버

기본 조합은 **yrs + `yrs::sync` 직접 구성, 문서마다 actor 하나**다. 이 skill 은 sync engine 고유의 결정(라이브러리·프로토콜·권한·저장·수렴성 테스트)만 다룬다. core/shell 분리는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md), actor·종료 공통 규칙은 [rust-async-tokio](../rust-async-tokio/SKILL.md), close code 매핑은 [rust-error-handling](../rust-error-handling/SKILL.md) 이 맡는다.

## Quick Reference (결정 트리)

```
CRDT 라이브러리는 프론트 에디터와 제품 모델이 정한다
├── Yjs 생태계 에디터(ProseMirror·Tiptap·BlockNote), 블록 문서 ──> yrs + yrs::sync 직접 구성
├── 레이어 트리 이동·time travel 이 핵심 (캔버스) ──────────────> loro (LoroTree, checkout)
├── git 식 history·branch merge 가 핵심 ─────────────────────────> automerge (sync 계층은 착수 때 재조사)
└── Figma 와 같은 모델 ──────────────────────────────────────────> CRDT 없이 서버 권위 LWW + fractional index

서버 구조 (yrs 기준)
├── 문서 상태 ──> 문서당 actor 하나가 Awareness(Doc 포함)를 단독 소유 ──────── §2
├── 메시지 ────> MessageReader 로 풀어 메시지마다 권한 검사 → handle_message ── §2
├── awareness ─> 연결에 묶인 client id 항목만 적용·중계, 30초 만료는 직접 ──── §3
├── 권한·에러 ─> upgrade 전 토큰 검증(401), 에러 분류는 core 에서 한 번 ──── §4
├── 트랜잭션 ──> 블록 범위로 좁히고 같은 Doc 에서 중첩하지 않는다 ─────────── §5
├── 저장·확장 ─> update log + snapshot + compaction, 문서 하나 = 노드 하나 ── §6
└── 테스트 ────> 수렴성 proptest + 단절·재연결 시뮬레이션 (turmoil) ───────── §7
```

착수 전에 정할 것 — 코드가 아니라 제품이 정하는 값이다. handshake 시작 주체(§3)와 `small-client` 필요 여부(§1)도 여기에 든다.

| 결정 | 선택지 | 갈리는 것 |
|---|---|---|
| ack 정책 | (a) persist 후 broadcast (b) broadcast 후 비동기 persist (Figma) | (b) 는 crash 때 최근 수백 ms 편집을 잃을 수 있다 |
| 리비전 보기 | 필요하면 `skip_gc: true` | GC 를 전제로 한 compaction 과 함께 쓸 수 없다 |
| awareness client id | (a) 프론트가 `provider.awareness.clientID` 를 토큰 요청에 넣고 Go 가 claim 에 담는다 (b) 서버가 연결의 첫 자기 항목으로 묶는다 | (a) 는 `doc.clientID` 를 나중에 읽지 않는다. Yjs 는 id 충돌을 감지하면 `doc.clientID` 를 다시 뽑지만 awareness 는 만들 때 복사한 id 를 계속 쓴다. (b) 는 클라이언트가 남의 항목도 다시 보내서 잘못 묶일 수 있다 (§3) |
| Go 가 문서 내용을 읽나 | 읽는다면 누가 Doc 을 해석해 넘길지 | 엔진 API 경계, snapshot 형식 공개 여부 |

## 1. 라이브러리 선택

| | yrs | loro | automerge | diamond-types |
|---|---|---|---|---|
| 강점 | Yjs 와 동작·binary protocol 호환이 목표, Yjs 에디터 바인딩 생태계 | movable tree(순환 자동 방지), Fugue + Eg-walker, 1.0 부터 데이터 형식 안정 | 3.0 에서 메모리 10배 이상 감소(공식 블로그), rich text | plain text 편집 |
| 서버 동기화 | `yrs::sync` 로 직접 구성. y-sync crate 는 정체 | 네트워크·저장은 범위 밖. loro-websocket-server 는 개발·테스트용, 메시지당 256 KiB | 신뢰할 수 있고 순서가 보장되는 스트림 + peer 별 State 전제. automerge-repo(Rust) 는 JS 비호환, samod 는 README 경고와 공식 블로그가 상충 ⚠️ | — |
| 주의 | `small-client`: 문서는 yrs v0.26 이하·yjs pre v14 호환용 32-bit ClientID 라고 적는다(기본 53-bit). npm yjs latest 는 13.x, 14 는 beta 라 필요 여부는 ⚠️ Yjs 13.x 클라이언트와 상호운용 테스트로 정한다 | `LoroCounter` 는 `counter` feature, `set_peer_id` 는 유일해야 한다 | Rust native 메모리 수치 없음 ⚠️ | plain text 만 → 제외 |

- **Figma 는 true CRDT 가 아니다.** 여러 CRDT 에서 영감을 받아 조합했다고 적는다. 서버 권위, LWW, 순환 parent 거부, fractional indexing 이다. 문서마다 Rust child process 를 띄우고 "each document lives exclusively on one specific worker", journal 은 비동기로 쓰고 30~60초마다 checkpoint 한다. **Notion** 은 LWW 에서 RGA + Peritext 로 직접 옮겼고 라이브러리는 밝히지 않았다. 둘을 "Yjs 기반"으로 적지 않는다. **블록 에디터 함정**: yrs + y-prosemirror 는 블록 split 을 삭제 + 삽입으로 모델링해서, 동시에 들어온 편집이 원래 블록에 남는다. Notion 은 "text slice" 로 풀었다. 블록 문서라면 프론트 스키마에서 먼저 검토한다.
- **래퍼 crate 를 쓰지 않는다.** yrs-warp 0.9 는 yrs ^0.24, yrs-axum 0.8 은 ^0.18, y-sweet-core 0.9 는 ^0.19 에 묶여 0.28 과 타입을 주고받지 못한다. yrs-warp 의 sink 는 `Lagged` 를 받으면 루프가 끝나 느린 peer 가 연결된 채로 update 를 못 받는다. **yrs 0.28 에서도 호환이 깨졌다.** `Subscription` 제거, 구독은 key 를 받는다(`observe_update_v1("key", ..)`), `Any::Int`/`Float` 는 `Number` 로 통합됐다. 0.27 예제는 그대로 컴파일되지 않는다. 성능 비교에 dmonad crdt-benchmarks 를 쓰지 않는다. 옛 JS/WASM 빌드(ywasm 0.9 등)를 잰 것이다. Rust native 는 criterion 으로 직접 잰다.

## 2. 문서당 actor — Room(core) 과 DocActor(shell)

`Arc<Mutex<Doc>>`·`Arc<RwLock<Awareness>>` 로 공유하지 않는다. `transact_mut` 은 lock 을 얻을 때까지 **스레드를 block** 하므로(wasm 에서는 panic) tokio worker 가 멈춘다. 또 `Protocol` 의 handle 계열 메서드가 `&mut Awareness` 를 받으니, Awareness(안에 Doc 포함)를 actor 하나가 통째로 소유한다. Spring 으로 치면 문서마다 단일 스레드 executor 에 상태를 가둔 모양이다. yrs 의 `sync` feature 없이 Awareness 를 가진 task 를 `tokio::spawn` 하면 observer 콜백 타입 때문에 E0277(cannot be sent / shared between threads safely)이 난다. `spawn_local` 로 우회하지 않는다.

**core (`sync-core`)** — IO 도 OS 시계도 없다. bytes 와 시각을 넣으면 보낼 것을 돌려준다. 그래서 `[dependencies]` 는 `yrs = { version = "0.28", features = ["sync"] }`(없으면 Awareness 가 Send·Sync 가 아니다)와 `thiserror = "2"` 뿐이다. sync-server 가 여기에 `sync-core`, `tokio`(features `rt-multi-thread`·`macros`·`sync`·`time`), `axum = { version = "0.8", features = ["ws"] }`, `metrics`, `tracing` 을 더한다. axum 의 `ws` feature 는 tokio 를 켜므로 close frame 을 아는 타입은 core 에 두지 않는다(§4).

```rust
use std::sync::{Arc, atomic::{AtomicU64, Ordering}};
use yrs::sync::{Awareness, DefaultProtocol, Message, MessageReader, Protocol, SyncMessage};
use yrs::{ClientID, Doc, encoding::read::Cursor, updates::{decoder::DecoderV1, encoder::Encode}};
use crate::error::RoomError;
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Role { Editor, Viewer }
/// 연결 하나의 신원. shell 이 토큰에서 만든다. client_id 가 None 이면 awareness 를 받지 않는다.
pub struct PeerCtx { pub role: Role, pub client_id: Option<ClientID> }
#[derive(Debug, PartialEq)]
pub enum Outbound { Reply(Vec<u8>), DocUpdate(Vec<u8>), Presence(Vec<u8>) }
#[must_use = "error 가 있으면 out 을 보낸 뒤 연결을 닫는다"]
pub struct Handled { pub out: Vec<Outbound>, pub error: Option<RoomError> }
pub struct Room { awareness: Awareness, now_ms: Arc<AtomicU64>, dropped: u64 }
impl Room {
    pub fn new(doc: Doc) -> Self {
        let now_ms = Arc::new(AtomicU64::new(0));
        let clock = Arc::clone(&now_ms);
        let awareness = Awareness::with_clock(doc, move || clock.load(Ordering::Relaxed));
        Self { awareness, now_ms, dropped: 0 }
    }
    pub fn handle_client(&mut self, peer: &PeerCtx, frame: &[u8], now_ms: u64) -> Handled {
        self.now_ms.store(now_ms, Ordering::Relaxed);
        let mut decoder = DecoderV1::new(Cursor::new(frame));
        let mut out = Vec::new();
        for msg in MessageReader::new(&mut decoder) {
            match msg.map_err(Into::into).and_then(|msg| self.step(peer, msg)) {
                Ok(produced) => out.extend(produced),
                Err(err) => return Handled { out, error: Some(RoomError::from(err)) },
            }
        }
        Handled { out, error: None }
    }
    fn step(&mut self, peer: &PeerCtx, msg: Message) -> Result<Vec<Outbound>, yrs::sync::Error> {
        let Some(msg) = authorize(peer, msg) else {
            self.dropped += 1; // 끊지 않는다. viewer 도 서버 SyncStep1 에 SyncStep2 로 답한다
            return Ok(Vec::new());
        };
        let relay = relay_of(&msg);
        let reply = DefaultProtocol.handle_message(&mut self.awareness, msg)?;
        Ok(reply.map(|m| Outbound::Reply(m.encode_v1())).into_iter().chain(relay).collect())
    }
}
fn authorize(peer: &PeerCtx, msg: Message) -> Option<Message> {
    match msg {
        Message::Sync(SyncMessage::SyncStep2(_) | SyncMessage::Update(_)) if peer.role == Role::Viewer => None,
        Message::Awareness(mut update) => {
            update.clients.retain(|id, _| Some(*id) == peer.client_id); // 인증이 없으니 자기 항목만 (§3)
            (!update.clients.is_empty()).then_some(Message::Awareness(update))
        }
        other => Some(other),
    }
}
fn relay_of(msg: &Message) -> Option<Outbound> {
    match msg {
        Message::Sync(SyncMessage::SyncStep2(u) | SyncMessage::Update(u)) => Some(Outbound::DocUpdate(u.clone())),
        Message::Awareness(_) => Some(Outbound::Presence(msg.encode_v1())),
        _ => None,
    }
}
```

- `handle_client` 는 decode → 권한(`authorize`) → 적용만 보이게 했다(Composed Method). `Protocol::handle()` 은 reply 만 돌려주고 무엇을 중계할지 알려주지 않으며, role·peer 정보를 받지 않고, 첫 에러에서 그 앞 reply 까지 버린다(crate 소스). role 별 `Protocol` 구현으로 `handle_update` 등을 덮어쓸 수도 있지만, 권한·relay·계측을 한곳에 모으려고 `MessageReader` 로 직접 돈다. 대신 `relay_of` 는 받은 update 를 그대로 넘기므로, 새 내용이 없는 SyncStep2(접속마다 온다)도 journal 한 행과 peer N 명 broadcast 가 된다. 멱등이라 결과는 맞고 비용만 든다. y-websocket-server 는 Doc 의 `update` 이벤트(Yjs 는 내용이 있을 때만 낸다)에서 중계한다. **에러가 나도 앞서 적용한 출력은 버리지 않는다.** `[Update A][깨진 Update]` frame 이면 A 는 이미 Doc 에 들어갔다. 여기서 `out` 을 버리면 다른 peer 와 journal 이 A 를 받지 못해 재접속 전까지 서버와 어긋난다. 그래서 `Handled` 로 함께 돌려주고 shell 은 `out` 을 다 보낸 뒤 연결을 닫는다(로컬 회귀 테스트, 위 코드를 되돌리면 실패하는 것도 확인).

**shell (`sync-server`)** — 발췌다. `Command`(Join·Frame·Leave), `Peer { ctx: PeerCtx, out }`, `DocHandle`(actor 의 `Sender<Command>` 를 감싼 `join`·`frame`·`leave`), `run`·`handle`·`on_frame`·`broadcast`·`send_to`·`close`·`now_ms` 는 생략했다. `PeerCtx` 는 연결 때 토큰에서 만들고(§4), 클라이언트가 보낸 값으로 정하지 않는다.
- `run` 은 `select!` 로 `rx.recv()` 와 5초 `interval` 을 함께 기다리고, tick 마다 `room.handle_timeout(now)`(§3) 결과를 broadcast 한다. 끝낼 때는 `None => break` 로 쓴다. `else => break` 는 interval 분기가 살아 있어 실행되지 않는다. `broadcast(except, bytes)` 는 `peers.retain(|id, p| Some(*id) == except || deliver(&p.out, ..))` 로 보내지 못한 peer 를 뺀다. `on_frame` 은 `Handled.out` 부터 처리한다. `Reply` 는 보낸 peer 에게, `Presence` 는 나머지에게 보낸다. `DocUpdate` 는 journal 묶음(§6)에 넣은 뒤 `Message::Sync(SyncMessage::Update(..))` 로 감싸 곧바로 나머지에게 보낸다(착수 전 결정 표의 ack (b). (a) 라면 broadcast 를 flush 완료 뒤로 미룬다). 그다음 `error` 가 있으면 `close(peer, &SyncError::from(err))` 에서 `close_frame()` 으로 넘긴다.

```rust
const OUTBOUND_CAPACITY: usize = 64; // 예시값. 편집 빈도와 문서 크기를 재서 정한다
const SEND_TIMEOUT: Duration = Duration::from_secs(10); // 예시값
/// false 면 peer 를 뺀다. 느린 peer 를 기다리면 같은 문서의 모든 peer 가 함께 멈춘다.
fn deliver(out: &mpsc::Sender<WsMessage>, msg: WsMessage) -> bool {
    match out.try_send(msg) {
        Ok(()) => true,
        Err(TrySendError::Full(_)) => { metrics::counter!("crdt_slow_client_dropped_total").increment(1); false }
        Err(TrySendError::Closed(_)) => false,
    }
}
pub async fn serve_peer(mut socket: WebSocket, doc: DocHandle, ctx: PeerCtx) {
    let (tx, mut rx) = mpsc::channel(OUTBOUND_CAPACITY);
    let Ok(id) = doc.join(ctx, tx).await else { return };
    loop {
        tokio::select! {
            out = rx.recv() => {
                // None: actor 가 이 peer 를 뺐거나 actor 가 끝났다. 어느 쪽이든 재접속(1013)이 맞고, 큐가 찼을 수 있으니 직접 보낸다
                let msg = out.unwrap_or_else(|| WsMessage::Close(SyncError::SlowConsumer.close_frame()));
                let is_close = matches!(msg, WsMessage::Close(_));
                // 읽지 않는 클라이언트에게는 send 가 끝나지 않는다
                let sent = timeout(SEND_TIMEOUT, socket.send(msg)).await;
                if is_close || !matches!(sent, Ok(Ok(()))) { break }
            }
            inbound = socket.recv() => match inbound {
                Some(Ok(WsMessage::Binary(bytes))) => if doc.frame(id, bytes).await.is_err() { break },
                Some(Ok(WsMessage::Close(_)) | Err(_)) | None => break,
                Some(Ok(_)) => {} // y-sync 는 binary 만 쓴다
            },
        }
    }
    doc.leave(id).await; // actor 가 이미 뺀 peer 여도 무해하다
}
```

- 연결마다 bounded mpsc 를 두고 `try_send` 한다. Full 이면 기다리지 않고 actor 가 peer 를 뺀다(`Sender` drop). 연결 task 는 송신 채널이 닫힌 것(`rx.recv()` 가 None)을 보고 1013(`SyncError::SlowConsumer`)으로 닫은 뒤 루프를 빠져 socket 을 drop 한다. actor task 가 끝나(panic·종료) peer 별 `Sender` 가 모두 drop 돼도 같은 길로 1013 이 나간다. futures `split` 의 두 반쪽은 socket 하나를 공유한다. task 둘로 돌리며 writer 가 끝날 때 reader 를 abort 하지 않으면, reader 가 연결을 쥔 채 update 를 못 받는 peer 가 남는다. 한 `select!` 루프는 이 실수를 구조적으로 없앤다. actor 가 오류로 보낸 close frame 은 그대로 전달하고 끝난다(1013 을 덧붙이지 않는다). 단 그 close frame 도 `try_send` 라 큐가 차 있으면 버려지고, 클라이언트는 1013 을 받는다. 끊긴 클라이언트는 재접속하며 SyncStep1(state vector)을 보내므로 SyncStep2 로 빠진 부분을 받는다. `tokio::sync::broadcast` 는 가득 차면 오래된 값을 덮어쓰고 뒤처진 receiver 에 `Lagged` 만 주므로, 연결은 살아 있는데 update 가 빠진다. **registry**(doc_id → actor handle): DashMap 문서는 map 안의 참조를 쥔 채 같은 map 을 부르면 deadlock 날 수 있다고 적으니 `Ref` 를 `.await` 너머로 들고 가지 않는다. 첫 로드 중에 연결이 몰리면 actor 가 두 번 뜰 수 있으니 entry 에 loading 상태를 두거나 registry 자체를 actor 로 직렬화한다. **문서 내리기**: registry 가 Sender 를 쥐고 있는 동안 `recv()` 는 None 을 주지 않으므로 `None => break` 에 닿지 않고, 한 번 연 문서가 전부 메모리에 남는다. 마지막 peer 가 나가고 idle 시간이 지나면 actor 가 checkpoint(§6) 한 뒤 registry 에 자기 entry 를 지워 달라고 한다. 그사이 들어온 연결은 loading 과 같은 방식(closing 상태)으로 기다리게 한다.

## 3. y-sync 프로토콜과 awareness

메시지 태그는 SYNC=0(하위 STEP1=0 state vector · STEP2=1 부족분 update · UPDATE=2), AWARENESS=1, AUTH=2, QUERY_AWARENESS=3 이다. SyncStep1 은 `txn.state_vector()` 이고, 받은 쪽은 그 state vector 로 `encode_state_as_update_v1(&sv)` 를 만들어 SyncStep2 로 돌려준다. 양쪽이 한 번씩 주고받으면 같아진다. Yjs update 는 교환·결합·멱등 법칙을 만족하므로 받은 update 를 그대로 중계해도 중복·역순 도착에 결과가 같다(§7 에서 property 로 확인).

- frame 하나에 메시지가 여러 개 이어 붙을 수 있다. `MessageReader` 는 `EndOfBuffer` 를 에러가 아니라 반복 종료로 처리한다(crate 소스). 끝이 잘린 메시지는 조용히 버려진다. **handshake 시작 주체가 사양과 구현에서 다르다.** PROTOCOL.md 개정판(master)은 클라이언트가 SyncStep1 로 시작하고 "The server SHOULD NOT initiate" 라고 적는다(마지막 릴리스 태그의 문서에는 없는 문장이다). 반면 yrs `DefaultProtocol::start` 와 y-websocket-server 는 연결 직후 서버가 SyncStep1 을 보낸다. 하나를 골라 문서화한다. `AsyncProtocol` 은 `yrs::sync::protocol` 에 있지만 `yrs::sync` 로 re-export 되지 않는다. awaitable 트랜잭션용이라 Doc 을 여러 task 가 공유할 때 의미가 있다. actor 단독 소유면 동기 `Protocol` 로 충분하다(이 skill 의 판단).

**awareness**(커서·이름·접속 상태) 규칙: clock 이 엄밀히 클 때만 적용, 30초 갱신이 없으면 제거(MUST), 클라이언트는 적어도 15초마다 재전송(SHOULD), 클라이언트는 자기 항목만 바꿔야 한다(MUST). 그런데 **인증은 없고**, PROTOCOL.md 는 신원을 상위 계층이 강제해야 한다고 적는다. yrs `Awareness` 에는 만료 타이머가 없다. 직접 만료시키려면 `iter`·`meta` 로 `last_updated` 를 읽고 `remove_state` 로 지운다. `Awareness::new(doc)` 은 내부에서 SystemClock 을 쓰므로 core 에서는 `with_clock` 으로 시계를 주입한다. yrs 는 `Fn() -> Timestamp + Send + Sync` 클로저도 `Clock` 으로 받는다. 그래서 §2 `Room::new` 는 `Rc`·`Cell` 이 아니라 `Arc<AtomicU64>` 를 캡처한다.

```rust
const AWARENESS_TIMEOUT_MS: u64 = 30_000;
impl Room {
    pub fn handle_timeout(&mut self, now_ms: u64) -> Option<Vec<u8>> {
        self.now_ms.store(now_ms, Ordering::Relaxed);
        let expired: Vec<ClientID> = self.awareness.iter()
            .filter(|(_, s)| s.data.is_some() && now_ms.saturating_sub(s.last_updated) >= AWARENESS_TIMEOUT_MS)
            .map(|(id, _)| id)
            .collect();
        if expired.is_empty() { return None; }
        for id in &expired { self.awareness.remove_state(*id); }
        let update = self.awareness.update_with_clients(expired)
            .expect("remove_state keeps the entry (data = None), so every id is still present");
        Some(Message::Awareness(update).encode_v1())
    }
}
```

- 여러 항목이 함께 만료되면 바이트 순서는 `AwarenessUpdate.clients`(std `HashMap`)의 순회 순서라 실행마다 다를 수 있다. `expired` 를 정렬해도 소용없다. 의미는 같으니 테스트는 decode 해서 비교한다. 이 순서는 yrs 타입이 정해 core 에서 `BTreeMap` 으로 바꿀 수 없지만, 바이트 순서에 기대는 코드가 없으므로 [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 HashMap 순서 규칙(core 는 순회 순서에 기대지 않는다)을 어기지 않는다. **신원은 서버가 강제한다.** §2 `authorize` 는 연결에 묶인 client id 의 항목만 남기고 남의 항목은 끊지 않고 버린다. 정상 클라이언트도 남의 항목을 보내기 때문이다. y-websocket 클라이언트는 로컬 상태가 있으면 연결 직후 자기 항목(`[doc.clientID]`)을 보내지만, 받은 남의 변경도 그대로 다시 보내고 awareness query 에는 아는 상태 전부로 답한다. 그래서 "처음 온 단일 항목"으로 묶으면 남의 id 에 묶일 수 있다(착수 전 결정 표). 이름·색 같은 사용자 필드는 같은 자리에서 claim 값으로 덮어쓴다. 필드 이름은 프론트 규약이라 코드에서 뺐다. 연결이 끝나면 묶인 id 의 상태를 `remove_state` 로 지우고 나머지에게 알린다(y-websocket-server 도 연결별 client id 를 기억했다가 닫힐 때 지운다).

## 4. 권한 — upgrade 전 한 번, 메시지마다 한 번

Go 가 짧은 수명 토큰(문서·사용자·role·만료, client id 바인딩 (a) 라면 client id 까지)을 발급하고 Rust 는 WebSocket upgrade **전에** 검증한다. upgrade 뒤에는 HTTP 상태 코드를 줄 수 없고 close frame 뿐이다. Spring 의 `HandshakeInterceptor.beforeHandshake` 자리다.

```rust
const MAX_MESSAGE_BYTES: usize = 8 << 20; // 예시값. 실제 문서 크기 분포를 재서 정한다
/// Go 가 발급한 단기 토큰의 claim. 문서 ID 도 경로가 아니라 claim 에서만 읽는다.
pub struct Grant { pub doc_id: DocId, pub peer: PeerCtx }
impl FromRequestParts<AppState> for Grant {
    type Rejection = StatusCode;
    async fn from_request_parts(parts: &mut Parts, app: &AppState) -> Result<Self, Self::Rejection> {
        app.tokens.verify(parts).ok_or(StatusCode::UNAUTHORIZED)
    }
}
/// extractor 는 인자 순서대로 돈다. Grant 를 앞에 두면 WS 헤더 검사보다 먼저 401 로 답한다(어느 순서든 101 을 돌려주기 전에는 upgrade 되지 않는다).
pub async fn connect(grant: Grant, State(app): State<AppState>, ws: WebSocketUpgrade) -> Result<Response, StatusCode> {
    let doc = app.registry.open(&grant.doc_id).await.map_err(|err| {
        tracing::warn!(error = %err, "document load failed");
        StatusCode::SERVICE_UNAVAILABLE // upgrade 전이라 HTTP 로 답한다. 실패가 503 하나뿐이라 여기서 분류한다
    })?;
    Ok(ws.max_message_size(MAX_MESSAGE_BYTES).on_upgrade(move |socket| serve_peer(socket, doc, grant.peer)))
}
```

- 브라우저의 `WebSocket` 생성자는 URL 과 subprotocol 목록만 받으므로 `Authorization` 헤더를 붙일 수 없다. 토큰은 query string·`Sec-WebSocket-Protocol`·cookie 중 하나로 오고, 그래서 `verify` 가 `Parts` 전체를 받는다. cookie 라면 RFC 6455 §10.2 대로 `Origin` 이 기대한 출처인지 보고 아니면 403 으로 답한다. `open` 은 Postgres 에서 문서를 읽으므로 실패할 수 있고, extractor 가 모두 통과한 뒤에만 불린다. 이 엔드포인트의 HTTP 실패는 503 하나라 `AppError: IntoResponse` 를 두지 않았다. 종류가 늘면 [rust-error-handling](../rust-error-handling/SKILL.md) 의 `IntoResponse` 한 곳으로 옮긴다. `DocId` 는 uuid newtype 이다(parse, don't validate: [rust-idioms](../rust-idioms/SKILL.md)). axum 기본값은 메시지 64 MB, frame 16 MB, write buffer 128 KiB, `max_write_buffer_size` 무제한이다. write buffer 는 쓰기가 실패할 때만 쌓이므로 느린 클라이언트 방어가 아니다(§2 의 bounded mpsc 가 맡는다). 반대로 `max_message_size` 를 너무 낮추면 큰 문서의 첫 SyncStep2 나 오프라인 편집 뒤 SyncStep2 가 거절되어 재동기화가 영영 실패한다.

**메시지 단위 필터.** read-only 판정은 메시지 앞 2바이트로 한다. `00 00`(SyncStep1)은 허용, `00 01`(SyncStep2)·`00 02`(Update)는 거부다. 이것을 frame 에 적용하면 뚫린다.

```rust
// ❌ BAD: frame 앞 2바이트만 본다 — [SyncStep1][Update] 를 한 frame 에 붙이면 통과한다
pub fn is_write_frame(frame: &[u8]) -> bool {
    frame.starts_with(&[0, 1]) || frame.starts_with(&[0, 2])
}
```

✅ GOOD 는 §2 의 `authorize` 다. decode 한 메시지마다 검사하고, viewer 의 쓰기는 **끊지 않고 버리고 센다**. viewer 도 서버의 SyncStep1 에 정상적으로 SyncStep2 로 답하므로, 거부를 연결 종료로 처리하면 viewer 가 접속할 때마다 끊긴다. viewer 에게 SyncStep1 을 아예 보내지 않는 방법도 있다.

**에러는 core 에서 한 번 나눈다.** `RoomError` 는 close code 를 모른다. yrs 에러 variant 를 wildcard 없이 나열해서, yrs 가 variant 를 추가하면 컴파일이 멈추고 다시 분류하게 한다.

```rust
#[derive(Debug, thiserror::Error)]
pub enum RoomError {
    #[error("client sent an invalid sync message")]
    Client(#[source] yrs::sync::Error),
    #[error("server failed to handle a sync message")]
    Internal(#[source] yrs::sync::Error),
}
impl From<yrs::sync::Error> for RoomError {
    fn from(err: yrs::sync::Error) -> Self {
        use yrs::sync::Error as E;
        match err {
            E::DecodingError(_) | E::Update(_) | E::Unsupported(_) | E::PermissionDenied { .. } => Self::Client(err),
            // 받은 awareness JSON 은 해석하지 않는다. 이 variant 는 서버가 자기 상태를 인코딩할 때만 난다
            E::AwarenessEncoding(_) | E::IO(_) | E::Other(_) => Self::Internal(err),
        }
    }
}
```

- 클라이언트 잘못: 깨진 bytes(`DecodingError`), 디코딩은 되지만 구조가 틀린 update(`Update`, yrs 0.28 의 `UpdateError` 는 `InvalidParent` 하나), 모르는 태그(`Unsupported`), 거부 사유를 담아 보낸 Auth(`PermissionDenied`). 서버 내부 오류(1011)로 보내지 않는다(깨진 update·모르는 태그·거부 Auth 가 `Client` 인 것은 로컬 테스트). sync-server 의 `SyncError` 가 `Room(#[from] RoomError)` 으로 감싸고, `close_frame()` 한 곳에서 `Client` → 1008, `Internal` → 1011 을 고른다([rust-error-handling](../rust-error-handling/SKILL.md)). core 가 axum `CloseFrame` 을 알면 core 가 tokio 를 끌어온다.

## 5. 트랜잭션 — 좁게, 중첩 없이

`transact_mut()` 은 lock 을 얻을 때까지 block 하고, `try_transact_mut()` 은 즉시 `ExclusiveAcqFailed` 를 돌려준다. 읽기 트랜잭션도 쓰기 트랜잭션이 살아 있으면 block 된다. **같은 스레드에서 같은 Doc 에 트랜잭션을 중첩할 때 둘 중 하나라도 쓰기(`transact_mut`)면 영원히 멈춘다.** 쓰기 lock 은 재진입을 허용하지 않아서 안쪽은 바깥이 끝나기를 기다리고, 바깥은 안쪽이 끝나야 끝난다. 읽기 안의 읽기는 공유 lock 이라 멈추지 않는다. 단 yrs 가 쓰는 async-lock `RwLock` 은 write-preferring 이라, 다른 스레드가 쓰기를 기다리는 동안에는 새 읽기도 기다린다. actor 단독 소유면 그런 스레드는 없다. 그러나 단독 소유는 다른 task 와의 경쟁을 없앨 뿐 쓰기가 낀 중첩의 self-deadlock 은 막지 못한다. 멈춤을 테스트로 재현하지는 않는다(테스트가 끝나지 않는다). 대신 `try_*` 로 확인했다(로컬 테스트): 쓰기를 쥔 동안 `try_transact_mut()` 은 `Err`, 읽기를 쥔 동안 `try_transact()` 는 `Ok` 이고 `try_transact_mut()` 은 `Err`, 다른 스레드가 쓰기를 기다리면 새 `try_transact()` 도 `Err` 다. 흔한 경로:
- 트랜잭션을 쥔 채 `doc.get_or_insert_text(..)` 호출. 안에서 `transact_mut()` 을 다시 연다. rustdoc 은 이때 panic 한다고 적지만, 0.28 구현은 wasm 에서만 panic 이고 그 밖에서는 `write_blocking` 으로 멈춘다(crate 소스) · `observe_update_v1` 콜백 안에서 같은 Doc 의 `transact_mut()`. 콜백이 `&TransactionMut` 을 받는다는 것은 lock 이 잡혀 있다는 뜻이다. 받은 트랜잭션을 쓰고, 꼭 새로 열어야 하면 `try_transact_mut` 의 Err 를 처리한다 · 트랜잭션을 쥔 채 `DefaultProtocol.handle_message`. SyncStep2·Update 처리가 안에서 `transact_mut()` 을 연다
- 텍스트 위치 단위: `Options::offset_kind` 기본값은 `Bytes`(UTF-8)라서 "한글" 의 byte 3 에 넣으면 "한X글" 이다. yrs 는 Options 를 직렬화할 때 `Utf16` 을 Yjs 호환 값 0 으로 쓴다(소스 주석: Yjs 에는 이 옵션이 없다). JS 쪽 offset 이 UTF-16 이라는 것은 추론이다 ⚠️. 서버가 index 로 텍스트를 만진다면 y-prosemirror 와 offset 교차 테스트로 확정한다. 같은 Options 의 `client_id` 는 활성 peer 사이에서 유일해야 한다. 겹치면 문서 상태가 손상된다. 서버가 직접 편집한다면 클라이언트와 겹치지 않는 id 를 준다.

## 6. 저장과 수평 확장 — Postgres

```sql
CREATE TABLE doc_owner    (doc_id uuid PRIMARY KEY, node_id text NOT NULL, epoch bigint NOT NULL, lease_until timestamptz NOT NULL);
CREATE TABLE doc_update   (doc_id uuid NOT NULL, seq bigserial, epoch bigint NOT NULL, data bytea NOT NULL, PRIMARY KEY (doc_id, seq));
CREATE TABLE doc_snapshot (doc_id uuid PRIMARY KEY, upto_seq bigint NOT NULL, data bytea NOT NULL);
-- 소유 획득: 주인이 없거나 lease 가 끝난 문서만, epoch 를 올리며. 0 rows 면 다른 노드가 소유 중이다
INSERT INTO doc_owner (doc_id, node_id, epoch, lease_until) VALUES ($1, $2, 1, now() + $3::interval)
ON CONFLICT (doc_id) DO UPDATE SET node_id = EXCLUDED.node_id, epoch = doc_owner.epoch + 1, lease_until = EXCLUDED.lease_until
WHERE doc_owner.lease_until < now() RETURNING epoch;
-- journal append: 소유권이 그대로일 때만 들어간다. 0 rows 면 이 노드는 문서를 내려놓는다
WITH fence AS (
  UPDATE doc_owner SET lease_until = now() + $5::interval
  WHERE doc_id = $1 AND node_id = $2 AND epoch = $3
  RETURNING doc_id
)
INSERT INTO doc_update (doc_id, epoch, data) SELECT doc_id, $3::bigint, $4::bytea FROM fence;
```

- **fencing 은 모든 journal 쓰기와 같은 문장에서 epoch 를 검사해야 효과가 있다.** 값을 기록만 하면 옛 소유자가 늦게 보낸 쓰기를 막지 못한다. READ COMMITTED 에서 `UPDATE` 는 다른 트랜잭션이 먼저 바꾼 행을 만나면 그 커밋을 기다린 뒤 최신 행으로 WHERE 를 다시 평가한다. 넘겨받은 쪽이 epoch 를 올렸다면 옛 소유자의 fence 는 0 rows 가 된다. 넘겨받는 노드는 epoch 를 올린 트랜잭션을 **커밋한 뒤에** journal 을 로드한다. 그 전에 읽으면 옛 소유자가 그사이 커밋한 update 를 놓친다. `ON CONFLICT ... DO UPDATE ... WHERE` 가 거짓이면 그 행은 `RETURNING` 에 나오지 않는다(PG 문서). 파라미터 타입은 적어 두었다. INSERT 의 SELECT 목록에 나오는 `$3`·`$4` 는 `$3::bigint`·`$4::bytea`, CTE 의 `now() + $5` 는 `$5::interval` 이다. 적지 않았을 때 PG 가 무엇으로 추론하는지는 실행해 보지 않았다 ⚠️.
- 쓰기 묶음: actor 가 짧은 간격(값은 측정으로 정한다)으로 모은 `DocUpdate` 를 `merge_updates_v1` 로 합쳐 한 행에 쓴다. merge 는 GC 를 하지 않는다. awareness(`Presence`)는 저장하지 않는다. flush 를 actor 안에서 await 하면 그동안 그 문서의 메시지 처리가 멈춘다. 별도 writer task 에 넘기되, bounded 채널 두 개가 서로 `send().await` 하는 순환을 만들지 않는다(서로 기다리다 둘 다 멈춘다). actor → writer 는 `try_send` 하고 Full 이면 묶음을 actor 에 남겨 다음 묶음과 합친다. writer → actor 의 fence 0 rows(소유권 상실) 알림은 `watch` 나 oneshot 으로 보내 문서를 내려놓게 한다. 둘 다 send 가 곧바로 반환해 순환에 끼지 않는다. checkpoint 는 트랜잭션 하나다: fence → `encode_state_as_update_v1(&StateVector::default())` 를 snapshot 에 upsert(`upto_seq`) → `DELETE ... WHERE doc_id = $1 AND seq <= upto_seq`. 장기 compaction 은 merge 가 아니라 이처럼 Doc 에 적용한 뒤 다시 인코딩한다. 로드는 snapshot 에 `seq > upto_seq` 인 update 를 더한다. update 가 멱등이라 겹쳐 읽어도 결과가 같다.
- `NOTIFY` 에 update 본문을 싣지 않는다(payload 8000 bytes 미만, commit 때 전달). 소유자 변경 같은 깨우기 신호만 보낸다. sqlx·LISTEN 사용법은 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md). **문서 하나 = 노드 하나.** Figma 는 문서를 한 worker 에만 두고, Cloudflare Durable Objects 도 전역 고유 이름의 단일 스레드 객체 하나가 조정 지점이다. 라우팅은 (A) ingress consistent hash 또는 (B) 위 `doc_owner` lease 다. 다른 노드로 들어온 연결은 소유 노드로 보낸다.

## 7. 수렴성 테스트

replica 3개가 update 를 임의 순서·중복으로 받아도 내용과 state vector 가 같고, snapshot 으로 다시 로드해도 같아야 한다. §6 compaction 의 회귀 테스트를 겸한다.

```rust
use proptest::{collection::vec, prelude::*, sample::Index};
use yrs::updates::decoder::Decode;
use yrs::{ClientID, Doc, GetString, OffsetKind, Options, ReadTxn, StateVector, Text, Transact, Update};
fn apply(doc: &Doc, update: &[u8]) {
    let update = Update::decode_v1(update).expect("test updates are encoded by yrs");
    doc.transact_mut().apply_update(update).expect("a well-formed update applies");
}
fn text_and_sv(doc: &Doc) -> (String, StateVector) {
    let text = doc.get_or_insert_text("t");
    let txn = doc.transact();
    (text.get_string(&txn), txn.state_vector())
}
fn utf16_doc(id: u64) -> Doc {
    Doc::with_options(Options { offset_kind: OffsetKind::Utf16, ..Options::with_client_id(ClientID::new(id)) })
}
fn insert_at(doc: &Doc, at: &Index, s: &str) -> Vec<u8> {
    let text = doc.get_or_insert_text("t");
    let mut txn = doc.transact_mut();
    let len = text.len(&txn) as usize;
    text.insert(&mut txn, at.index(len + 1) as u32, s);
    txn.encode_update_v1()
}
proptest! {
    #[test]
    fn should_converge_when_updates_arrive_in_any_order_with_duplicates(
        edits in vec((0..3usize, any::<Index>(), "[a-z가-힣]{1,3}"), 1..16),
        picks in vec(any::<Index>(), 0..48),
    ) {
        // Given: replica 3개가 서로 모르는 채로 편집하고 update 를 남긴다
        let replicas: Vec<Doc> = (1..=3).map(utf16_doc).collect();
        let updates: Vec<Vec<u8>> = edits.iter().map(|(r, at, s)| insert_at(&replicas[*r], at, s)).collect();
        // When: 임의 순서·중복으로 받은 뒤 전부 한 번 더 받는다
        for doc in &replicas {
            for p in &picks { apply(doc, &updates[p.index(updates.len())]); }
            for u in &updates { apply(doc, u); }
        }
        // Then: 내용과 state vector 가 같고, snapshot 으로 다시 로드해도 같다
        let expected = text_and_sv(&replicas[0]);
        for doc in &replicas[1..] { prop_assert_eq!(text_and_sv(doc), expected.clone()); }
        let snapshot = replicas[0].transact().encode_state_as_update_v1(&StateVector::default());
        let loaded = utf16_doc(9);
        apply(&loaded, &snapshot);
        prop_assert_eq!(text_and_sv(&loaded), expected);
    }
}
```

- `text_and_sv` 가 `get_or_insert_text` 를 트랜잭션보다 **먼저** 부르는 이유는 §5 다. 한글 음절을 섞으려고 `OffsetKind::Utf16` 으로 맞췄다(§5). proptest 1.12 는 Rust 1.88+ 가 필요하다. helper 는 unwrap 대신 `expect(이유)` 를 쓴다. `tests/` helper 에 `allow-unwrap-in-tests` 가 적용되는지는 clippy 버전마다 다르다. 이것과 테스트 배치·이름·proptest 공통 규칙은 [rust-testing](../rust-testing/SKILL.md). 네트워크 단절은 turmoil 로 재현한다. 한 스레드에서 여러 host 를 돌리며 `partition` → 편집 → `repair` 뒤 상태가 같은지 본다(seed 고정). loom 은 직접 만든 atomic 구조가 생길 때만 쓴다.

## Anti-Patterns

| 실수 | 문제 | 대신 |
|---|---|---|
| `Arc<Mutex<Doc>>`·`Arc<RwLock<Awareness>>` 공유, `sync` 없이 `spawn_local` 우회 | `transact_mut` 이 worker thread 를 block, 또는 문서가 한 스레드에 묶임 | 문서당 actor 단독 소유 + `features = ["sync"]` (§2) |
| `broadcast` channel fan-out | `Lagged` 때 update 가 조용히 빠짐 | 연결별 bounded mpsc + `try_send` (§2) |
| frame 앞 2바이트로 read-only 판정, viewer 쓰기에 연결 종료 | 이어 붙인 메시지로 우회, viewer 가 접속마다 끊김 | decode 후 메시지마다 버리고 계측 (§4) |
| awareness 를 받은 그대로 적용·중계 | 인증이 없어 남의 커서·이름을 바꿀 수 있음 | 연결에 묶인 client id 항목만, 사용자 필드는 claim 값으로 (§3) |
| epoch 를 기록만 하는 fencing | 옛 소유자의 늦은 쓰기가 들어감 | 쓰기 문장 안에서 fence (§6) |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:
1. **[기능 검증]** — `cargo test -p sync-core` 에서 수렴성 property(replica 3개, 임의 순서·중복, snapshot 재로드), 두 replica state vector 교환, "뒤 메시지가 깨져도 앞 update 는 `DocUpdate` 로 나온다" 회귀 테스트가 통과한다
2. **[안전성]** — viewer frame 에 섞인 Update·SyncStep2 가 문서를 바꾸지 않고 카운터만 올리는 테스트, 남의 client id 항목이 적용·중계되지 않는 테스트, 모르는 태그·깨진 update 가 `RoomError::Client` 인 테스트, 토큰도 WS 헤더도 없는 요청이 `WebSocketUpgrade` 의 405·400·426 이 아니라 401 인 테스트(`tower::ServiceExt::oneshot`)가 있다. 느린 peer 는 두 단계로 확인한다. 용량이 찬 peer 의 `Sender` 만 actor 가 빼는 테스트, 그리고 실제 WS 연결(axum 서버 + tokio-tungstenite 클라이언트)에서 actor 가 peer 를 빼면 클라이언트가 1013 close 를 받고 스트림이 끝나는 테스트다. 채널이 닫혔다는 것(`recv()` 가 None)만 보는 테스트로는 연결이 살아 남는 버그를 잡지 못한다
3. **[동시성·순수성]** — `cargo clippy --all-targets -- -D warnings` 통과. `grep -rnE 'Arc<(Mutex|RwLock)<(Doc|Awareness)' crates/` 0 건, yrs 에 `sync` feature, [rust-engine-architecture](../rust-engine-architecture/SKILL.md) 의 `cargo tree` 스크립트(`set -euo pipefail`, 결과를 변수에 담기, `--target all --all-features`)가 `sync-core` 에서 exit 0
4. **[영속성]** — journal append 와 checkpoint 가 모두 fence 를 거친다. 옛 epoch 로 쓴 INSERT 가 0 rows 인 DB 테스트(`#[sqlx::test]`, `DATABASE_URL` 필요)가 있다
5. **[일관성]** — [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 lint 설정(`unwrap_used` warn, `allow-unwrap-in-tests`)을 따른다. close code 매핑은 `SyncError::close_frame()` 한 곳에만 있고, `From<yrs::sync::Error> for RoomError` 에 wildcard 가 없다

## 참조 스킬

- [rust-engine-architecture](../rust-engine-architecture/SKILL.md) — sans-IO `Room`, `sync-core`/`sync-server` workspace, 순수성 CI · [rust-async-tokio](../rust-async-tokio/SKILL.md) — actor·`select!` 취소 안전성, 종료 처리, metrics exporter · [rust-error-handling](../rust-error-handling/SKILL.md) — `SyncError::close_frame()`, close code 선택 · [rust-testing](../rust-testing/SKILL.md) — proptest·테스트 배치·이름 규칙 · [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) — sqlx 사용, LISTEN/NOTIFY, lease·fencing · `/architecture:distributed-lock`(fencing token 일반론) · `/security:auth-patterns`(단기 토큰과 권한 모델) · `/dx:negative-path-coverage`(단절·느린 peer·부분 실패 테스트 목록)

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. Rust 코드는 `sync-core`·`sync-server` 두 crate 로 나눈 scratch workspace 에서 `cargo clippy --all-targets -- -D warnings`·`cargo test` 로 확인했고, [rust-engine-architecture](../rust-engine-architecture/SKILL.md) 의 `cargo tree` 스크립트가 `sync-core` 에서 exit 0 이고 core 에 optional tokio 를 넣어 shell 이 feature 로 켜면 exit 1 인 것도 확인했다(rustc 1.96, yrs 0.28.1, axum 0.8.9, tokio 1.54.1). SQL 은 로컬 Postgres 가 없어 실행하지 않았다. 다음 재검증은 2027-02.
- [yrs crates.io](https://crates.io/api/v1/crates/yrs) · [y-crdt README](https://raw.githubusercontent.com/y-crdt/y-crdt/main/README.md) · [yrs 0.28.1 docs](https://docs.rs/yrs/0.28.1/yrs/index.html) · [y-crdt releases](https://github.com/y-crdt/y-crdt/releases) · [npm yjs](https://registry.npmjs.org/yjs) · [yrs-warp 0.9.0 deps](https://crates.io/api/v1/crates/yrs-warp/0.9.0/dependencies) · [yrs-axum 0.8.2 deps](https://crates.io/api/v1/crates/yrs-axum/0.8.2/dependencies) · [y-sweet-core 0.9.1 deps](https://crates.io/api/v1/crates/y-sweet-core/0.9.1/dependencies) · [yrs-warp broadcast.rs](https://raw.githubusercontent.com/y-crdt/yrs-warp/master/src/broadcast.rs) · [y-sync](https://crates.io/api/v1/crates/y-sync) — 검증일 2026-11-15 · ✅ verified (yrs 0.28.1 은 2026-11-04, breaking 변경은 0.28.0, npm yjs latest 13.6.33·14.0.0 beta, y-sync 0.4.0 은 2023-11-17 이후 릴리스 없음. `small-client` 문구와 key 를 받는 `observe_update_v1` 은 crate 소스 재확인) / ⚠️ `small-client` 필요 여부는 상호운용 테스트 전이라 미확정 · subagent
- [automerge sync 0.12.0](https://docs.rs/automerge/0.12.0/automerge/sync/index.html) · [Automerge 3.0](https://automerge.org/blog/automerge-3/) · [2026-08](https://automerge.org/blog/2026-august/) · [2026-09](https://automerge.org/blog/2026-september/) · [2026-11](https://automerge.org/blog/2026-november/) · [samod README](https://raw.githubusercontent.com/alexjg/samod/main/README.md) · [samod docs.rs](https://docs.rs/crate/samod/0.16.0) · [LoroDoc 1.17.1](https://docs.rs/loro/1.17.1/loro/struct.LoroDoc.html) · [ExportMode](https://docs.rs/loro/1.17.1/loro/enum.ExportMode.html) · [Loro docs](https://www.loro.dev/llms-full.txt) · [loro protocol](https://raw.githubusercontent.com/loro-dev/protocol/main/README.md) · [diamond-types README](https://raw.githubusercontent.com/josephg/diamond-types/master/README.md) · [diamond-types crates.io](https://crates.io/api/v1/crates/diamond-types) · [Eg-walker](https://arxiv.org/abs/2409.14252) · [dmonad crdt-benchmarks](https://raw.githubusercontent.com/dmonad/crdt-benchmarks/main/README.md) · [Figma multiplayer](https://www.figma.com/blog/how-figmas-multiplayer-technology-works/) · [Rust in production at Figma](https://www.figma.com/blog/rust-in-production-at-figma/) · [Making multiplayer more reliable](https://www.figma.com/blog/making-multiplayer-more-reliable/) · [Notion CRDT](https://www.notion.com/blog/how-notion-handles-concurrent-editing-with-crdts) · [Notion offline](https://www.notion.com/blog/how-we-made-notion-available-offline) · [Cloudflare Durable Objects](https://developers.cloudflare.com/durable-objects/what-are-durable-objects/) — 검증일 2026-11-15 · ✅ verified (samod 는 상충 기록, 3.0 의 "over 10x" 는 블로그 재확인, diamond-types 1.0.0 은 2022-08-25·plain text 만, dmonad 는 ywasm 0.9.3 등 JS/WASM 측정) / ⚠️ automerge 의 Rust native 메모리 수치 없음, samod 성숙도는 채택 시 재조사 · subagent
- [yrs Protocol 0.28.1](https://docs.rs/yrs/0.28.1/yrs/sync/protocol/trait.Protocol.html) · [protocol module](https://docs.rs/yrs/0.28.1/yrs/sync/protocol/index.html) · [Clock 0.28.1](https://docs.rs/yrs/0.28.1/yrs/sync/time/trait.Clock.html) · [protocol.rs 소스](https://docs.rs/crate/yrs/0.28.1/source/src/sync/protocol.rs) · [awareness.rs v0.28.1](https://raw.githubusercontent.com/y-crdt/y-crdt/v0.28.1/yrs/src/sync/awareness.rs) · [Awareness 0.28.1](https://docs.rs/yrs/0.28.1/yrs/sync/awareness/struct.Awareness.html) · [yrs Cargo.toml v0.28.1](https://raw.githubusercontent.com/y-crdt/y-crdt/v0.28.1/yrs/Cargo.toml) · [Transact 0.28.1](https://docs.rs/yrs/0.28.1/yrs/trait.Transact.html) · [async-lock RwLock 3.5.0](https://docs.rs/async-lock/3.5.0/async_lock/struct.RwLock.html) · [Options](https://docs.rs/yrs/0.28.1/yrs/doc/struct.Options.html) · [doc.rs 소스](https://docs.rs/crate/yrs/0.28.1/source/src/doc.rs) · [merge_updates_v1](https://docs.rs/yrs/0.28.1/yrs/fn.merge_updates_v1.html) · [Yjs document updates](https://docs.yjs.dev/api/document-updates) — 검증일 2026-11-15 · ✅ verified (기록의 ❌ 정정값 적용: `&mut Awareness` + `Result`. crate 소스로 확인: `handle()` 이 첫 에러에서 reply 를 버림, overridable handler, `sync::Error` variant 와 발생 지점, awareness `apply_update` 에 Err 경로 없음, `remove_state` 가 항목을 남김, 클로저 `Clock` impl, `get_or_insert_text` 의 rustdoc panic 문구와 `write_blocking` 구현, `Utf16` 직렬화 주석, `Clock` blanket impl 의 `Send + Sync` bound, `transact` 는 `read_blocking`·`transact_mut` 은 `write_blocking`, async-lock 의 "write-preferring". `sync` 없을 때 E0277, 중첩 트랜잭션 lock(쓰기 중 쓰기·읽기 중 쓰기 거절, 읽기 중 읽기 허용, 쓰기 대기 중 새 읽기 거절)은 로컬 컴파일·테스트) · subagent
- [y-protocols PROTOCOL.md 2026-05-05 개정 커밋](https://raw.githubusercontent.com/yjs/y-protocols/73b2ff75486c9879843718dc6c7fc52d63aea4fe/PROTOCOL.md) · [y-protocols PROTOCOL.md v1.0.7 태그](https://raw.githubusercontent.com/yjs/y-protocols/v1.0.7/PROTOCOL.md) · [@y/websocket-server 0.1.5 utils.js](https://unpkg.com/@y/websocket-server@0.1.5/src/utils.js) · [y-websocket 3.1.0 client](https://unpkg.com/y-websocket@3.1.0/src/y-websocket.js) · [y-protocols 1.0.7 awareness.js](https://unpkg.com/y-protocols@1.0.7/awareness.js) · [axum extractor 순서 0.8.9](https://docs.rs/axum/0.8.9/axum/extract/index.html#the-order-of-extractors) · [Yjs Transaction.js v13.6.33](https://raw.githubusercontent.com/yjs/yjs/v13.6.33/src/utils/Transaction.js) · [futures-util split.rs 0.3.34](https://docs.rs/crate/futures-util/0.3.34/source/src/stream/stream/split.rs) · [axum ws.rs 0.8.9 소스](https://docs.rs/crate/axum/0.8.9/source/src/extract/ws.rs) · [tokio-tungstenite 0.29.0](https://docs.rs/tokio-tungstenite/0.29.0/tokio_tungstenite/) · [MDN WebSocket()](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket/WebSocket) · [RFC 6455](https://www.rfc-editor.org/rfc/rfc6455.txt) · [axum WebSocketUpgrade 0.8.9](https://docs.rs/axum/0.8.9/axum/extract/ws/struct.WebSocketUpgrade.html) · [Spring HandshakeInterceptor](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/socket/server/HandshakeInterceptor.html) · [tokio broadcast](https://docs.rs/tokio/1.54.1/tokio/sync/broadcast/index.html) · [tokio mpsc](https://docs.rs/tokio/1.54.1/tokio/sync/mpsc/index.html) · [tokio select!](https://docs.rs/tokio/1.54.1/tokio/macro.select.html) · [Alice Ryhl — Actors with Tokio](https://ryhl.io/blog/actors-with-tokio/) · [DashMap 6.2.1](https://docs.rs/dashmap/6.2.1/dashmap/struct.DashMap.html) · [turmoil Sim 0.7.2](https://docs.rs/turmoil/0.7.2/turmoil/struct.Sim.html) · [loom 0.7.3](https://docs.rs/loom/0.7.3/loom/index.html) · [proptest](https://crates.io/api/v1/crates/proptest) — 검증일 2026-11-15 · ✅ verified (JS 쪽은 Yjs 13.x 용 릴리스 파일로 고정했다. master 는 Yjs v14 용 pre-release 다. PROTOCOL.md 는 개정 커밋으로 고정했고 "SHOULD NOT initiate"·15초 재전송·상위 계층 신원 강제 문구는 이 개정판에만 있다. 사양·구현 불일치, awareness 의 "MUST only modify its own entry"·"not authenticated", y-websocket 클라이언트의 자기 항목 전송·origin 을 보지 않는 재전송(원격 적용도 `update` 이벤트를 낸다)·query 에 전체 상태 응답, 서버의 연결별 id 정리, 생성자 인자, §10.2 Origin·403, DashMap "May deadlock if called when holding any sort of reference into the map", Yjs 가 id 충돌 때 `doc.clientID` 를 다시 뽑고 내용이 있을 때만 `update` 를 내는 것, awareness 가 생성 때 `doc.clientID` 를 복사하는 것, y-websocket-server 가 Doc `update` 이벤트에서 중계하는 것, `split` 두 반쪽이 `BiLock`(Arc)으로 socket 하나를 공유하는 것, axum `WebSocket::recv` 가 `self.next().await` 인 것, extractor 가 인자 순서대로 돌고 `WebSocketUpgrade` 거절이 405·400·426 이며 101 응답을 돌려줄 때만 upgrade 되는 것(axum 소스), bounded 채널 순환은 deadlock 이고 `try_send`·oneshot 은 순환에 끼지 않는다는 것(Alice Ryhl). extractor 순서에 따른 401, 느린 peer 제거, actor 종료, 빠진 peer 의 실제 WS 연결이 1013 으로 닫히는 것과 split 식으로 바꾸면 연결이 남는 것(mutation)은 로컬 테스트) · subagent
- [PostgreSQL 18 limits](https://www.postgresql.org/docs/18/limits.html) · [NOTIFY](https://www.postgresql.org/docs/18/sql-notify.html) · [PostgreSQL 18 transaction isolation](https://www.postgresql.org/docs/18/transaction-iso.html) · [WITH 의 data-modifying 문](https://www.postgresql.org/docs/18/queries-with.html) · [INSERT ON CONFLICT](https://www.postgresql.org/docs/18/sql-insert.html) — 검증일 2026-11-15 · ✅ verified (UPDATE 의 WHERE 재평가, CTE 안 UPDATE, `DO UPDATE ... WHERE` 가 거짓인 행은 `RETURNING` 에 없음) / ⚠️ 소유 획득·fence SQL 자체는 로컬 Postgres 가 없어 미실행 · subagent
