---
name: rust-idioms
description: "Rust 관용 패턴 — Composed Method 를 ?·free fn 으로 쓰기, helper 추출 시 borrow 충돌(E0502) 회피, let-else·let chains 로 중첩 줄이기, newtype, 모듈·파일 분할, clippy 길이·중첩 lint. Use when Rust 함수가 길어지거나 중첩이 깊어 쪼갤 방법을 고르거나 모듈 구조를 정할 때."
---

# Rust Idioms — 함수와 모듈을 나누는 Rust 방식

Composed Method·Guard Clause·파일 쪼개기 습관은 Rust 에서도 그대로 통한다. 바뀌는 것은 나누는 수단이다: `Result` + `?`, free fn, borrow 규칙, 모듈 파일 규칙, clippy 설정. 원칙 설명은 `/dx:clean-code`, 상시 규칙은 [rust.md rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 에 있다. 여기서는 Rust 메커니즘만 다룬다.

## Quick Reference (결정 트리)

```
이 로직 블록을 어떻게 나눌까?
├── 실패할 수 있는 단계 (checkDuplicateNickname 류) ─> fn check_x(..) -> Result<_, E>, 호출부는 ?
├── 입력 형식 검증 (checkEmail 류) ──────────────────> 경계의 newtype 생성자 (Email::parse)
├── self 상태가 필요 없다 ─────────────────────────> impl 밖 module-private free fn (receiver 가 분명하면 method)
├── 한 번만 쓰고 실패 없는 1-2줄 ──────────────────> block expression { .. } + WHY 주석
├── 필드를 빌린 채 &mut self helper 가 필요 ───────> 필요한 필드만 받는 fn (E0502 회피)
└── 인자 8개 이상 / bool 인자 여러 개 ─────────────> context struct / enum
중첩을 어떻게 줄일까?
├── Err/None 이면 그대로 위로 ──────────> ?
├── 꺼내지 못하면 return·continue ──────> let-else (1.65+)
├── if let 안에 if / if let ────────────> let chains (edition 2024, 1.88+)
├── match arm 안에 if ──────────────────> match guard
└── 짧은 순수 변환 / 상태 변경·조기 반환 ─> combinator / for
파일이 커졌다
├── 기능 여러 개가 섞였다 ──> foo.rs + foo/ 하위 파일 (책임별 모듈)
├── 한 타입의 impl 이 크다 ──> 하위 파일에 impl 분할, 부모가 부를 method 는 pub(super)
└── 테스트가 길다 ───────────> 공개 API 만 쓰는 테스트는 tests/ 로 (/rust:rust-testing)
```

## Composed Method 를 Rust 로

[rust.md rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 세 규칙(3줄 이상 블록은 이름 있는 함수로, 1-2줄은 WHY 주석, 함수는 20-50줄)은 그대로다. Rust 에서는 네 가지가 달라진다.
1. 실패할 수 있는 단계는 `fn check_x(..) -> Result<_, E>` 로 뽑고 `?` 로 잇는다. `?` 가 `From::from` 으로 에러를 바꾸므로 호출부에 try-catch 가 없다
2. `self` 가 필요 없는 단계는 `impl` 밖 모듈 수준 private fn 으로 둔다 (Microsoft M-REGULAR-FN). pedantic `unused_self` 를 켜면 잡히지만, 기본 설정(`avoid-breaking-exported-api = true`)에서는 crate 밖으로 export 되지 않은 method 만 본다. receiver 가 분명하면 method 다 (C-METHOD). 함수 안 nested `fn` 을 끝에 두면 pedantic `items_after_statements` 에 걸린다
3. 줄 수 기준은 rule 과 같다: **3줄 이상은 이름 있는 fn, 한 번만 쓰고 실패도 없는 1-2줄은 block expression + WHY 주석**. 출처끼리 부딪치는 지점이다 (Book 12.3 "each function is responsible for one task" vs rust-analyzer "Avoid creating single-use helper functions"). rust-analyzer 도 `return`·`?` 를 쓰려면 예외로 둔다. block 안의 `return`·`?` 는 block 이 아니라 바깥 함수를 빠져나가므로, 단계 안에서 `?`·`return` 으로 끝내려면 fn 으로 뽑는다 (labeled block 의 `break 'a`(1.65+)도 있지만 이름 있는 fn 이 읽기 쉽다)
4. 형식 검증(`checkEmail`)은 service 에서 빼서 경계의 newtype 생성자로 옮긴다 (§타입으로 검증·분기 줄이기)

```rust
// ❌ BAD: 검증·중복 확인·저장이 중첩돼 happy path 가 맨 안쪽에 묻힌다
pub fn create_user(repo: &mut UserRepo, req: CreateUserRequest) -> Result<UserId, UserError> {
    if req.email.contains('@') {
        let nickname = req.nickname.trim();
        if (2..=20).contains(&nickname.chars().count()) {
            if repo.exists_nickname(nickname) {
                Err(UserError::DuplicateNickname)
            } else {
                Ok(repo.insert(&req.email, nickname))
            }
        } else {
            Err(UserError::InvalidNickname)
        }
    } else {
        Err(UserError::InvalidEmail)
    }
}
// ✅ GOOD: 같은 추상화 수준의 단계만 남기고 실패는 ? 로 넘긴다. 형식 검증은 newtype 생성자가 맡는다 (§타입으로 검증)
pub fn create_user(repo: &mut UserRepo, req: CreateUserRequest) -> Result<UserId, UserError> {
    let email = Email::parse(&req.email)?;
    let nickname = Nickname::parse(&req.nickname)?;
    check_duplicate_nickname(repo, nickname.as_str())?;
    Ok(repo.insert(&email, &nickname))
}
fn check_duplicate_nickname(repo: &UserRepo, nickname: &str) -> Result<(), UserError> {
    // 동시 가입 경합의 최종 방어선은 DB unique 제약 — 여기는 친절한 에러를 위한 사전 검사
    if repo.exists_nickname(nickname) {
        return Err(UserError::DuplicateNickname);
    }
    Ok(())
}
```

- **clippy 는 BAD 를 잡지 못한다.** 아래 템플릿(`excessive-nesting-threshold = 4`)으로 돌려도 경고가 없다 (로컬 실측). Composed Method 는 리뷰 기준이다. async service 도 모양은 같다: `check_duplicate_nickname(repo, nickname.as_str()).await?`. `UserError` 설계는 [rust-error-handling](../rust-error-handling/SKILL.md)

```rust
let job_label = {
    // 로그 한 줄의 폭을 맞추려고 앞 12자만 남긴다. 사람에게 보이는 문구가 아니라 char 단위로 충분하다
    let short: String = course_title.trim().chars().take(12).collect();
    format!("course:{short}")
};
```

사용자에게 보이는 텍스트는 char 가 아니라 grapheme 단위로 자른다 (이모지·결합 문자). rust-og-image-render 참고.

## helper 추출 시 borrow 충돌 (E0502)

Java 의 `this.addWeight(item.weightG)` 를 그대로 옮기면 E0502 가 난다. `&mut self` 는 **self 전체**를 빌리고, 컴파일러는 함수 경계를 넘어 어느 필드만 쓰는지 보지 않는다.

```rust
// ❌ BAD
impl Cart {
    fn recalc_weight(&mut self) {
        self.total_weight_g = 0;
        for item in &self.items {
            self.add_weight(item.weight_g); // error[E0502]: cannot borrow `*self` as mutable because it is also borrowed as immutable
        }
    }
    fn add_weight(&mut self, weight_g: u64) {
        self.total_weight_g += weight_g;
    }
}
// ✅ GOOD: helper 는 필요한 필드만 받는다. 한 함수 안에서 서로 다른 필드를 빌리는 것(disjoint field borrow)은 허용된다
impl Cart {
    fn recalc_weight(&mut self) {
        self.total_weight_g = 0;
        for item in &self.items {
            add_weight(&mut self.total_weight_g, item.weight_g);
        }
    }
}
fn add_weight(total_weight_g: &mut u64, weight_g: u64) {
    *total_weight_g += weight_g;
}
```

- 다른 해법: 읽기와 쓰기를 단계로 나눈다 (`self.total_weight_g = sum_weights(&self.items);`), 필드가 많으면 `let Self { items, total_weight_g } = self;` 로 분해해 각각 빌린다 (nomicon borrow splitting). 함수 경계를 넘는 필드 단위 borrow(view types)는 2026 project goal 의 **실험**이라 지금 쓸 수 없다
- borrow 에러를 `clone()` 으로 덮지 않는다 (rule NEVER). `&T` 로 빌리기 → move → `Arc::clone` 순으로 검토한다. 출처(rust-unofficial anti-pattern)는 소유권을 배우는 중, 속도·메모리 제약이 없는 프로토타입, borrow 를 맞추기가 너무 복잡해 가독성을 고를 때를 예외로 들지만 rule 은 이 예외를 두지 않는다

## 중첩 줄이기

| 도구 | 쓰는 곳 | 조건 |
|---|---|---|
| `?` | Err/None 을 그대로 위로 | Result 는 `From` 으로 변환 |
| `let PAT = expr else { .. };` | enum variant 꺼내기, `continue`·`break` | 1.65+, else 블록은 반드시 diverge |
| let chains | 중첩 `if let` | **edition 2024 전용** (1.88+). 2021 이면 컴파일 에러 |
| match guard `Pat if cond =>` | arm 안의 `if` | guard 가 false 면 다음 arm 으로 넘어가 의미가 바뀔 수 있다. clippy `collapsible_match` 도 1.97 부터 뒤에 wildcard 아닌 arm 이 있으면 제안하지 않는다 |
| `is_some_and` / `is_none_or` | `map_or(false, f)` / `map_or(true, f)` | 1.70 / 1.82. None 일 때 값이 반대라 서로 바꿔 쓰면 안 된다. clippy `unnecessary_map_or`(style)가 제안한다 (로컬 실측) |

꺼내기만 하는 `let user = match repo.find(id) { Some(user) => user, None => return Err(..) };` 는 pedantic `manual_let_else` 가 잡는다 (로컬 실측). 에러로 바꾸기만 하면 `?` 가 더 짧다: `let user = repo.find(id).ok_or(UserError::NotFound(id))?;`. let-else 는 `?` 로 표현하지 못하는 경우에 쓴다.

```rust
// ✅ GOOD: Paid 가 아니면 다음 주문으로 넘어간다 (? 로는 continue 를 표현할 수 없다)
for order in orders {
    let OrderStatus::Paid { paid_at } = order.status else {
        continue;
    };
    settled.push((order.id, paid_at));
}
```

```rust
// ❌ BAD: edition 2024 에서는 clippy `collapsible_if`(style)가 let chain 으로 합치라고 제안한다 (로컬 실측)
if let Some(coupon) = &order.coupon {
    if coupon.is_active(now) {
        if let Some(discount) = coupon.discount_for(order.subtotal) {
            order.apply(discount);
        }
    }
}
// ✅ GOOD (edition 2024)
if let Some(coupon) = &order.coupon
    && coupon.is_active(now)
    && let Some(discount) = coupon.discount_for(order.subtotal)
{
    order.apply(discount);
}
```

match guard 는 `JobStatus::Failed if attempts >= max_attempts => Action::Dead,` 처럼 arm 에 조건을 붙인다. combinator 와 `for` 는 Google 스타일을 따른다: 길고 복잡한 chain, `for` 헤더 안 chain, `for_each` 를 피한다 (짧은 chain 은 combinator 가 낫다는 단서가 붙는다).

```rust
// ✅ 짧은 순수 변환 → combinator
orders.iter().filter(|o| o.is_paid()).map(|o| o.id).collect()
// ✅ 상태 변경·continue·조기 반환이 섞이면 → for
for order in orders.iter_mut() {
    if order.is_expired(now) {
        order.cancel();
        continue;
    }
    if order.amount > limit {
        return Err(OrderError::OverLimit(order.id));
    }
}
```

## 타입으로 검증·분기 줄이기

검증 결과를 bool 로 버리지 말고 더 구조화된 타입으로 바꾼다 (Parse, don't validate). Spring 의 `@Valid` + validator bean 자리에 **fallible 생성자를 가진 newtype** 이 온다.

```rust
// ✅ GOOD: 필드가 비공개라 parse 를 거치지 않고는 Email 을 만들 수 없다
pub struct Email(String);
impl Email {
    pub fn parse(raw: &str) -> Result<Self, UserError> {
        let trimmed = raw.trim();
        if !trimmed.contains('@') {
            return Err(UserError::InvalidEmail);
        }
        Ok(Self(trimmed.to_owned()))
    }
}
impl TryFrom<CreateUserRequest> for NewUser {
    type Error = UserError;
    fn try_from(req: CreateUserRequest) -> Result<Self, Self::Error> {
        Ok(Self { email: Email::parse(&req.email)?, nickname: Nickname::parse(&req.nickname)? })
    }
}
// Nickname 은 Email 과 같은 모양에 as_str() getter 를 둔다. 필드가 여럿이면 TryFrom 으로 DTO 를 한 번에 바꾸고, insert 는 검증된 NewUser 만 받는다
pub fn create_user(repo: &mut UserRepo, req: CreateUserRequest) -> Result<UserId, UserError> {
    let new_user = NewUser::try_from(req)?;
    // 위 절의 &str 버전을 그대로 쓴다. &Nickname 은 &str 로 자동 변환되지 않는다 (E0308)
    check_duplicate_nickname(repo, new_user.nickname.as_str())?;
    Ok(repo.insert(new_user))
}
```

- service 에는 IO 가 필요한 검사(중복 확인)만 남고, 이후 코드는 `Email` 을 받으므로 다시 검사하지 않는다. 약한 타입에서의 변환은 `TryFrom`·`FromStr`·`parse` 로 하고, 검증을 건너뛰는 infallible `From<String>` 은 두지 않는다 (M-STRONG-TYPES-GUARD — library 지침, 앱에 유추 적용)
- fallible 생성자 이름은 출처마다 다르다 (Microsoft `TryFrom`·`from_x`, Google `try_new`, Comprehensive Rust `new -> Result`). crate 안에서 하나로 통일한다. getter 는 `get_` 없이 `as_str()`·`email()` 로 쓴다 (C-GETTER). 단위 newtype(`Meters`)과 `uom` 선택은 [rust-engine-architecture](../rust-engine-architecture/SKILL.md)
- bool flag 인자도 타입으로 바꾼다: ❌ `send_welcome(&user, true, false)` → ✅ `send_welcome(&email, Channel::Email, Timing::Now)` (2-variant enum, 이름 있는 두 함수, options struct 중 하나). bool 인자 4개부터 pedantic `fn_params_excessive_bools`(기본 3)가 잡는다

## 모듈·파일 분할

```
src/
├── main.rs     조립만 (설정 → 의존성 생성 → 실행). main 은 직접 테스트할 수 없다 (Book 12.3)
├── lib.rs      pub mod user; pub mod order; (main.rs 는 lib 을 외부 crate 처럼 써서 pub 만 보인다, Book 7.3)
├── user.rs     non-leaf: mod 선언과 pub use 만
├── user/       handler.rs · service.rs · repo.rs
├── order.rs    주 타입 Order 와 핵심 impl
└── order/      pricing.rs (impl Order 의 가격 계산 부분)
```

- `foo.rs` + `foo/` 를 쓴다 (Book 7.5 "most idiomatic"). `foo/mod.rs` 는 older style 이고, 같은 모듈에 둘 다 있으면 E0761. 예외는 `tests/common/mod.rs` (Book 11.3). 파일 이름은 주 타입 이름, non-leaf 모듈은 선언·re-export 만 둔다 (Google). `user/user.rs` 처럼 같은 이름을 중첩하면 clippy `module_inception`(style) 경고
- 모듈은 기능(`user`, `order`) 단위로 묶고 `utils`·`traits`·`errors` 같은 기술 분류는 피한다 (`traits`·`errors` 는 M-BALANCED-MODULES — library 지침을 앱에 유추 적용, `utils` 는 같은 이유로 확장). 앱 경계 `AppError` 하나를 담는 `error.rs` 는 예외 ([rust-error-handling](../rust-error-handling/SKILL.md))

가시성은 Java 와 경계가 다르다. **Rust 의 캡슐화 단위는 타입이 아니라 모듈**이라, 같은 모듈 안 코드는 private 필드도 본다.

| Java | Rust | 범위 |
|---|---|---|
| private (클래스 안) | 정확한 대응 없음 | 경계가 모듈이므로 파일을 작게 유지하는 것이 곧 캡슐화 |
| package-private | 기본 (아무것도 안 씀) | 같은 모듈 + 하위 모듈 |
| 여러 모듈이 공유 | `pub(super)` / `pub(crate)` | 부모 모듈 / crate 전체. rustc `unreachable_pub` 이 crate 밖에 안 나가는 `pub` 을 잡는다 |
| protected | 없음 | 상속이 없다 |

impl 분할: 같은 crate 면 하위 파일에서 `impl Order` 를 이어 쓸 수 있고 private 필드도 보인다. 하위 파일의 method 는 그 하위 모듈 private 이므로 부모가 부를 것은 `pub(super)` 로 연다. 다만 Google 의 "non-leaf 모듈에 구현을 두지 않는다" 와 부딪치므로, 먼저 책임별 타입·모듈로 나눌 수 있는지 보고 한 타입이 정말 클 때만 쓴다.

```rust
// src/order/pricing.rs — Order 의 discount_rate 는 0..=100 을 생성자에서 보장하는 DiscountRate newtype
use super::Order;

impl Order {
    // pub(super) 가 없으면 order.rs 의 self.discounted_total() 이 error[E0624]: method `discounted_total` is private
    pub(super) fn discounted_total(&self) -> Option<u64> {
        // 기본 release profile(overflow-checks 꺼짐)은 금액 overflow 를 panic 없이 wrap 하므로 checked_* 로 None 을 돌려준다
        let gross = self.lines.iter().try_fold(0_u64, |sum, l| {
            sum.checked_add(l.price.checked_mul(u64::from(l.qty))?)
        })?;
        // DiscountRate 가 0..=100 을 보장하므로 뺄셈은 넘치지 않는다
        gross
            .checked_mul(u64::from(100 - self.discount_rate.percent()))
            .map(|v| v / 100)
    }
}
```

**파일 길이 (house rule)**: Rust Style Guide·Microsoft·Google·Linux kernel·rust-analyzer 어디에도 파일·함수 길이 숫자 한도는 없고, clippy 에 파일 길이 lint 도 없다. 이 레포는 **테스트 모듈을 뺀 400줄 초과 `.rs` 를 분할 검토 대상**으로 두고 스크립트로 잰다.

```sh
# 파일 끝의 테스트 모듈(0열 #[cfg(test)] 다음 줄이 `mod tests {`)부터 제외하고 센다
git ls-files '*.rs' | while IFS= read -r f; do
  n=$(awk 'prev ~ /^#\[cfg\(test\)\]/ && /^mod tests \{/ { n--; exit } { n++; prev = $0 } END { print n + 0 }' "$f")
  if [ "$n" -gt 400 ]; then echo "$f: $n"; fi
done
```

## Lint 로 강제

레벨은 Cargo.toml, threshold 는 clippy.toml 에 둔다. Cargo.toml 에 쓴 threshold 는 적용되지 않는다: `too_many_lines = { level = "warn", threshold = 100 }` 은 `unused manifest key` 경고만 나고, `[lints.clippy]` 에 `too-many-lines-threshold = 100` 을 쓰면 manifest 파싱 에러다 (로컬 실측).

```toml
# Cargo.toml (workspace root, virtual manifest) — lint 레벨 선택은 house rule
# member 는 edition.workspace = true · rust-version.workspace = true · [lints] workspace = true 를 모두 적는다
# (workspace 안에서 cargo new 가 넣어 준다. 손으로 쓰다 빠뜨리면 edition 2015 로 빌드되고 let chains 가 에러)
[workspace]
members  = ["crates/*"]
resolver = "3"                     # virtual manifest 는 resolver 를 반드시 적는다
[workspace.package]
edition      = "2024"
rust-version = "1.88"              # let chains 하한. 의존성 MSRV 가 더 높으면 그 값. 상속한 member 의 clippy msrv 도 이 값
[workspace.lints.rust]
unreachable_pub = "warn"                   # tests/common/mod.rs helper 도 대상 → pub(crate) fn (로컬 실측)
[workspace.lints.clippy]
too_many_lines                  = "warn"   # pedantic(allow) 이라 직접 켠다
unwrap_used                     = "warn"   # 불변식에는 expect("왜 실패할 수 없는지")
allow_attributes_without_reason = "warn"
manual_let_else                 = "warn"
mod_module_files                = "warn"   # foo/mod.rs 금지. tests/common/mod.rs 는 경고하지 않는다
undocumented_unsafe_blocks      = "warn"   # unsafe 블록마다 // SAFETY: 주석 (restriction 이라 직접 켠다)
```

```toml
# clippy.toml (workspace root) — 값은 모두 house rule
too-many-lines-threshold    = 100   # 기본값과 같지만 명시한다. 기본값이 바뀌어도 기준이 유지된다
excessive-nesting-threshold = 4     # 시작값. 실제 코드의 경고 수를 잰 뒤 조정한다
allow-unwrap-in-tests       = true
```

- 단일 crate 면 같은 표를 `[lints.rust]`·`[lints.clippy]` 로 쓴다. Cargo 는 표 안 순서를 무시하므로, 그룹 안 개별 lint 를 덮어쓰려면 `pedantic = { level = "warn", priority = -1 }` 처럼 그룹 priority 를 더 낮춘다. 같은 priority 에 그룹과 level 이 다른 개별 lint 가 있으면 `lint_groups_priority`(correctness, 기본 deny)가 에러를 낸다 (virtual manifest 의 `[workspace.lints]` 에서도 로컬 실측). pedantic 전체를 켜면 `missing_errors_doc` 때문에 `Result` 를 돌려주는 export 된 `pub fn`(crate root 에서 `pub` 경로로 닿는 것. 기본 `check-private-items = false` 라 private 모듈 안 `pub fn` 은 제외, bin crate 의 root `pub fn` 은 포함 — 로컬 실측)마다 `# Errors` 문서가 필요하므로 팀이 정한다. restriction 그룹은 통째로 켜지 않고 lint 단위로 켜며, correctness 는 기본 deny 를 유지한다 (Microsoft 템플릿의 warn 을 복사하지 않는다)
- clippy.toml 은 (`CLIPPY_CONF_DIR` 가 없으면) crate 디렉토리에서 위로 올라가 **처음 찾은 파일 하나만** 쓰이고 병합되지 않는다 (로컬 실측: 자기 clippy.toml 을 둔 member 에는 root 의 nesting threshold 가 적용되지 않았다). member crate 에 자기 clippy.toml(core 의 `disallowed-methods` 등)을 두면 위 threshold 를 그 파일에 복제한다. lint 이름은 Cargo.toml 에서 underscore(`too_many_lines`), clippy.toml 키는 hyphen 이다 (Cargo 1.99+ 는 `[lints]` 의 hyphen 이름에 경고). `inline_modules`(1.97+, `#[cfg(test)]` 를 뺀 inline mod 금지)는 toolchain 이 1.97 이상일 때 추가한다
- `allow-unwrap-in-tests` 는 `#[test]` 함수와 `#[cfg(test)]` 모듈만 보므로 1.96 은 `tests/common/mod.rs` helper 의 `unwrap()` 을 경고한다 (로컬 실측). 1.100 CHANGELOG 는 integration test 로 넓혔지만, 구현은 rustc 입력 경로가 `tests` 로 시작하는지만 보고 workspace member 는 `crates/<x>/tests/…` 로 넘어간다 (로컬 확인) → member 에도 적용되는지 ⚠️ 1.100 미측정. helper 에서는 `expect("seed fixture is valid")` 를 쓴다

| lint | 그룹·기본값 | 세는 방식 | 주의 |
|---|---|---|---|
| `too_many_lines` | pedantic, 100 | 코드가 있는 줄만 (빈 줄·주석만 있는 줄·바깥 중괄호 제외), closure 는 부모에 포함 | 화면 줄 수보다 느슨하다. 20-50줄 PREFER 는 리뷰 기준 |
| `excessive_nesting` | complexity, 0 = 꺼짐 | `if` 뿐 아니라 `impl`·trait·inline mod·함수 본문도 1단계 | 4 일 때 free fn 은 4번째 중첩 `if`, impl method 는 3번째 중첩 `if` 에서 경고 (로컬 실측) |
| `too_many_arguments` | complexity, 7 | 인자 8개부터 | trait impl 은 제외 |

**`cognitive_complexity` 는 쓰지 않는다.** 레포 공통 rule 의 "Cognitive Complexity ≤ 15" 를 이 lint 로 강제하면 안 된다. 1.91 에 restriction 으로 옮겨졌고, 문서가 "left in `restriction` so as to not mislead users into using this lint as a measurement tool" 이라고 적는다. 대신 `too_many_lines` + `excessive_nesting` + 리뷰로 본다. CI 는 `cargo clippy --all-targets -- -D warnings` 로 막고, 코드에 `#![deny(warnings)]` 를 넣지 않는다 (컴파일러가 바뀌면 빌드가 깨진다). 예외는 `#[expect(lint, reason = "…")]` (1.81+) 로 단다. 경고가 사라지면 `unfulfilled_lint_expectations` 로 알려 주므로 함수가 짧아진 뒤 예외가 남지 않는다 (로컬 실측). 단 build target·feature 마다 lint 결과가 다르면 `#[expect]` 가 한쪽에서 unfulfilled 가 되므로 `#[allow(.., reason)]` 를 쓴다. 예: lib build 에서만 dead 인 fn 의 `#[expect(dead_code)]` 는 `--all-targets` 의 test build 에서 unfulfilled 다 (로컬 실측. test 전용 fn 이면 `#[cfg(test)]` 가 먼저다). `#[allow]` 자체를 막으려면 restriction `allow_attributes` 를 켠다.

```rust
#[expect(clippy::too_many_lines, reason = "전이 표는 한 match 에 모아 둬야 한눈에 읽힌다")]
pub fn next_state(state: JobState, event: JobEvent) -> Option<JobState> {
    match (state, event) {
        (JobState::Queued, JobEvent::Claimed) => Some(JobState::Running),
        // … 100줄을 넘는 (상태, 이벤트) 조합
        // 허용 목록 방식: 표에 없는 전이는 모두 거부한다. 빠진 전이는 컴파일러가 못 잡으므로 테스트로 확인
        _ => None,
    }
}
```

## Anti-Patterns

| 실수 | 문제 | 대신 |
|---|---|---|
| `if` 안에 `if` 로 검증을 늘어놓은 service | happy path 가 맨 안쪽에 묻히고 clippy 도 못 잡는다 | `check_x()?` 단계 + newtype 생성자 |
| 루프 안에서 `&mut self` helper 호출 | E0502 | 필드만 받는 fn, 계산 → 대입 분리 |
| bool flag 인자 | 호출부에서 의미가 안 보인다 | 2-variant enum, 이름 있는 두 함수 |
| `cognitive_complexity` 로 CC ≤ 15 강제 | clippy 문서가 측정값을 부정한다 | `too_many_lines` + `excessive_nesting` + 리뷰 |
| reason 없는 `#[allow]`, 코드의 `#![deny(warnings)]` | 예외가 영구화되고 toolchain 업데이트 때 빌드가 깨진다 | `#[expect(.., reason)]`, CI 의 `-D warnings` |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:
1. **[기능 검증]** — `cargo test` 통과, `cargo clippy --all-targets -- -D warnings` 경고 0. 예: clippy.toml 의 `too-many-lines-threshold` 를 잠깐 올려 `#[expect(clippy::too_many_lines)]` 함수에 `unfulfilled_lint_expectations` 가 뜨면 설정 파일이 실제로 읽히는 것이다
2. **[구조]** — 파일 길이 스크립트 출력이 비었거나, 출력된 파일마다 분할 검토 결과(분할 또는 유지 이유)가 PR 에 적혀 있다. reason 없는 `#[allow]` 가 0건이다 (`allow_attributes_without_reason` 경고 0 — 1번 clippy 에 포함). 예외는 `#[expect(.., reason)]` 가 기본이고, `rg -n '#!?\[allow\(' --type rust` 로 나온 `#[allow]` 는 target 마다 lint 결과가 다른 경우뿐이다
3. **[일관성]** — rust.md rule 의 Composed Method·lint 설정 bullet 과 충돌이 없다. 함수 길이는 [clean-code rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/clean-code.md) 의 20-50줄 PREFER·100줄 초과 금지와 같은 값을 clippy.toml 에 둔다

## 참조 스킬

- [rust-error-handling](../rust-error-handling/SKILL.md) — `check_x()?` 가 돌려주는 에러 타입 설계, `expect`·panic 정책 · [rust-engine-architecture](../rust-engine-architecture/SKILL.md) — core/shell workspace, core 전용 clippy.toml, 단위 newtype
- [rust-testing](../rust-testing/SKILL.md) — `#[cfg(test)] mod tests`·`tests/` 배치, `should_x_when_y` 이름 · rust-from-spring — Spring 개념 → Rust 대응표
- `/dx:clean-code` — Composed Method·SLAP·Guard Clause 원칙 (Java·Go 예시) · `/dx:refactoring-principles` — 동작을 유지하며 단계적으로 쪼개는 절차

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. "로컬 실측" 은 rustc·clippy 1.96.0 scratch crate 결과다. 다음 재검증은 2027-02.
- [Book 12.3](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) · [Book 11.3 — Submodules in Integration Tests](https://doc.rust-lang.org/book/ch11-03-test-organization.html#submodules-in-integration-tests) · [Book 7.5](https://doc.rust-lang.org/book/ch07-05-separating-modules-into-different-files.html) · [Book 7.3 — binary + library](https://doc.rust-lang.org/book/ch07-03-paths-for-referring-to-an-item-in-the-module-tree.html#best-practices-for-packages-with-a-binary-and-a-library) · [Book 3.2 — Integer Overflow](https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-overflow) · [Book 9.2](https://doc.rust-lang.org/book/ch09-02-recoverable-errors-with-result.html) · [Reference — Visibility](https://doc.rust-lang.org/reference/visibility-and-privacy.html) · [Implementations](https://doc.rust-lang.org/reference/items/implementations.html) · [Try propagation](https://doc.rust-lang.org/reference/expressions/operator-expr.html#the-try-propagation-expression) · [rustc allowed-by-default lints](https://doc.rust-lang.org/rustc/lints/listing/allowed-by-default.html#unreachable-pub) · [Rust 1.65.0](https://blog.rust-lang.org/2022/11/03/Rust-1.65.0/) · [1.81.0](https://blog.rust-lang.org/2024/09/05/Rust-1.81.0/) · [1.88.0](https://blog.rust-lang.org/2025/06/26/Rust-1.88.0/) · [std Option](https://doc.rust-lang.org/std/option/enum.Option.html) · [Rust Style Guide](https://doc.rust-lang.org/style-guide/index.html) · [Linux kernel Rust coding guidelines](https://docs.kernel.org/rust/coding-guidelines.html) · [Google Rust Style Guide](https://google.github.io/styleguide/rustguide.html) · [rust-analyzer style](https://raw.githubusercontent.com/rust-lang/rust-analyzer/master/docs/book/src/contributing/style.md) — 검증일 2026-11-15 · ✅ verified (E0761·E0624·E0308(`&Nickname` → `&str`)·`tests/common` 의 `unreachable_pub` 경고·block 안 `?` 가 바깥 함수를 빠져나가는 것은 로컬 실측; let-else·labeled block `break`(1.65), `#[expect]`, let chains·edition 2021 컴파일 에러 로컬 재현, `is_some_and`·`is_none_or`; ❌→정정: 길이 숫자 한도 없음, Google 적용 범위는 "intend to start applying" 단계; rust-analyzer: 프로젝트 내부 스타일) · subagent
- [Microsoft Guidelines — Universal](https://microsoft.github.io/rust-guidelines/guidelines/universal/index.html) · [Resilience](https://microsoft.github.io/rust-guidelines/guidelines/libs/resilience/index.html) · [Libraries UX](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html) · [API Guidelines — Predictability](https://rust-lang.github.io/api-guidelines/predictability.html) · [Naming](https://rust-lang.github.io/api-guidelines/naming.html) · [Parse, don't validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) · [Comprehensive Rust — Parse, don't validate](https://google.github.io/comprehensive-rust/idiomatic/leveraging-the-type-system/newtype-pattern/parse-don-t-validate.html) · [After NLL: interprocedural conflicts](https://smallcultfollowing.com/babysteps/blog/2018/11/01/after-nll-interprocedural-conflicts/) · [Nomicon — Splitting Borrows](https://doc.rust-lang.org/nomicon/borrow-splitting.html) · [View types experiment](https://goals.rust-lang.org/2026/view-types-experiment.html) · [Anti-pattern: Clone to satisfy the borrow checker](https://rust-unofficial.github.io/patterns/anti_patterns/borrow_clone.html) — 검증일 2026-11-15 · ✅ verified (M-REGULAR-FN 은 Universal. M-STRONG-TYPES-GUARD·M-BALANCED-MODULES 는 library 지침이라 앱에는 유추 적용; C-METHOD, C-GETTER; E0502 로컬 재현. view types 는 ❌→정정: Accepted 상태의 실험) · subagent
- [Cargo manifest — lints](https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section) · [workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html) · [profiles — release](https://doc.rust-lang.org/cargo/reference/profiles.html#release) · [Cargo CHANGELOG](https://doc.rust-lang.org/nightly/cargo/CHANGELOG.html) · [Clippy configuration](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/book/src/configuration.md) · [lint configuration — msrv](https://doc.rust-lang.org/clippy/lint_configuration.html#msrv) · [avoid-breaking-exported-api](https://doc.rust-lang.org/clippy/lint_configuration.html#avoid-breaking-exported-api) · [lint list](https://rust-lang.github.io/rust-clippy/stable/index.html) · [README](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/README.md) · [Anti-pattern: deny(warnings)](https://rust-unofficial.github.io/patterns/anti_patterns/deny-warnings.html) · Clippy lint 소스 [too_many_lines](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/functions/too_many_lines.rs) · [excessive_nesting](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/excessive_nesting.rs) · [too_many_arguments](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/functions/too_many_arguments.rs) · [excessive_bools](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/excessive_bools.rs) · [collapsible_if](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/collapsible_if.rs) · [manual_let_else](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/manual_let_else.rs) · [items_after_statements](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/items_after_statements.rs) · [unused_self](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/unused_self.rs) · [module_style](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/module_style.rs) · [item_name_repetitions](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/item_name_repetitions.rs) · [cargo lints](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cargo/mod.rs) · [lint_groups_priority](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cargo/lint_groups_priority.rs) · [unnecessary_map_or](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/methods/unnecessary_map_or.rs) · [missing_errors_doc](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/doc/mod.rs) · [missing_headers](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/doc/missing_headers.rs) · [undocumented_unsafe_blocks](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/undocumented_unsafe_blocks.rs) · [Clippy cognitive_complexity](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cognitive_complexity.rs) · [Clippy CHANGELOG](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/CHANGELOG.md) · [rust-clippy PR #16786](https://github.com/rust-lang/rust-clippy/pull/16786) · [clippy_utils `is_in_test` (rust-1.100.0)](https://raw.githubusercontent.com/rust-lang/rust-clippy/rust-1.100.0/clippy_utils/src/lib.rs) — 검증일 2026-11-15 · ✅ verified (release 기본 `overflow-checks = false`, `[workspace.package]` 는 member 가 `{key}.workspace = true` 로 opt-in 해야 상속된다. 빠뜨리면 edition 2015, cargo new 가 세 줄을 넣는 것, Cargo.toml 에 쓴 threshold 두 형태의 결과는 로컬 실측; clippy.toml "unstable and may be deprecated", 탐색 시작은 `CLIPPY_CONF_DIR` → `CARGO_MANIFEST_DIR` → 현재 디렉토리, msrv 기본은 `rust-version`, `avoid-breaking-exported-api` 기본 true, 그룹 기본 레벨. 가장 가까운 clippy.toml 하나만 쓰이는 것은 로컬 실측; threshold 4 경계·let chain 제안·`collapsible_match`·`unnecessary_map_or` 제안·`[workspace.lints]` 의 `lint_groups_priority` 에러·target 별 `#[expect]` unfulfilled·`missing_errors_doc` 의 export 범위는 로컬 실측; 1.91 restriction 이동, 1.97 `collapsible_match` guard 제안 축소, 1.100 integration test 판정은 입력 경로 `tests` 접두사 검사) / ⚠️ 1.99 hyphen lint 이름 경고는 로컬 toolchain 1.96 이라 미측정 / ⚠️ 1.97+ 동작은 로컬 toolchain 1.96 이라 미측정 · subagent
