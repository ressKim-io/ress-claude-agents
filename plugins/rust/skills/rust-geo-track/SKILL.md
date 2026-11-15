---
name: rust-geo-track
description: "Rust GPS 트랙 판정 — geo crate 거리 API·미터 평면 투영, 방향 게이트·순서 체크포인트·corridor 커버리지 구간 판정, 순간이동·과속·시간 역행 탐지, 수치 안정성, proptest 성질. Use when Rust 로 러닝·라이딩 기록이 코스 구간을 지났는지 판정하거나 이상 기록을 걸러낼 때."
---

# Rust GPS Track — 구간 통과 판정과 이상 기록 탐지

GPS 기록이 코스 구간을 지났는지 판정하고 부정 기록을 걸러내는 IO 없는 core 코드의 패턴이다. 임계값(속도 상한, corridor 폭, 일치율)은 종목과 제품이 정할 값이라 예시 숫자는 테스트용이다. `judge()` 진입점과 core/shell 분리는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md), 큐 처리는 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) 에 있다.

## Quick Reference (결정 트리)

```
거리를 어떻게 재나? (geo 0.33 metric space API)
├─ 위경도 두 점, 판정 안의 비교 ─────────────> Haversine.distance(a, b)
├─ 사용자에게 보여 줄 거리·기록 ─────────────> Geodesic.distance(a, b)
├─ 점-선 거리, 교차, 최근접 점, R-tree ───────> LocalFrame 으로 미터 평면 투영 → Euclidean
└─ p.haversine_distance(&q) 같은 trait 메서드 ─> deprecated. CI -D warnings, 로컬은 [lints.rust]

구간을 지났다는 것을 무엇으로 판정하나?
├─ 출발선·도착선 ──────────────────> 방향 게이트 (orientation 부호가 바뀌는 선분)
├─ 반환점·랩·왕복 ─────────────────> 순서 있는 게이트 (직전 교차 위치보다 뒤에서만 찾는다)
├─ 코스를 따라 달렸나 ─────────────> corridor 커버리지 (effort 구간만, 코스 샘플 기준 비율)
└─ 모양 유사도 (Fréchet) ──────────> 보조 신호만. GPS spike 한 점에 크게 흔들린다

이상 기록은 어디서 거르나? → 원본 점에 먼저 (smoothing 전)
├─ 1 step 에 불가능한 점프·가감속 ─> Teleport / Acceleration (상한 + GPS 여유)
├─ 오래 계속 빠름 (차량 탑승) ─────> Overspeed  (빠른 step 이 sustained 이상 이어짐)
├─ 시간 역행·같은 timestamp ───────> TimeReversed / DuplicateTimestamp (정렬로 숨기지 않는다)
└─ 기록 공백 ──────────────────────> Gap (공백에 걸친 구간은 판정 실패로). mock 위치는 기기 신호로만
```

## 판정 파이프라인 — 부정 탐지는 원본에 먼저

| 순서 | 단계 | 좌표 | 결과 (모두 `Judgement` 값 — Err 아님) |
|---|---|---|---|
| 1 | 입력 검증 `validate_input` (점 수, 시각 존재·범위, `LonLat::parse`) | 원본 위경도 | 실패 → `Rejected` |
| 2 | 부정 탐지 `anti_cheat::run_all` | 원본 위경도 + Haversine | blocking Finding → `Flagged` |
| 3 | smoothing → `LocalFrame::project` | 미터 평면 `Local` | — |
| 4 | 게이트 → 체크포인트 → effort 구간만 잘라 (솎는다면 여기서) corridor | `Local` | `Passed` / `NotPassed` |

- smoothing 이나 중복 제거를 먼저 돌리면 순간이동·중복 timestamp 증거가 사라져서 2 가 3 보다 앞이다. 단계마다 private 모듈 하나, `judge()` 는 순서대로 부르기만 하는 Composed Method 다. 기록은 1초 간격으로 받는다 (Strava 권장. 이 skill 에서는 공백 탐지에도 필요하다). Newson & Krumm(2009) 은 샘플 간격을 30초로 늘려도 map matching 정확도가 거의 떨어지지 않았다고 보고하지만 이건 경로 **모양** 이야기다. 솎기는 잘라 낸 effort 의 corridor 입력에만 하고, 게이트 통과 위치·시각과 `effort_slice` 의 index 는 솎지 않은 점에서 구한다. 솎은 점으로는 통과 시각이 샘플 간격만큼 틀어질 수 있다. **입력 경계 — GPX·FIT 파싱은 ingest crate 에서.** core 는 파싱 crate 에 의존하지 않는다. `<name>-ingest` crate 가 파일을 원본 숫자로 바꾸고, core 의 `validate_input` 이 `LonLat::parse` 로 한 번 검사한다. **좌표 순서**가 라이브러리마다 다르다: geo `Point` 는 (x = lon, y = lat), geographiclib-rs 는 (lat, lon). 앱 JSON 은 `lon`·`lat` 필드 이름으로 고정한다. **FIT** (`fitparser`, 쓰기 미지원): `position_lat`/`position_long` 이 semicircle(i32) 그대로 나온다. `f64::from(v) * (180.0 / 2_147_483_648.0)` 로 바꾼다 (2^31 을 리터럴로 — `powi` 는 std 가 정밀도를 명시하지 않는다). **GPX** (`gpx` crate, 마지막 릴리스가 오래됐다 — 날짜는 Sources): Waypoint 의 time·hdop 등이 `Option` 이다. time 이 없으면 명시적으로 `Rejected`. thiserror 1.x 에 의존해, thiserror 2 를 쓰는 workspace 면 트리에 1과 2가 함께 들어간다.

## 거리 — geo metric space API

```toml
[dependencies]
geo = "0.33"
rstar = "0.12" # geo 0.33 이 ^0.12 에 의존. 0.14 면 두 벌이 들어오고 geo 타입을 RTree 에 못 넣는다
```

```rust
use geo::{Distance, Geodesic, Haversine, Point};
let (a, b) = (Point::new(126.9780, 37.5665), Point::new(127.0276, 37.4979)); // x = lon, y = lat
// ❌ BAD: 0.29 에서 deprecated — CI 의 -D warnings 나 deprecated = "deny" 면 컴파일 실패
// let d = a.haversine_distance(&b);
// ✅ GOOD: metric space 값에 distance 를 부른다
let quick = Haversine.distance(a, b); // 구면, 평균 반경 6371.0088 km
let precise = Geodesic.distance(a, b); // WGS84 타원체 (Karney)
```

| metric | 지원 | 언제 |
|---|---|---|
| `Haversine` | Point → Point (`&line` 을 넣으면 E0308, 로컬 실측). `distance_within(a, b, r)` 은 거리 ≤ r 이면 true, `length(&ls)` | 판정 안 비교. 짧은 거리에서도 수치가 안정적이다. 위경도끼리의 거리 비교는 판정 안에서 Haversine 하나로 통일한다 (평면 연산은 투영 후 Euclidean) |
| `Geodesic` | Point → Point, f64 전용 | 표시 거리. 구면 모델 오차(보통 0.3% 이하, 최대 0.55%)가 없다. 위 두 점(8.8 km)에서 차이 0.08% (로컬 측정) |
| `Euclidean` | Point·Line·LineString 등 (비-Point 는 참조로 `Euclidean.distance(&line, &point)`) | **미터로 투영한 뒤에만** |

- deprecated 를 로컬 빌드에서도 에러로 만들려면 Cargo.toml `[lints.rust] deprecated = "deny"` (workspace 면 `[workspace.lints.rust]` + 멤버 `[lints] workspace = true`). 코드에 `#![deny(..)]` 를 넣지 않는다. 대상: `HaversineDistance`, `EuclideanDistance`, `ls.frechet_distance(&o)`, `haversine_length()`, `LineInterpolatePoint`(→ `point_at_ratio_from_start(&Euclidean, r)`), `RhumbLength`. `DensifyHaversine` 의 안내문 `Haversine.densify(&line)` 은 인자가 빠져 그대로는 컴파일되지 않는다. geo 다음 릴리스(CHANGES Unreleased)는 rstar 0.14·MSRV 1.90·Simplify 연관 타입 변경을 예고한다. geo 를 올리는 PR 은 golden diff 로 확인한다. `Line::haversine_closest_point` 는 현재 릴리스(0.33)에 고위도 끝점 버그(#1325, main 에서만 수정)가 있고, `CrossTrackDistance` 는 무한 great circle 기준이라 선분 끝을 clamp 하지 않는다 → 투영 후 점-선분 거리를 쓴다.

## 평면 투영 — LonLat·Local newtype

LineLocatePoint, line_intersection, Buffer, Simplify, rstar 는 평면 계산이라 위경도를 넣으면 "도" 단위가 된다. 위도 37° 에서 경도 1° 는 약 88.8 km, 위도 1° 는 약 111.2 km(구면 모델 기준, WGS84 Geodesic 으로는 약 89.0 km·111.0 km)라 방향마다 약 1.25배 왜곡된다.

```rust
use geo::{Coord, Point};
/// 위경도(도, x = lon). 필드가 private 이라 `parse` 를 거친 값만 있다
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LonLat(Point<f64>);
/// 미터. 코스 기준점이 원점. 평면 연산 함수는 이 타입만 받는다
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Local(pub Coord<f64>);

impl LonLat {
    pub fn parse(lon: f64, lat: f64) -> Result<Self, InputRejection> {
        // NaN 은 어떤 비교도 false, inf 는 범위 밖이라 이 검사 하나에 함께 걸린다
        let in_range = (-180.0..=180.0).contains(&lon) && (-90.0..=90.0).contains(&lat);
        if !in_range {
            return Err(InputRejection::InvalidCoordinate);
        }
        Ok(Self(Point::new(lon, lat)))
    }
    pub fn point(self) -> Point<f64> {
        self.0
    }
}
#[derive(Debug, Clone, Copy)]
pub struct LocalFrame {
    origin: Point<f64>,
    m_per_deg_lon: f64,
}
impl LocalFrame {
    // geo Haversine 과 같은 평균 반경 → 짧은 거리에서 두 값이 맞는다
    const M_PER_DEG_LAT: f64 = 6_371_008.8 * std::f64::consts::PI / 180.0;
    pub fn around(origin: LonLat) -> Self {
        let m_per_deg_lon = Self::M_PER_DEG_LAT * origin.0.y().to_radians().cos();
        Self {
            origin: origin.0,
            m_per_deg_lon,
        }
    }
    pub fn project(&self, p: LonLat) -> Local {
        Local(Coord {
            x: (p.0.x() - self.origin.x()) * self.m_per_deg_lon,
            y: (p.0.y() - self.origin.y()) * Self::M_PER_DEG_LAT,
        })
    }
}
```

- `LonLat::parse` 는 core 첫 단계 `validate_input` 이 한 번 부르고, 실패는 `Rejected` 의 사유 `InputRejection` 이 된다. `RobustKernel::orient2d` 는 NaN 을 Collinear 로 돌려줘 게이트가 조용히 건너뛰므로(소스 확인), `project` 와 부정 탐지가 검증된 좌표만 보게 하는 것이 이 타입의 목적이다. `Local` 은 불변식 없는 단위 태그라 필드를 연다. 모듈 밖에서 `LonLat(..)` 로 만들면 E0603(private 생성자), 도 단위 값을 평면 함수에 넣으면 E0308 이다 (로컬 실측). 단위 newtype·uom 선택은 [rust-engine-architecture](../rust-engine-architecture/SKILL.md), newtype 기본은 [rust-idioms](../rust-idioms/SKILL.md). 기준점은 코스마다 하나로 정하고 트랙과 코스를 같은 frame 으로 투영한다. 위도 37.5° 기준점에서 4.4~6.3 km 떨어진 점의 투영 거리와 Haversine 차이는 0.83 m 이하(1.3e-4)였다 (로컬 측정). 코스가 길면 구간마다 frame 을 나누고 이 오차를 테스트로 고정한다. 날짜변경선(±180°)을 넘는 코스는 다루지 않는다.

## 방향 게이트 — orientation 부호가 바뀌는 선분

연속한 두 점이 게이트 선의 반대쪽에 있으면 통과다. **방향**은 "Clockwise 쪽 → CounterClockwise 쪽" 하나로 정하고, 선 위의 점(Collinear)은 직전 쪽을 이어받는다. 통과 위치는 `Crossing { segment, t }` 로 돌려줘 같은 선분 안의 순서까지 비교한다 (derive 한 `PartialOrd` 는 필드 순서로 비교).

```rust
use geo::kernels::RobustKernel;
use geo::line_intersection::{LineIntersection, line_intersection};
use geo::{Kernel, Line, Orientation}; // Kernel 을 import 하지 않으면 orient2d 가 E0599
/// 진행 방향에서 볼 때 왼쪽 끝 → 오른쪽 끝. 통과 = Clockwise 쪽에서 CounterClockwise 쪽으로
#[derive(Debug, Clone, Copy)]
pub struct DirectedGate(Line<f64>);
#[derive(Debug, Clone, Copy, PartialEq, PartialOrd)]
pub struct Crossing {
    pub segment: usize, // 트랙의 점 segment → segment + 1 선분
    pub t: f64,         // 그 선분에서 교차점까지의 비율
}
impl DirectedGate {
    pub fn new(left: Local, right: Local) -> Self {
        Self(Line::new(left.0, right.0))
    }
    /// `after` 보다 뒤의 첫 통과. 같은 선분이면 교차점이 더 뒤여야 한다 (한 번을 두 번 세지 않게)
    pub fn first_crossing(&self, path: &[Local], after: Option<Crossing>) -> Option<Crossing> {
        let mut last_side: Option<(usize, Orientation)> = None;
        for (i, p) in path.iter().enumerate().skip(after.map_or(0, |a| a.segment)) {
            let side = RobustKernel::orient2d(self.0.start, self.0.end, p.0);
            if side == Orientation::Collinear {
                continue; // 선 위의 점은 직전 쪽을 이어받는다 (hysteresis)
            }
            if let Some((from, Orientation::Clockwise)) = last_side
                && side == Orientation::CounterClockwise
                && let Some(crossing) = (from..i).find_map(|k| self.hit(path, k))
                && after.is_none_or(|a| crossing > a)
            {
                return Some(crossing);
            }
            last_side = Some((i, side));
        }
        None
    }
    fn hit(&self, path: &[Local], segment: usize) -> Option<Crossing> {
        let seg = Line::new(path[segment].0, path[segment + 1].0);
        match line_intersection(seg, self.0)? {
            LineIntersection::SinglePoint { intersection, .. } => {
                let (d, v) = (seg.delta(), intersection - seg.start);
                let t = (v.x * d.x + v.y * d.y) / (d.x * d.x + d.y * d.y);
                Some(Crossing { segment, t })
            }
            LineIntersection::Collinear { .. } => None, // 선을 따라 겹친 구간은 통과가 아니다
        }
    }
}
```

- ❌ BAD: `before == Clockwise && after != Clockwise` — `after` 가 Collinear(선에 닿기만 함)여도 true 라 통과로 센다. 테스트 다섯 경우 (로컬 실행): 게이트를 진행 방향으로 통과(선의 Clockwise 쪽 → CounterClockwise 쪽) `Some` · 닿았다 같은 쪽으로 복귀 `None`(BAD 규칙은 통과로 센다) · 반대 방향 `None` · 게이트 끝 바깥 `None` · 선 위 점 경유 통과 `Some`. `if let ... && let ...` 체인은 edition 2024 와 Rust 1.88+ 가 필요하다 (geo 0.33 MSRV 도 1.88). `is_proper` 로 끝점 접촉을 따로 세지 않는다. 끝점 교차는 `false` 지만 float snap 으로 `true` 가 나올 수 있어 이중 카운트·누락이 생긴다. 통과 **시각**을 `t` 로 보간할지 가장 가까운 GPS 점으로 할지는 정책으로 정하고 golden 으로 고정한다. Strava 는 시작·끝에 가장 가까운 GPS 점을 쓴다고 설명한다.

## 순서 있는 체크포인트 — 직전 교차 위치보다 뒤에서만

```rust
/// 게이트를 순서대로 찾는다. 다음 게이트는 직전 교차 위치보다 뒤에서만. 하나라도 못 지나면 None
pub fn pass_in_order(path: &[Local], gates: &[DirectedGate]) -> Option<Vec<Crossing>> {
    let mut passes: Vec<Crossing> = Vec::with_capacity(gates.len());
    for gate in gates {
        let after = passes.last().copied();
        passes.push(gate.first_crossing(path, after)?);
    }
    Some(passes)
}
```

- 출발선을 반대 방향 게이트로 한 번 더 두면 왕복 도착선, 같은 게이트를 N 번 두면 N 랩이다. 같은 게이트가 반복돼도 한 번의 통과를 두 번 세지 않는다. 같은 선분·같은 게이트면 교차 계산이 같은 `t` 를 내서 `crossing > a` 가 거짓이고, 한 선분이 게이트 둘을 넘는 성긴 기록은 선분 안 순서가 맞을 때만 통과다. 테스트 (로컬 실행): 왕복 `[0, 1, 3]` · 반환점 생략 `None` · 한 선분이 g1→g2 순으로 넘음 통과 · 역순 `None` · 한 번 통과에 `[g, g]` `None`(선 위 점 경유 포함) · 두 바퀴에 `[g, g]` 통과. 진행률(`LineLocatePoint`)로 순서를 볼 때: 이 함수는 코스 **전체**에서 최근접 선분을 고르고 동률이면 앞 선분을 택한다(strict `<`). 그래서 왕복 코스에서 진행률이 뒤로 가거나 점프한다. 직전 위치 `±window` 의 하위 LineString 에만 호출하고 `progress = progress.max(next)` 로 고정한다. 좌표가 유한하지 않으면 `None` 이다.

## corridor 커버리지 — effort 구간, 코스 샘플 기준 비율

```rust
use geo::{CoordsIter, Densify, Euclidean, LineString};
use rstar::{RTree, primitives::Line as Segment};
#[derive(Debug, Clone, Copy)]
pub struct CorridorParams {
    spacing_m: f64,
    half_width_m: f64,
    min_permille: u16,
}
impl CorridorParams {
    const MIN_SPACING_M: f64 = 0.5; // 0 이하·NaN 은 Densify 가 panic, 너무 작으면 점이 폭증한다
    pub fn new(spacing_m: f64, half_width_m: f64, min_permille: u16) -> Result<Self, ParamsError> {
        let spacing_ok = spacing_m.is_finite() && spacing_m >= Self::MIN_SPACING_M;
        let width_ok = half_width_m.is_finite() && half_width_m > 0.0;
        if !(spacing_ok && width_ok && min_permille <= 1000) {
            return Err(ParamsError::Corridor);
        }
        Ok(Self {
            spacing_m,
            half_width_m,
            min_permille,
        })
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Coverage {
    pub covered: usize,
    pub total: usize,
}
impl Coverage {
    /// 정수로 비교해 float 경계에서 판정이 흔들리지 않게 한다
    pub fn meets(&self, p: &CorridorParams) -> bool {
        self.total > 0 && self.covered * 1000 >= usize::from(p.min_permille) * self.total
    }
}
pub fn effort_slice(path: &[Local], start: Crossing, finish: Crossing) -> Option<&[Local]> {
    path.get(start.segment..=finish.segment + 1)
}
/// 트랙 점이 아니라 코스 샘플 기준 비율. 절반만 달리거나 지름길로 가면 낮게 나온다
pub fn corridor_coverage(course: &[Local], effort: &[Local], p: &CorridorParams) -> Coverage {
    let to_segment = |w: &[Local]| Segment::new([w[0].0.x, w[0].0.y], [w[1].0.x, w[1].0.y]);
    let tree = RTree::bulk_load(effort.windows(2).map(to_segment).collect());
    let course: LineString<f64> = course.iter().map(|l| l.0).collect();
    let samples = Euclidean.densify(&course, p.spacing_m);
    let max_sq = p.half_width_m * p.half_width_m; // rstar 는 반지름의 제곱을 받는다
    let near = |q: [f64; 2]| tree.locate_within_distance(q, max_sq).next().is_some();
    let covered = samples.coords_iter().filter(|c| near([c.x, c.y])).count();
    let total = samples.coords_count();
    Coverage { covered, total }
}
```

- ❌ BAD: `inside as f64 / track.len() as f64` (트랙 점 중 corridor 안 비율) — 1 km 코스를 절반만 달린 트랙이 1.0, 위 함수로는 `Coverage { covered: 52, total: 101 }` 다 (로컬 실행). 정지 중 쌓인 점도 비율을 부풀린다. 그리고 **트랙 전체가 아니라 effort 하나**(같은 `path` 에서 `pass_in_order` 가 돌려준 출발·도착 통과 쌍)를 `effort_slice` 로 잘라 잰다. 사각 루프 두 바퀴 중 둘째 랩만 지름길이면 트랙 전체는 `41/41`, 둘째 랩은 `10/41` 이다 (로컬 실행). 앞 랩이나 워밍업이 지름길을 가린다. `CorridorParams` 는 `new` 로만 만든다 (모듈 밖 struct literal 은 E0451, 로컬 실측). `Densify` 는 spacing 이 0 이하·NaN 이면 assert 로, 구간 수가 `u64` 로 안 바뀌면 `expect` 로 panic 하므로 Params 가 DB·설정에서 오면 잘못된 값 하나가 모든 job 을 panic 시킨다. 일치율 하한 `min_permille` 도 1000 이하만 받는다 — `covered ≤ total` 이라 1000 을 넘으면 모든 기록이 조용히 `NotPassed` 가 된다. `ParamsError` 는 판정(`Judgement`)이 아니라 설정 오류라 Params 를 읽는 shell 이 분류한다 ([rust-error-handling](../rust-error-handling/SKILL.md)). 트랙은 점이 아니라 **선분**으로 인덱싱해 성긴 기록도 메운다. corridor 는 방향·순서를 보지 않아 역주행도 덮이니 게이트와 함께 쓴다.

> ⚠️ **특허 — 법무 검토 대상.** Strava 특허 US9116922B2(상태 Active, 예상 만료 2031-03-31)는 타일·R-Tree 후보 선별, corridor 일치율, 시작·종료선 통과(연속한 두 점이 선의 반대쪽)를 서술한다. 이 skill 은 법률 판단을 하지 않는다. 같은 조합이나 가상 시작선·extrapolation 판정을 구현하기 전에 법무 검토를 받는다.

## 부정 기록 탐지 — 원본 점에 규칙을 건다

규칙마다 함수 하나, `run_all` 은 순서대로 부르기만 한다. 출력 순서가 규칙 순서로 고정돼 결정적이다. 입력 `RawPoint { t_ms: i64, at: LonLat }` 는 검증만 거친 원본 점이고, Finding 은 원본 점 index 만 담는다 (거리·공백 길이는 원본에서 다시 잰다). 아래에서 뺀 규칙도 같은 모양이다: `time_order`(dt < 0 → `TimeReversed`, dt == 0 → `DuplicateTimestamp`), `gaps`(dt > `max_gap_ms` → `Gap`), `teleports`(dt > 0 이고 `distance_m` > `max_speed_mps`·dt + `gps_slack_m` → `Teleport`), `accelerations`(dt > 0 인 연속 두 step 의 속도 차 |v₂ − v₁| 가 `max_accel_mps2`·(dt₁ + dt₂)/2 + `gps_slack_m`·(1/dt₁ + 1/dt₂) 를 넘으면 → 두 step 이 만나는 점의 `Acceleration`).

```rust
use geo::{Distance, Haversine};
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Finding {
    TimeReversed { index: usize },
    DuplicateTimestamp { index: usize },
    Gap { index: usize },
    Teleport { index: usize },
    Acceleration { index: usize },
    Overspeed { from: usize, to: usize },
}

pub fn run_all(points: &[RawPoint], lim: &SportLimits) -> Vec<Finding> {
    let steps = steps(points);
    let mut findings = time_order(&steps);
    findings.extend(gaps(&steps, lim));
    findings.extend(teleports(&steps, lim));
    findings.extend(accelerations(&steps, lim));
    findings.extend(overspeed(&steps, lim));
    findings
}
struct Step {
    index: usize, // 도착 점
    dt_ms: i64,
    distance_m: f64,
}
impl Step {
    // d/dt 대신 거리끼리 비교해 dt 로 나누지 않는다. dt ≤ 0 step 은 time_order 가 이미 남겼다
    fn is_fast(&self, lim: &SportLimits) -> bool {
        self.dt_ms > 0 && self.distance_m > lim.max_speed_mps * self.dt_ms as f64 / 1000.0
    }
}
fn steps(points: &[RawPoint]) -> Vec<Step> {
    let step = |(i, w): (usize, &[RawPoint])| Step {
        index: i + 1,
        dt_ms: w[1].t_ms.saturating_sub(w[0].t_ms), // 외부 시각이라 넘치면 panic 대신 포화
        distance_m: Haversine.distance(w[0].at.point(), w[1].at.point()),
    };
    points.windows(2).enumerate().map(step).collect()
}
fn overspeed(steps: &[Step], lim: &SportLimits) -> Vec<Finding> {
    let sustained = |run: &&[Step]| run.iter().map(|s| s.dt_ms).sum::<i64>() >= lim.sustained_ms;
    let span = |run: &[Step]| Finding::Overspeed {
        from: run[0].index - 1,
        to: run[run.len() - 1].index,
    };
    steps
        .chunk_by(|a, b| a.is_fast(lim) == b.is_fast(lim)) // 1.77+
        .filter(|run| run[0].is_fast(lim))
        .filter(sustained)
        .map(span)
        .collect()
}
```

| `SportLimits` 필드 | 근거 (검증된 것만) | 정하는 방법 |
|---|---|---|
| `max_speed_mps` (러닝) | Usain Bolt 100 m 세계기록 레이스(2009)의 레이저 실측 최고속도 12.32 m/s (Štuhec 외 2023) | 사람 러닝 상한의 근거로 쓰되, GPS 잡음 여유를 두고 sustained 조건과 함께 쓴다. 다른 종목은 실측 fixture 로 |
| `gps_slack_m` | 개활지 스마트폰 오차 반경 약 4.9 m (gps.gov archive), 차량 데이터 σ ≈ 4.07 m (Newson & Krumm) | 두 점 사이 거리의 여유라 점 오차 반경 ε 의 약 2배로 둔다 (두 끝점 오차의 합, 예: 두 점 accuracy 의 합). ε 는 `k·σ` 나 기기 accuracy 로 잡는다. Android `getAccuracy` 는 68% 신뢰 반경이다 |
| `max_accel_mps2` | 검증된 수치 없음 | 종목별 실측 fixture 로 정한다. 1초 원본에서는 GPS 오차가 지배한다 (점 오차 ε 면 가속도 오차 최대 4ε/dt², 1초·5 m 면 20 m/s². 규칙의 slack 항은 `gps_slack_m` = 2ε 일 때 이 오차를 덮는다) → 여러 step 평균 속도로 재거나 연속 조건을 붙인다 |
| `max_gap_ms` | Strava 는 GPS drift 가 구간 중간에서 "Gap Threshold" 를 건드리면 매칭되지 않는다고 설명한다 (기준이 시간인지 거리인지는 공개 안 됨) | 시간 공백 기준은 이 skill 의 선택이다. 클라이언트에 1초 기록을 요구하고 공백 구간 판정은 실패로 |

- 시간 역행은 정렬로 고치지 않고 Finding 으로 남긴다 (고치면 조작 흔적이 지워진다). 어떤 Finding 이 판정을 막을지(`is_blocking`)는 제품 결정이다. Strava 도 공백·drift 를 부정이 아니라 매칭 실패로 다룬다. 출력이 달라지는 규칙(코드) 변경은 `ENGINE_VERSION` 을 올린다. 임계값은 Params 위치에 따라 다르다 — 코드 상수면 `ENGINE_VERSION` 을 올리고, DB·설정이면 `params_hash` 가 바뀐다 (⚠️ 설계 제안 — 팀 합의). 이 규칙과 결정성(`total_cmp`, 결과 양자화)은 [rust-engine-architecture](../rust-engine-architecture/SKILL.md) §ENGINE_VERSION 과 결과 키. mock 위치는 트랙 모양만으로 알 수 없다. Android `isMock()`(API 31+, 그 아래는 deprecated `isFromMockProvider`), iOS `isSimulatedBySoftware`(15+)·`isProducedByAccessory` 를 클라이언트가 payload 에 넣어 보내고 **신호**로만 쓴다. 규칙으로 못 잡는 차량 이동은 Strava 도 GBDT 모델(feature 57개)로 따로 탐지한다.

## 테스트 — 실측 fixture 와 proptest 성질

- **fixture** (`tests/fixtures/`, insta 로 판정 결과 고정): 정상 통과, 반환점 생략, 역방향, 터널 공백, 차량 탑승 구간, 시간 역행, 중복 timestamp, 출발선 근처 GPS drift, 다회 랩(둘째 랩 지름길 포함). 실제 기록은 좌표를 평행 이동해 개인 위치를 지운다. float 필드는 `rounded_redaction` 으로 반올림한다 ([rust-testing](../rust-testing/SKILL.md)). geographiclib-rs 는 `Haversine`·`LocalFrame` 투영 결과를 측지 거리와 대조하는 oracle 이다 (허용오차는 모델 오차 — 구면 최대 0.55%, 투영은 위처럼 범위별로 잰 값). geo `Geodesic` 은 내부에서 geographiclib-rs 를 쓰므로 그것끼리 비교하면 같은 구현을 두 번 잰다 → GeographicLib 공개 테스트 데이터(GeodTest)와 대조하고, 자체 정확도를 명시하지 않는 부분 포트라 허용오차를 mm 수준으로 둔다. **proptest 성질**: "남→북으로만 움직이는 트랙은 통과하고, 뒤집으면 절대 통과하지 못한다." 좌표 strategy 는 범위를 정한다. `f64::ANY` 는 inf 와 NaN 을 섞어 NaN 실패만 찾으니 NaN 은 `LonLat::parse` 단위 테스트로 따로 본다. `local(x, y)` 는 `Local(Coord { x, y })` 를 만드는 테스트 helper 다.

```rust
proptest! {
    #[test]
    fn should_never_pass_when_track_is_reversed(
        mut pts in prop::collection::vec((-20.0f64..20.0, -49.0f64..49.0), 0..40),
    ) {
        // Given: y 가 줄지 않는(남→북) 트랙은 동서 방향 게이트를 통과한다
        pts.sort_by(|a, b| a.1.total_cmp(&b.1));
        let with_ends = [(0.0, -50.0)].into_iter().chain(pts).chain([(0.0, 50.0)]);
        let forward: Vec<Local> = with_ends.map(|(x, y)| local(x, y)).collect();
        let gate = DirectedGate::new(local(-100.0, 0.0), local(100.0, 0.0));
        prop_assert!(gate.first_crossing(&forward, None).is_some());
        // When: 같은 트랙을 뒤집으면
        let reversed: Vec<Local> = forward.iter().rev().copied().collect();
        // Then: 방향 게이트를 통과하지 못한다
        prop_assert!(gate.first_crossing(&reversed, None).is_none());
    }
}
```

## Anti-Patterns

| 실수 | 문제 | 해결 |
|---|---|---|
| 위경도를 LineLocatePoint·rstar·Buffer 에 그대로 | 도 단위 계산, 방향마다 약 1.25배 왜곡 (위도 37°) | `LocalFrame` 투영 후 `Local` 만 받는 함수 |
| `after != Clockwise` 로 통과 판정 | 선에 닿기만 해도 통과 | `== CounterClockwise` + Collinear hysteresis |
| 다음 게이트를 직전 통과 선분부터 다시 찾기만 함 | 랩·루프에서 한 번 통과를 여러 번 센다 | `(segment, t)` 가 직전보다 뒤일 때만 |
| corridor 를 트랙 점 기준·트랙 전체로 | 절반만 달려도 1.0, 앞 랩이 지름길 랩을 가린다 | 코스 샘플 기준 + `effort_slice` + 게이트 |
| smoothing 뒤에 부정 탐지, 시간 역행을 정렬로 "수정" | 순간이동·조작 흔적 소실, dt=0 이면 inf 속도 | 원본 점에 먼저, Finding 으로 남기고 `dt > 0` guard |
| geo 0.33 + rstar 0.14 혼용 | geo 타입의 RTreeObject 불일치. 0.13 첫 릴리스는 `bulk_load` 회귀(다음 패치에서 수정 — 버전은 Sources), 배포된 0.14 에 `bulk_load_parallel`·`rayon` feature 없음 | rstar `"0.12"` 로 맞추고 Cargo.lock 확인 |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — `cargo test -p <name>-core` 가 통과하고, 게이트에 통과·접촉·역방향·끝 바깥·Collinear 경유 다섯 경우, 체크포인트에 `[g, g]` 한 번 통과 `None`·한 선분 역순 `None`, corridor 에 둘째 랩 지름길 실패와 `CorridorParams::new` 의 0·NaN·inf·하한 미만·`min_permille` > 1000 거부, 부정 탐지에 Teleport·Acceleration·Overspeed·TimeReversed·Duplicate·Gap 과 "GPS 오차 안이면 Finding 없음"·극단 timestamp 경우가 있다
2. **[회귀 고정]** — proptest 성질(역방향 트랙은 방향 게이트 불통과)과 실측 fixture golden 이 있고 `INSTA_UPDATE=no cargo test` 가 통과한다. proptest 가 실패해 `proptest-regressions/` 파일이 생기면 그 파일을 커밋한다
3. **[API·lint]** — `cargo clippy --all-targets -- -D warnings` 가 통과한다 (deprecated geo API 도 여기서 에러. 로컬 빌드까지 막으려면 core Cargo.toml `[lints.rust]` 또는 `[workspace.lints.rust]` 에 `deprecated = "deny"`). `cargo tree -p <name>-core -d` 출력에 rstar 가 없다 (두 버전이면 여기 나오고, `-i rstar` 는 ambiguous 에러를 낸다)
4. **[안전성]** — `LonLat`·`CorridorParams` 는 fallible 생성자로만 만들어지고(필드 private), 평면 연산 함수의 인자에 위경도 `f64`·`Point<f64>` 가 없다 (`Local` 만). corridor 일치율 판정(`Coverage::meets`)은 정수 비교이고, 속도·거리·가속도 같은 float 임계값 비교는 `dt > 0` guard 뒤에서만 한다
5. **[일관성]** — 미통과·부정·입력 거부를 `Err` 가 아니라 `Judgement`(Verdict variant)로 돌려주고 테스트 밖에 `unwrap()` 이 없다. 함수 길이·중첩·파일 분할은 [rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 과 맞는다

## 참조 스킬

- [rust-engine-architecture](../rust-engine-architecture/SKILL.md) — `judge()` 진입점, core/shell 분리, 결정성, `ENGINE_VERSION`·`params_hash`, 단위 newtype · [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) — 판정 job claim·결과 upsert·재시도. 이 core 를 부르는 shell · [rust-error-handling](../rust-error-handling/SKILL.md) — 판정 결과(`Judgement`)와 Err·설정 오류 구분 · [rust-async-tokio](../rust-async-tokio/SKILL.md) — 판정 계산을 rayon·`spawn_blocking` 으로 · [rust-testing](../rust-testing/SKILL.md) — proptest 설정, insta golden, `rounded_redaction` · [rust-idioms](../rust-idioms/SKILL.md) — newtype·parse don't validate, let chains, Composed Method, lint 템플릿 · `/dx:clean-code` — Composed Method·SLAP (`run_all`·`judge` 의 모양) · `/dx:negative-path-coverage` — 공백·역행·NaN 같은 이상 입력 체크리스트

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. 코드 블록은 scratch crate(geo 0.33.1, rstar 0.12.2, proptest 1.12.0)에서 rustc 1.96 으로 `cargo check --all-targets`·`cargo clippy --all-targets -- -D warnings`·`cargo test`·`cargo fmt --check` 를 통과했고, BAD 예시(deprecated — Cargo.toml `[lints.rust]` 와 clippy `-D warnings` 각각, E0308·E0603·E0599·E0451)와 spacing 0 의 Densify panic 은 실패를 확인했다. 다음 재검증은 2027-02. [geo CHANGES](https://raw.githubusercontent.com/georust/geo/main/geo/CHANGES.md) · [geo 0.33.1 의존성](https://crates.io/api/v1/crates/geo/0.33.1/dependencies) · [Distance](https://docs.rs/geo/0.33.1/geo/algorithm/line_measures/trait.Distance.html) · [Euclidean](https://docs.rs/geo/0.33.1/geo/algorithm/line_measures/metric_spaces/struct.Euclidean.html) · [HaversineMeasure](https://docs.rs/geo/0.33.1/geo/algorithm/line_measures/metric_spaces/struct.HaversineMeasure.html) · [HaversineDistance](https://docs.rs/geo/0.33.1/geo/algorithm/haversine_distance/trait.HaversineDistance.html) · [geodesic.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/line_measures/metric_spaces/geodesic.rs) · [Densify](https://docs.rs/geo/0.33.1/geo/algorithm/line_measures/trait.Densify.html) · [densify.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/line_measures/densify.rs) · [LineIntersection](https://docs.rs/geo/0.33.1/geo/algorithm/line_intersection/enum.LineIntersection.html) · [RobustKernel](https://docs.rs/geo/0.33.1/geo/algorithm/kernels/robust/struct.RobustKernel.html) · [robust.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/kernels/robust.rs) · [line_locate_point.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/line_locate_point.rs) · [FrechetDistance](https://docs.rs/geo/0.33.1/geo/algorithm/line_measures/trait.FrechetDistance.html) · [HaversineClosestPoint](https://docs.rs/geo/0.33.1/geo/algorithm/haversine_closest_point/trait.HaversineClosestPoint.html) · [cross_track_distance.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/cross_track_distance.rs) — 검증일 2026-11-15 · ✅ verified (MSRV 1.88, rstar ^0.12·geographiclib-rs ^0.2.3 의존, deprecated 목록, Unreleased breaking, Point→Point 한정은 정정값 반영 + 로컬 컴파일. `GeodesicMeasure` 가 `geographiclib_rs::Geodesic::wgs84` 를 쓰는 것, `max_segment_length > 0` assert·`to_u64().expect`, NaN → Collinear 는 소스 확인) · subagent · [Movable Type — latlong](https://www.movable-type.co.uk/scripts/latlong.html) · [GeographicLib Geodesic](https://geographiclib.sourceforge.io/C++/doc/classGeographicLib_1_1Geodesic.html) · [GeographicLib — Test data for geodesics](https://geographiclib.sourceforge.io/C++/doc/geodesic.html#testgeod) · [geographiclib-rs](https://docs.rs/geographiclib-rs/0.2.7/geographiclib_rs/index.html) · [rstar CHANGELOG](https://raw.githubusercontent.com/georust/rstar/master/rstar/CHANGELOG.md) · [rstar 0.14.0 crate](https://static.crates.io/crates/rstar/rstar-0.14.0.crate) · [rstar 0.12.2 RTree](https://docs.rs/rstar/0.12.2/rstar/struct.RTree.html) · [rstar #256](https://github.com/georust/rstar/issues/256) · [geo-types 0.7.20](https://crates.io/api/v1/crates/geo-types/0.7.20) · [cargo tree](https://doc.rust-lang.org/cargo/commands/cargo-tree.html) — 검증일 2026-11-15 · ✅ verified (구면 오차 0.3%/0.55%, 인자 순서 lat·lon, GeodTest 데이터 공개, rstar 0.13.0 `bulk_load` 회귀 → 0.13.1 backport, `bulk_load_parallel`·`rayon` 은 정정값: 0.14.0 에 없음, 반지름 제곱, geo-types rstar feature 0_8~0_13, `-d` 는 여러 버전 의존성만 표시·`-i` 모호 에러는 cargo 1.96 로컬 실측) · subagent · [US9116922B2](https://patents.google.com/patent/US9116922B2/en) · [Strava — segment matching issues](https://support.strava.com/en-us/articles/15401957-segment-matching-issues) · [Strava — removing cars](https://stories.strava.com/articles/removing-cars-from-leaderboards) · [Android Location](https://developer.android.com/reference/android/location/Location) · [iOS isSimulatedBySoftware](https://developer.apple.com/documentation/corelocation/cllocationsourceinformation/issimulatedbysoftware) · [GPS accuracy (archive, 원 출처 ION.org)](https://archive.gps.gov/systems/gps/performance/accuracy/) · [Newson & Krumm 2009](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/map-matching-ACM-GIS-camera-ready.pdf) · [Štuhec 외 2023 (Europe PMC)](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=PMCID:PMC10669785&format=json&resultType=core) — 검증일 2026-11-15 · ✅ verified (특허 Active·예상 만료 2031-03-31, gps.gov 원 URL 은 404 라 archive 사본, 12.32 m/s 는 Bolt 2009 베를린 9.58 s 레이스를 분석한 초록 기준) / ⚠️ 특허 청구 범위 해석은 법무 영역이라 판단하지 않음 · subagent · [gpx](https://crates.io/api/v1/crates/gpx) · [gpx Waypoint](https://docs.rs/gpx/0.10.0/gpx/struct.Waypoint.html) · [fitparser](https://docs.rs/fitparser/0.12.0/fitparser/index.html) · [fitparser profile](https://docs.rs/crate/fitparser/0.12.0/source/src/profile/decode.rs) · [Garmin forum — semicircle](https://forums.garmin.com/developer/fit-sdk/f/discussion/280125/record-the-latitude-and-longitude-format-of-the-message) · [proptest Config](https://docs.rs/proptest/1.12.0/proptest/test_runner/struct.Config.html) · [proptest failure persistence](https://proptest-rs.github.io/proptest/proptest/failure-persistence.html) · [std slice::chunk_by](https://doc.rust-lang.org/std/primitive.slice.html#method.chunk_by) · [std f64](https://doc.rust-lang.org/std/primitive.f64.html) · [std PartialOrd](https://doc.rust-lang.org/std/cmp/trait.PartialOrd.html) — 검증일 2026-11-15 · ✅ verified (regressions 파일은 실패를 찾았을 때 생성, `chunk_by` 1.77.0 안정화, derive `PartialOrd` 는 필드 선언 순서의 사전식 비교) / ⚠️ semicircle 변환식의 Garmin 공식 문서는 JS 렌더링이라 읽지 못해 포럼 답변과 fitparser 프로필로 대체 · subagent · 로컬 계산(구면 R=6371.0088 km) + Geodesic 대조 (scratch crate 테스트 출력, 2026-11-15): 위도 37° 경도 1° = 88,804 m·위도 1° = 111,195 m(비 1.252), WGS84 Geodesic 89,011 m·110,978 m(비 1.247), 서울 두 점 Haversine 8,792.9 m vs Geodesic 8,785.7 m(0.08%), 위도 37.5° 기준 4.4~6.3 km 투영 오차 ≤ 0.83 m — ✅ 로컬 계산 · subagent · crates.io 최신 버전 (검증일 2026-11-15): geo 0.33.1 (2026-04-20), rstar 0.14.0·0.13.1 (2026-11-01)·0.13.0 (2026-05-24)·0.12.2 (2024-11-05), geographiclib-rs 0.2.7 (2026-02-17), gpx 0.10.0 (2023-12-04), fitparser 0.12.0 (2026-11-03), proptest 1.12.0 (2026-10-10) — ✅ verified · subagent
