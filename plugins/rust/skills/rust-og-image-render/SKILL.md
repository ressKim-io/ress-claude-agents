---
name: rust-og-image-render
description: "Rust OG 미리보기 이미지 렌더 — resvg·usvg·tiny-skia 파이프라인, 한글 폰트 번들·keep-all 줄바꿈, SVG escape·외부 리소스 차단, CPU 오프로드·동시성 상한, golden 이미지 테스트. Use when Rust 로 공유 링크 미리보기 이미지를 만들거나 렌더 결과에서 한글이 깨지거나 잘릴 때."
---

# Rust OG Image Render — 한글 미리보기 이미지 렌더

Go 가 내부 동기 HTTP 로 부르는 렌더 서버(og-render)를 resvg 로 만들 때의 결정 기준이다. 입력 정제·폰트·한글 줄바꿈·SVG 보안·동시성 상한·캐시 위치·golden 테스트를 다룬다. core/shell 분리는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md), CPU 오프로드 일반론은 [rust-async-tokio](../rust-async-tokio/SKILL.md) 에 있다.

## Quick Reference (결정 트리)

```
무엇으로 그릴까?
├── 템플릿 몇 종, 텍스트 + 도형 + 로고 ──────> SVG 문자열 → resvg (이 skill)
├── 프론트와 JSX·CSS 템플릿을 공유해야 한다 ──> satori(Node) / takumi (default-features = false — 기본 feature 가 libwebp-sys C 빌드를 끌어온다. 필요한 feature 이름은 ⚠️ 도입 시 확인)
└── 임의 HTML·복잡한 CSS 를 그대로 ─────────> headless Chrome 별도 서비스 (무겁다)
글자가 이상하다?
├── 한글이 빈칸·□ ────────────> fontdb 에 한글 폰트를 안 넣었다 (Options::default 는 비어 있음)
├── 이모지만 빈칸 ────────────> 이모지 폰트를 번들 안 했거나, CBDT·sbix 인데 raster-images 가 없다
├── dev 는 되고 prod 만 깨짐 ──> load_system_fonts() 사용 → 번들 폰트만 쓴다
├── 제목이 캔버스 밖으로 ─────> resvg 는 inline-size·text-overflow 미지원 → 줄을 먼저 나눈다
├── "한강 공원"이 "한강 공/원" ─> 음절 단위 줄바꿈 → 공백 기준 keep-all 직접 구현
└── 특정 입력만 500 ──────────> U+FFFE·U+FFFF·C0 제어문자 → XML Char 필터
요청이 몰리면?
├── 렌더 슬롯이 남았다 ───> spawn_blocking, 슬롯 수는 코어 수에서 시작해 부하 테스트로 조정 (permit 은 클로저 안으로)
├── 슬롯이 없다 ──────────> 기다리지 않고 503 (try_acquire_owned) → Go 가 재시도하거나 기본 이미지를 쓴다
└── 오래 걸린다 ──────────> TimeoutLayer::with_status_code(503). 렌더는 계속 돌므로 permit 이 상한을 지킨다
```

## 1. 파이프라인과 crate 구성

`render_png` 는 검증된 `CleanText` 를 받아 layout → build_svg → rasterize → encode 네 단계를 부르는 Composed Method 다 (§6). validate 는 handler 가 `CleanText` 를 만들 때 끝난다 (§3·§7).

| 단계 | 위치 (og-core) | 하는 일 | 실패 |
|---|---|---|---|
| validate | `input.rs` `CleanText::parse` | XML Char 필터 → NFC → grapheme 상한 | 400 |
| layout | `layout.rs` `wrap_keep_all` | 공백 기준 keep-all, 긴 단어만 grapheme 분할, 마지막 줄 `…` | 500 (폭 측정) |
| build_svg | `template.rs` `build_svg` | 줄마다 escape 한 번, 사용자 값은 텍스트 노드에만 | — |
| rasterize | `renderer.rs` `Renderer::rasterize` | `usvg::Tree::from_str` → `resvg::render` | 500 |
| encode | `renderer.rs` `render_png` | `Pixmap::encode_png` | 500 |

```toml
# og-core/Cargo.toml — tokio·axum 없음
[dependencies]
resvg = { version = "0.50", default-features = false, features = ["text", "raster-images"] }
png = "0.18"                    # png::EncodingError 를 #[from] 으로 받으려면 직접 의존 (re-export 안 됨) — tiny-skia 가 쓰는 png 와 같은 버전으로 맞춘다 (cargo tree -i png 로 확인. 갈리면 ? 변환이 E0277 컴파일 에러)
unicode-normalization = "0.1"
unicode-segmentation = "1.13"
thiserror = "2.0"
# og-server: og-core + axum = "0.8", tokio = "1.54"(rt-multi-thread·macros·sync), tower-http = "0.7"(timeout), serde = "1.0"(derive), thiserror = "2.0", tracing = "0.1"
```

| resvg feature | 기본 | 여기서 | 이유 |
|---|---|---|---|
| `text` | ✅ | 켠다 | `<text>` 처리 (fontdb·harfrust·skrifa 를 끌어온다) |
| `raster-images` | ✅ | 켠다 | CBDT·sbix 컬러 이모지와 `<image>` 의 PNG·JPEG·GIF·WebP. 없으면 이모지가 빈칸 |
| `system-fonts` | ✅ | 끈다 | 시스템 폰트 탐색 (fontconfig). 켜 두고 `load_system_fonts()` 를 부르면 dev·prod 결과가 갈린다 |
| `memmap-fonts` | ✅ | 끈다 | 폰트 파일 mmap. 번들 바이트만 쓰면 필요 없다 |
| `svgz` | ✅ | 끈다 | gzip SVG 입력. SVG 를 직접 만들므로 필요 없다 |

- resvg 0.48 부터 shaping 은 harfrust, 폰트 파싱은 skrifa 다("small rendering changes"). archived 된 rustybuzz 를 직접 쓰는 옛 예제는 따라 하지 않는다. bin 은 Cargo.lock 을 커밋하고, resvg 를 올리는 PR 은 golden diff(§9)로 렌더 변화를 확인한다.

## 2. 폰트 — 번들만 쓰고 시작 시 검사한다

`Options::default()` 의 fontdb 는 비어 있고 기본 `font_family` 는 Times New Roman 이다. 폰트를 넣지 않으면 한글이 그려지지 않는다(로컬 실측: 텍스트 bounding box 가 `None`). `Renderer` 는 시작할 때 한 번 만들어 `Arc` 로 공유한다 (`Options<'static>`·`Tree` 는 Send + Sync).

```rust
use resvg::tiny_skia::{Pixmap, Transform};
use resvg::usvg::{self, fontdb};
use std::sync::Arc;
pub struct Renderer {
    opt: usvg::Options<'static>,
}
impl Renderer {
    pub fn new(fonts: impl IntoIterator<Item = &'static [u8]>, family: &str) -> Result<Self, FontMissing> {
        let mut opt = usvg::Options::default(); // fontdb 가 비어 있다
        let db = opt.fontdb_mut();
        for font in fonts {
            db.load_font_source(fontdb::Source::Binary(Arc::new(font))); // 복사 없음. OTF/TTF/TTC, woff2 는 못 읽는다
        }
        let query = fontdb::Query { families: &[fontdb::Family::Name(family)], ..Default::default() };
        if db.query(&query).is_none() {
            return Err(FontMissing(family.to_owned())); // 잘못된 번들을 시작 시점에 잡는다
        }
        db.set_sans_serif_family(family);
        opt.font_family = family.to_owned();
        opt.image_href_resolver = usvg::ImageHrefResolver {
            resolve_data: Box::new(|_, _, _| None), // data: URL
            resolve_string: Box::new(|_, _| None),  // 로컬 파일 경로
        };
        opt.max_depth = 16; // 템플릿 깊이에 맞춘다. 기본 1024
        Ok(Self { opt })
    }
}
// main: const FONT: &[u8] = include_bytes!("../assets/fonts/NotoSansCJKkr-Bold.otf"); Renderer::new([FONT], "Noto Sans CJK KR")?
```

- **의존성**: usvg·fontdb·tiny_skia 는 resvg 의 re-export 로 쓴다. 직접 의존하면 버전이 어긋날 때 같은 타입이 두 벌이 된다. **시작 경계**: `FontMissing(String)` 은 `Renderer::new` 에서만 나오는 에러 struct 라 요청 경계의 `RenderError`(§6)와 나눈다. `load_font_data(include_bytes!(..).to_vec())` 는 바이너리에 든 폰트를 힙에 한 벌 더 복사한다(Noto Sans CJK KR Bold 16,997,996 bytes) → `&'static [u8]` 를 `Source::Binary` 로 넘긴다. **폰트 선택**: Noto Sans CJK 와 Pretendard 는 OFL 1.1 이다. 번들은 허용되고, 생성된 이미지에는 의무가 없다. 다만 **사본마다 저작권 고지와 LICENSE 를 함께 둔다**(조건 2). 서브셋은 수정판이라 Reserved Font Name(RFN)을 쓸 수 없다(조건 3). Pretendard 의 RFN 은 Pretendard·Source·Inter·M PLUS 1 이라 서브셋하면 이름을 바꾸거나 원본을 번들한다. Noto CJK Sans LICENSE 에는 RFN 선언이 없다. **형식·커버리지**: fontdb 는 woff2 를 읽지 않으므로 OTF/TTF 원본을 번들한다. 현대 한글 11,172 음절(U+AC00–U+D7A3)을 모두 갖는지 도입할 때 skrifa `FontRef::new(&data)?.charmap().map(c)`(`use skrifa::MetadataProvider`)로 확인한다 (로컬 실측: NotoSansCJKkr-Bold.otf 누락 0, Pretendard 는 미검사). **이모지**: usvg 기본 font resolver 가 글자 단위로 fallback 하므로 이모지 폰트를 같이 넣으면 된다. NotoColorEmoji 는 CBDT 비트맵이라 `raster-images` 가 필요하고 약 10MB 다. 로컬 실측(Apple Color Emoji, sbix): `["text"]` 만이면 칠해진 픽셀 0, `raster-images` 를 더하면 3,341. COLR 벡터 이모지는 실측하지 않았다.

## 3. 입력 정제 — XML Char → NFC → grapheme

정제한 **원문**만 보관하고 escape 는 SVG 를 쓰는 시점에 한다. 생성자에서 escape 하면 폭 측정과 줄바꿈이 `&amp;` 같은 엔티티 문자열 기준으로 이루어지고, 엔티티 중간에서 잘릴 수도 있다.

```rust
// ❌ BAD: is_control 은 Cc 범주만 본다 → U+FFFE·U+FFFF 가 남아 usvg 파싱이 실패한다 (500)
let kept: String = raw.chars().filter(|c| !c.is_control()).collect();
// ✅ GOOD: XML Char 필터 → NFC → grapheme 상한
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CleanText(String);
impl CleanText {
    pub fn parse(raw: &str, max_graphemes: usize) -> Result<Self, InputError> {
        let filtered: String = raw.chars().filter(|&c| is_xml_char(c)).collect();
        let normalized: String = filtered
            .nfc()
            .map(|c| if c.is_control() { ' ' } else { c }) // 줄은 layout 이 다시 나눈다
            .collect();
        let cut: String = normalized.graphemes(true).take(max_graphemes).collect();
        let trimmed = cut.trim();
        if trimmed.is_empty() {
            return Err(InputError::EmptyTitle);
        }
        Ok(Self(trimmed.to_owned()))
    }
    pub fn as_str(&self) -> &str {
        &self.0
    }
}
// XML 1.0 Char 프로덕션. char 에는 surrogate 가 없으므로 D800–DFFF 는 볼 필요가 없다
fn is_xml_char(c: char) -> bool {
    matches!(c, '\t' | '\n' | '\r' | '\u{20}'..='\u{D7FF}' | '\u{E000}'..='\u{FFFD}' | '\u{10000}'..)
}
```

| 순서 | 빠뜨리면 |
|---|---|
| XML Char 필터 | U+FFFE 한 글자가 들어가도 usvg 파싱이 실패해 500 (로컬 실측). escape 로는 막지 못한다 |
| NFC | NFD 로 들어온 같은 제목이 다른 캐시 키·다른 렌더가 된다. 필터 뒤에 정규화해야 결과가 NFC 로 남는다 |
| grapheme 상한 | `chars().take(n)` 은 `👨‍👩‍👧` 를 `👨` 로 자른다. `graphemes(true)`(extended)를 쓴다 |

`max_graphemes` 는 렌더 비용 상한이다. 화면에 넘치는 부분은 layout 이 `…` 로 처리하므로 상한은 최대 줄 수에 들어가는 길이보다 넉넉하게 잡는다. 400 응답 문구는 [rust-error-handling](../rust-error-handling/SKILL.md) 의 경계 규칙을 따른다.

## 4. 한글 줄바꿈 — keep-all 을 직접 구현한다

resvg 는 SVG 2 의 `inline-size`·`white-space`·`text-overflow`·`line-height`·`text-align` 을 구현하지 않았다(`direction`·`unicode-bidi` 도 미지원). 긴 제목은 그대로 캔버스 밖으로 나가므로 **줄을 먼저 나누고 줄마다 `<text>` 를 만든다.** UAX #14 기본 규칙은 한글 음절 사이를 줄바꿈 후보로 본다. 왼쪽 정렬에서는 공백 기준 줄바꿈이 일반적이고, 그러려면 한글을 AL 로 tailoring 하라고 문서가 안내한다. cosmic-text 의 `Wrap::Word` 는 UAX #14 기본 규칙이라 음절마다 끊는다. keep-all 옵션은 없다. 게다가 usvg 와 다른 버전의 fontdb·harfrust·skrifa 를 끌어와 두 벌이 링크되고, shaping 버전이 달라 폭 측정이 렌더와 어긋날 수 있다.

```rust
pub fn wrap_keep_all<E>(
    text: &str,
    max_width: f32,
    max_lines: usize,
    measure: impl Fn(&str) -> Result<f32, E>,
) -> Result<Vec<String>, E> {
    let mut lines = Vec::new();
    let mut current = String::new();
    for word in text.split_whitespace() {
        let candidate = if current.is_empty() { word.to_owned() } else { format!("{current} {word}") };
        if measure(&candidate)? <= max_width {
            current = candidate;
            continue;
        }
        if !current.is_empty() {
            lines.push(std::mem::take(&mut current));
        }
        current = break_long_word(word, max_width, max_lines, &measure, &mut lines)?;
        if lines.len() >= max_lines {
            break; // 화면에 안 나올 줄은 재지 않는다. 남은 current 때문에 fit_max_lines 가 '…' 를 붙인다
        }
    }
    if !current.is_empty() {
        lines.push(current);
    }
    fit_max_lines(lines, max_width, max_lines, &measure) // 넘치면 마지막 줄을 grapheme 단위로 줄이고 '…'
}
```

`break_long_word`(줄을 넘긴 단어가 한 줄에 들어가면 한 번만 재고 돌려준다. 넘치는 단어만 grapheme prefix 를 하나씩 재며 채우고, `max_lines` 를 받아 줄 수가 차면 멈춘다)와 `fit_max_lines`(마지막 줄 말줄임)도 `measure: &impl Fn(&str) -> Result<f32, E>` 를 받는 짧은 함수다. `measure` 를 인자로 받으므로 단위 테스트는 "grapheme 하나 = 폭 1" fake 로 돌린다 ([rust-testing](../rust-testing/SKILL.md)). 실제 폭은 **렌더와 같은 shaping 스택**에서 잰다:

```rust
impl Renderer {
    pub fn text_width(&self, text: &str, font_size: f32) -> Result<f32, RenderError> {
        let svg = format!(
            r#"<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><text font-size="{font_size}">{}</text></svg>"#,
            escape_text(text)
        );
        let tree = usvg::Tree::from_str(&svg, &self.opt)?;
        Ok(tree.root().bounding_box().map_or(0.0, |b| b.width())) // 글리프 외곽선이 아니라 폰트 metrics(advance) 기준. 배치된 글자가 없으면 None
    }
}
```

- `Group::bounding_box` 는 0.50 부터 `Option` 이다. 텍스트의 bbox 는 글리프 모양이 아니라 폰트 metrics(advance·ascent)로 잰다(usvg `text/layout.rs`). advance 밖으로 그려지는 글리프가 있으면 측정보다 넓게 보이므로 `max_width` 에 여유를 둔다. 후보마다 SVG 를 한 번 파싱하므로 `max_graphemes` 로 호출 수에 상한을 걸고, 줄 수가 차면 남은 단어도, 긴 단어 안의 남은 grapheme 도 재지 않는다. 호출 수는 대략 `max_lines` × 한 줄 grapheme 수로 묶이고 제목 길이와는 무관하다(로컬 테스트: 폭 3·2줄 fake 기준 200자 단어도 측정 호출 20회 미만, 줄을 넘겨도 한 줄에 들어가는 단어는 1회). 공백 외의 줄바꿈 기회(하이픈·슬래시 뒤, CJK 문장부호)는 다루지 않는다. 필요해지면 한글을 AL 로 tailoring 한 UAX #14 구현을 검토한다.

## 5. SVG 생성과 보안

`Theme` 은 색(`background`·`color`)과 좌표·폰트 크기·`max_width`·`max_lines` 를 담는 상수 struct 다. **속성에 들어가는 색은 `&'static str` 로 받아** 요청 값을 실수로 속성에 넣는 길을 타입으로 좁힌다(`String::leak` 을 쓰면 뚫리니 리뷰에서 본다).

```rust
use std::fmt::Write;
pub fn escape_text(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;") // & 를 먼저
}
pub fn build_svg(lines: &[String], theme: &Theme) -> String {
    let mut svg = format!(
        r#"<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}"><rect width="100%" height="100%" fill="{}"/>"#,
        theme.background
    );
    for (i, line) in lines.iter().enumerate() {
        let y = theme.top + theme.line_height * i as f32;
        let text = escape_text(line); // 사용자 값은 텍스트 노드에만, 줄마다 한 번만 escape
        write!(
            svg,
            r#"<text x="{}" y="{y}" font-size="{}" fill="{}">{text}</text>"#,
            theme.left, theme.font_size, theme.color
        )
        .expect("writing to a String cannot fail");
    }
    svg.push_str("</svg>");
    svg
}
```

| 위협 | 막는 곳 |
|---|---|
| 마크업 주입 (`<`, `&`) | 텍스트 노드는 `&`·`<`(+`>`)를 escape. 사용자 값을 `href`·`style`·속성 이름에 넣지 않는다. `quick_xml::escape::escape` 를 써도 된다 |
| 파싱 실패 → 500 | §3 XML Char 필터. escape 만으로는 C0 제어문자·U+FFFE·U+FFFF 를 못 막는다 |
| 로컬 파일 읽기 | 기본 `ImageHrefResolver` 는 로컬 파일을 연다(로컬 실측: 절대 경로 이미지가 렌더됨). 두 resolver 모두 `None` 을 돌려주면 노드가 제거된다 |
| SSRF | usvg 는 네트워크 요청을 하지 않는다. 렌더러가 사용자 URL 을 직접 받아 fetch 하지 않는다. 아바타 같은 이미지는 Go 가 검증한 바이트를 넘기고, 그때만 `resolve_data` 를 연다(`resolve_string` 은 계속 차단). `data:` URL 은 렌더러가 바이트를 base64 로 직접 인코딩하고 MIME 은 허용 목록에서 골라 만든다(요청 문자열을 `href` 에 그대로 넣지 않는다). `ImageHrefResolver::default_data_resolver()` 는 SVG data 도(`svgz` feature 를 켜면 SVGZ 도) 받아 중첩 트리로 파싱하므로, 아바타만이면 mime 이 `image/png`·`image/jpeg` 일 때만 `ImageKind::PNG`·`ImageKind::JPEG` 를 돌려주는 resolver 를 직접 둔다(로컬 테스트) |
| 깊은 중첩 | `max_depth` 를 템플릿 깊이에 맞게 낮춘다 (0.50 에서 추가, 기본 1024). 순환 참조는 0.50 이 자체로 거부한다 |

## 6. 래스터화·PNG·캔버스

```rust
pub const WIDTH: u32 = 1200;
pub const HEIGHT: u32 = 630;
impl Renderer {
    pub fn render_png(&self, title: &CleanText, theme: &Theme) -> Result<Vec<u8>, RenderError> {
        let lines = wrap_keep_all(title.as_str(), theme.max_width, theme.max_lines, |s| {
            self.text_width(s, theme.font_size)
        })?;
        let pixmap = self.rasterize(&build_svg(&lines, theme))?;
        Ok(pixmap.encode_png()?)
    }
    fn rasterize(&self, svg: &str) -> Result<Pixmap, RenderError> {
        let tree = usvg::Tree::from_str(svg, &self.opt)?;
        let mut pixmap = Pixmap::new(WIDTH, HEIGHT).ok_or(RenderError::Canvas)?;
        resvg::render(&tree, Transform::default(), &mut pixmap.as_mut());
        Ok(pixmap)
    }
}
```

- **크기**: Meta 는 1200x630 이상(최소 200x200, 1.91:1, 8MB 이하)을 권한다. 카카오 운영진 답변은 800x400(2:1) 최적화와 내부 smart crop 이다. 1200x630 으로 그리되 위아래 가장자리에 핵심 텍스트를 두지 않는다. 실제 잘림은 공유해서 확인한다. **형식**: 카카오는 JPG·PNG 만 스크랩하고, pure-Rust WebP 인코더(image)는 lossless 만 지원한다 → PNG. 요청 경계의 `RenderError` 는 `Svg(#[from] usvg::Error)`·`Encode(#[from] png::EncodingError)`·`Canvas` 만 둔다(폰트 누락은 §2 `FontMissing`). 정제를 거친 입력에서 `Svg` 가 나오면 템플릿 버그이므로 500 이다.

## 7. axum 어댑터 — 상한을 넘으면 기다리지 않고 503

axum 은 서비스가 backpressure 를 신경 쓰지 않는다(항상 ready)고 가정하므로, 문서는 backpressure 를 쓰는 middleware 를 피하고 쓴다면 최소한 load shedding 을 하라고 권한다. tower `ConcurrencyLimit` 는 `poll_ready` 에서 **기다린다**. 앞에 `LoadShed` 를 붙이면 기다리지는 않지만 permit 을 응답 future 가 쥔다. timeout 이 그 future 를 drop 하면 permit 이 풀리는데 `spawn_blocking` 렌더는 계속 돌아 상한이 깨진다(로컬 테스트: 상한 1 에서 두 번째 렌더가 시작됨). 그래서 슬롯은 handler 에서 `Semaphore::try_acquire_owned` 로 잡아 클로저로 옮기고, 실패하면 바로 503 을 준다.

```rust
pub async fn render_og(State(app): State<AppState>, Json(req): Json<OgRequest>) -> Result<Response, OgError> {
    let title = CleanText::parse(&req.title, MAX_TITLE_GRAPHEMES)?; // 400
    let permit = app.render_slots.try_acquire_owned().map_err(|_| OgError::Busy)?; // 503
    let renderer = app.renderer; // State 는 요청마다 복제된 값이라 Arc 를 또 clone 하지 않고 옮긴다
    let png = tokio::task::spawn_blocking(move || {
        let _permit = permit; // timeout 으로 응답이 먼저 나가도 렌더가 끝날 때까지 슬롯을 쥔다
        renderer.render_png(&title, &DEFAULT_THEME)
    })
    .await??;
    Ok(([(header::CONTENT_TYPE, "image/png")], png).into_response())
}
pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/render", post(render_og))
        .layer(DefaultBodyLimit::max(16 * 1024))
        .layer(TimeoutLayer::with_status_code(StatusCode::SERVICE_UNAVAILABLE, Duration::from_secs(3)))
        .with_state(state)
}
```

- `OgError` 는 `Invalid(#[from] InputError)`·`Busy`·`Render(#[from] RenderError)`·`Join(#[from] JoinError)` 이다. `impl IntoResponse for OgError` 한 곳에서 `Invalid` → 400, `Busy` → 503, `Render`·`Join` → 500 으로 바꾼다. 500 은 고정 문구 + `error` 로그, 예상된 거절(400·503)은 `debug` 로그다. 구조는 [rust-error-handling](../rust-error-handling/SKILL.md) 의 HTTP 경계와 같다. `AppState` 는 `renderer: Arc<Renderer>` 와 `render_slots: Arc<Semaphore>` 를, `OgRequest` 는 `title: String` 을 담는다(`MAX_TITLE_GRAPHEMES`·`DEFAULT_THEME` 은 상수). 슬롯 수는 CPU 수에서 시작해 부하 테스트로 조정한다. `available_parallelism` 은 cgroup 정보를 읽지 못하면 CPU limit 보다 크게 셀 수 있다 ([rust-async-tokio](../rust-async-tokio/SKILL.md)). `TimeoutLayer::new` 는 deprecated(기본 408)라 `with_status_code` 로 503 을 준다. `DefaultBodyLimit` 기본은 2MB 다(로컬 테스트: 16KB 초과 → 413, 슬롯 0 → 503, 정제 후 빈 제목 → 400). 깨진 JSON 응답 형식까지 맞추려면 `AppJson` extractor 를 쓴다. **왜 rayon 이 아닌가**: 렌더는 CPU 작업이지만, 슬롯 Semaphore 가 동시 렌더를 슬롯 수로 묶고 넘치는 요청은 503 으로 거절한다. rust-async-tokio 의 기준(CPU 계산은 `spawn_blocking` + CPU 전용 Semaphore)대로 시작하고, 측정해서 CPU 가 처리량을 좌우하면 그 skill 의 `on_rayon` 으로 옮긴다. `spawn_blocking` 은 abort 할 수 없고 `rayon::spawn` 은 `()` 를 돌려줘 취소할 핸들이 없으므로 permit 은 어느 쪽이든 클로저 안에 둔다. `spawn_blocking` 은 기본 상한이 512 스레드이며, runtime 종료가 렌더를 무기한 기다리므로 `Runtime::shutdown_timeout` 을 둔다.

## 8. 캐시와 공유 URL — 공개 GET 에서만

| 질문 | 답 | 근거 |
|---|---|---|
| 내부 POST 에 ETag/304? | 쓰지 않는다 | RFC 9110: If-None-Match 가 거짓일 때 304 는 GET·HEAD 만, 그 밖의 메서드는 412. POST 응답은 명시적 freshness 와 같은 URI 의 Content-Location 이 둘 다 있어야만 캐시된다 |
| 어디서 캐시? | 공개 `GET /og/{id}.png?v=<key>` 를 80·443 에 둔다 (Go·CDN·미리 렌더한 저장소 중 팀이 정한다) | 렌더 서버는 렌더만 한다. 카카오 스크래퍼는 80·443 만 허용 (운영진 답변) |
| 키에 무엇을? | 엔진·템플릿·폰트셋 버전 + NFC 정규화된 입력을 해시. 입력 타입에 `HashMap` 을 쓰지 않는다 | 버전이 빠지면 immutable 캐시에 예전 이미지가 남는다 |
| 이미지를 바꾸면? | URL 을 바꾼다 (`?v=` 또는 파일명) | Meta "Use a new URL for the new image", 카카오 썸네일 캐시도 이미지 URL 기준 |
| 응답 헤더 | `Cache-Control: public, immutable, max-age=31536000` (Vercel og 는 `no-transform` 까지 붙인다) | RFC 8246 |
| 메타 태그 | `og:image:width`·`og:image:height`(첫 공유부터 바로 렌더), `og:image:alt` | Meta 문서, ogp.me |

## 9. golden 이미지 테스트

바이트 일치(crates.io 의 OG 이미지가 insta `assert_binary_snapshot!` 로 쓰는 방식)는 인코더 설정만 바뀌어도 깨지고, 이 매크로는 Experimental 이다. 기본은 **픽셀 허용오차 비교**다.

```rust
// tests/common/mod.rs — 채널 차이가 tolerance 를 넘는 픽셀의 비율, 크기가 다르면 None. pub 이면 unreachable_pub 경고라 pub(crate)
pub(crate) fn diff_ratio(actual: &Pixmap, expected: &Pixmap, tolerance: u8) -> Option<f64> {
    if actual.width() != expected.width() || actual.height() != expected.height() {
        return None;
    }
    let differing = actual
        .data()
        .chunks_exact(4)
        .zip(expected.data().chunks_exact(4))
        .filter(|(a, e)| a.iter().zip(e.iter()).any(|(x, y)| x.abs_diff(*y) > tolerance))
        .count();
    Some(differing as f64 / f64::from(actual.width() * actual.height()))
}
// tests/render_korean.rs (mod common; use common::diff_ratio;) — test_renderer() 는 main 과 같은 include_bytes! 번들 폰트로 Renderer::new 를 부른다
#[test]
fn should_match_golden_when_rendering_korean_title() {
    // Given
    let title = CleanText::parse("한강 공원 러닝 10K 완주 기록 — A&B <태그> 똠방각하 햏", 200).unwrap();
    let golden = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/golden/korean_title.png");
    // When
    let png = test_renderer().render_png(&title, &THEME).unwrap();
    // Then
    if std::env::var_os("UPDATE_GOLDEN").is_some() {
        std::fs::write(golden, &png).unwrap(); // 로컬에서만 켠다. diff 는 PR 에서 눈으로 본다
    }
    let ratio = diff_ratio(&Pixmap::decode_png(&png).unwrap(), &Pixmap::load_png(golden).unwrap(), 8).unwrap();
    assert!(ratio < 0.001, "differing pixel ratio {ratio}");
}
```

- tolerance·비율 임계값은 실측으로 정한다. 지각 기반 점수가 필요하면 `image_compare::rgba_hybrid_compare`(MIT)를 쓴다. dssim-core 는 AGPL-3.0 이다. golden 은 폰트·resvg 버전에 묶이므로 CI 와 로컬이 같은 번들 폰트를 쓰게 하고, 테스트가 시스템 폰트를 읽지 않게 한다. fixture: 줄바꿈·말줄임이 일어나는 긴 제목, 띄어쓰기 없는 긴 단어, KS X 1001 2,350자 밖 음절(똠·햏·뷁), ZWJ 이모지, `& < >`, 제어문자·U+FFFE, NFD 입력, 정제 후 빈 문자열(400). 실패 경로 목록은 `/dx:negative-path-coverage`, 스냅샷 운영 일반론은 [rust-testing](../rust-testing/SKILL.md).

## Anti-Patterns

| 실수 | 문제 | 해결 |
|---|---|---|
| `Options::default()` 그대로 렌더, woff2 번들 | 한글이 그려지지 않는다 (fontdb 비어 있음, woff2 미지원) | OTF·TTF 번들 + 시작 시 `query` 검사 |
| 생성자에서 escape | 엔티티 문자열로 폭을 재고 중간에서 자른다 | 원문 보관, 출력 시점에 줄마다 escape |
| 사용자 URL 을 렌더러가 fetch, 기본 resolver 유지 | SSRF·로컬 파일 노출 | deny-all resolver, 이미지 바이트는 Go 가 검증해 전달 |
| `ConcurrencyLimitLayer`(+`LoadShed`)로 상한, permit 을 클로저 밖에서 쥠 | 대기열이 쌓이거나, timeout 뒤 permit 이 풀려 렌더가 상한을 넘는다 | `try_acquire_owned` 실패 → 503, permit 을 `spawn_blocking` 클로저로 move |
| 내부 POST 에 ETag/304, 같은 URL 덮어쓰기 | RFC 위반 / 카카오·Meta 가 갱신하지 않는다 | 공개 GET + 버전이 들어간 URL |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:
1. **[기능 검증]** — `cargo test --workspace` 가 통과하고, 그중 `CleanText`(U+FFFE·U+FFFF·제어문자·NFD·ZWJ), `wrap_keep_all`(공백 기준·긴 단어·말줄임·줄 수가 차면 긴 단어 안에서도 측정 중단·한 줄에 들어가는 단어는 측정 1회·measure 에러 전파), `escape_text` 를 거친 SVG 의 usvg 파싱, golden 비교, handler(400·413·503·200 `image/png`) 테스트가 있다
2. **[렌더 결과]** — 번들 폰트만으로 한글·2,350자 밖 음절·이모지 fixture 가 그려진다. family 를 틀리게 주면 `Renderer::new` 가 시작 시점에 `FontMissing` 으로 실패한다. 번들 폰트의 U+AC00–U+D7A3 cmap 누락이 0 이다
3. **[안전성]** — [rust-engine-architecture](../rust-engine-architecture/SKILL.md) 의 순수성 스크립트(`cargo tree -p og-core -e normal --target all --all-features --prefix none` 결과를 변수에 담아 tokio·axum·reqwest 등을 grep)가 og-core 에서 exit 0 이고, deny-all resolver 로 로컬 절대 경로 `<image>` 가 제거됨을 테스트로 확인했다. 슬롯 수·timeout 값은 부하 테스트(`/sre:load-testing`)로 정했다
4. **[일관성]** — rust-idioms lint 템플릿(`unreachable_pub` 포함 → `tests/common` helper 는 `pub(crate)`)에서 `cargo clippy --workspace --all-targets -- -D warnings` 통과. [Rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 house rule(`too_many_lines` + threshold 100, `unwrap_used = "warn"` + `allow-unwrap-in-tests`, 불변식만 `expect`)을 지킨다. helper fn(`tests/common` 등)에서는 `unwrap()` 대신 `expect("…")` 를 쓴다 — `allow-unwrap-in-tests` 의 적용 범위는 clippy 버전과 workspace 배치에 따라 다르다 ([rust-idioms](../rust-idioms/SKILL.md))

## 참조 스킬

- [rust-engine-architecture](../rust-engine-architecture/SKILL.md) — og-core / og-server workspace, 순수성 CI. 그 skill 의 `render(spec, assets)` 는 여기서 assets(폰트)를 쥔 `Renderer` + `render_png(title, theme)` 이다 · [rust-async-tokio](../rust-async-tokio/SKILL.md) — `spawn_blocking` + CPU Semaphore 기본, 측정 후 `on_rayon`, permit 위치, `shutdown_timeout`, 컨테이너 CPU 수 · [rust-error-handling](../rust-error-handling/SKILL.md) — `IntoResponse` 한 곳, 500 고정 문구, `AppJson` rejection · [rust-testing](../rust-testing/SKILL.md) — 테스트 배치·이름, insta 운영 · [rust-idioms](../rust-idioms/SKILL.md) — Composed Method, newtype(`CleanText`), lint 템플릿
- `/security:owasp-top10` — SSRF 일반론 (그 skill 은 2021 판 기준 A10. 2025 판에서는 A01 Broken Access Control 에 통합) · `/sre:load-testing` — 슬롯 수·timeout 을 정하는 부하 테스트 · `/dx:negative-path-coverage` — 실패 경로 fixture 점검

## Sources / Verified

출처·인용·상태의 전문과 로컬 실측(scratch workspace) 기록은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. 다음 재검증은 2027-02. `allow-unwrap-in-tests` 의 clippy 1.96·1.100 동작과 그 출처는 [rust-idioms](../rust-idioms/SKILL.md) 에 있다.
- [resvg CHANGELOG](https://raw.githubusercontent.com/linebender/resvg/main/CHANGELOG.md) · [crates.io resvg](https://crates.io/api/v1/crates/resvg) · [usvg 0.50.0 features](https://crates.io/api/v1/crates/usvg/0.50.0) · [usvg Options](https://docs.rs/usvg/0.50.0/usvg/struct.Options.html) · [resvg::render](https://docs.rs/resvg/latest/resvg/fn.render.html) · [tiny-skia pixmap.rs](https://raw.githubusercontent.com/linebender/tiny-skia/main/src/pixmap.rs) · [ImageHrefResolver](https://docs.rs/usvg/0.50.0/usvg/struct.ImageHrefResolver.html) · [custom_href_resolver 예제](https://raw.githubusercontent.com/linebender/resvg/main/crates/resvg/examples/custom_href_resolver.rs) · [resvg image.rs](https://raw.githubusercontent.com/linebender/resvg/main/crates/resvg/src/image.rs) · [XML 1.0 (Char)](https://www.w3.org/TR/xml/) · [quick-xml escape](https://docs.rs/quick-xml/latest/quick_xml/escape/fn.escape.html) · [UAX #14](https://www.unicode.org/reports/tr14/) · [UAX #15](https://www.unicode.org/reports/tr15/) · [unicode-normalization](https://docs.rs/unicode-normalization/0.1.26/unicode_normalization/trait.UnicodeNormalization.html) · [unicode-segmentation](https://docs.rs/unicode-segmentation/1.13.3/unicode_segmentation/trait.UnicodeSegmentation.html) · [String::leak](https://doc.rust-lang.org/std/string/struct.String.html#method.leak) · [Pretendard LICENSE](https://raw.githubusercontent.com/orioncactus/pretendard/main/LICENSE) · [Noto CJK LICENSE](https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE) · [noto-cjk Korean OTF](https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/Korean) · [tokio spawn_blocking](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html) · [rayon::spawn 1.12.0](https://docs.rs/rayon/1.12.0/rayon/fn.spawn.html) (반환 `()`, 취소 핸들 없음) · [Runtime Builder](https://docs.rs/tokio/latest/tokio/runtime/struct.Builder.html) · [std available_parallelism](https://doc.rust-lang.org/std/thread/fn.available_parallelism.html) · [axum middleware (axum-v0.8.9)](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/axum/src/docs/middleware.md) · [tower ConcurrencyLimit](https://raw.githubusercontent.com/tower-rs/tower/tower-0.5.3/tower/src/limit/concurrency/service.rs) · [ConcurrencyLimit future.rs](https://raw.githubusercontent.com/tower-rs/tower/tower-0.5.3/tower/src/limit/concurrency/future.rs) · [tower load_shed](https://raw.githubusercontent.com/tower-rs/tower/tower-0.5.3/tower/src/load_shed/mod.rs) · [TimeoutLayer](https://docs.rs/tower-http/latest/tower_http/timeout/struct.TimeoutLayer.html) · [DefaultBodyLimit](https://docs.rs/axum/latest/axum/extract/struct.DefaultBodyLimit.html) — 검증일 2026-11-15 · ✅ verified (`default_data_resolver` 는 JPEG·PNG·GIF·WebP·SVG·SVGZ 를 받는다) + 로컬 실측(`Group::bounding_box` → `Option`, `png` 직접 의존 — png 0.17 로 두면 tiny-skia 0.12 의 png 0.18 과 갈려 `?` 가 E0277, 빈 fontdb 면 텍스트 bbox 없음, `max_depth`·순환 참조 거부는 0.50.0 항목 #1223·#1225·#1218; 기본 resolver 는 절대 경로 이미지를 렌더, deny-all 은 노드 제거, PNG·JPEG 만 받는 resolver 는 SVG data URL 노드를 버림, sbix 이모지 픽셀 0 → 3,341; U+FFFE 가 usvg 파싱 실패, NFD → NFC, ZWJ grapheme; NotoSansCJKkr-Bold.otf family "Noto Sans CJK KR", 음절 누락 0, 16,997,996 bytes) + 로컬 테스트(400·413·503·200, LoadShed+ConcurrencyLimit 아래에서 timeout 뒤 두 번째 렌더 시작, 클로저 안 permit 은 timeout 뒤에도 유지) / ⚠️ Pretendard 커버리지는 검사 안 함; 렌더 시간·메모리, 슬롯 수·timeout 값은 측정 안 함 · subagent, Claude
- [usvg text/layout.rs (v0.50.0)](https://raw.githubusercontent.com/linebender/resvg/v0.50.0/crates/usvg/src/text/layout.rs) · [usvg text/mod.rs (v0.50.0)](https://raw.githubusercontent.com/linebender/resvg/v0.50.0/crates/usvg/src/text/mod.rs) · [fontdb Database](https://docs.rs/fontdb/0.24.0/fontdb/struct.Database.html) · [fontdb 0.24.0 ttf_parser/mod.rs](https://docs.rs/crate/fontdb/0.24.0/source/src/ttf_parser/mod.rs) · [OWASP Top 10 2025 A01](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/) · [OWASP Top 10 2025](https://owasp.org/Top10/2025/) — 검증일 2026-11-15 · ✅ verified (텍스트 bbox 는 "font metrics and not glyph shape", `load_font_data` 는 `Vec` 을 `Arc` 로 감싼다, magic 이 `0x00010000`·`true`·`OTTO`·`ttcf` 가 아니면 `RawFace::parse` 가 `UnknownMagic` 을 돌려줘(`lib.rs` 가 `LoadError::MalformedFont` 로 바꿔 face 를 건너뛴다) woff·woff2 는 읽지 않는다 — 로컬 registry 소스와 `wOF2` 바이트 0 face 테스트, `Source::Binary(Arc::new(&'static [u8]))`(복사 없음) 는 로컬 컴파일·렌더; OWASP A01 매핑에 CWE-918 SSRF 포함, A10:2025 는 Mishandling of Exceptional Conditions) · Claude
- [resvg unsupported](https://raw.githubusercontent.com/linebender/resvg/main/docs/unsupported.md) · [svg2-changelog](https://raw.githubusercontent.com/linebender/resvg/main/docs/svg2-changelog.md) · [rustybuzz README](https://raw.githubusercontent.com/harfbuzz/rustybuzz/main/README.md) · [fontdb README](https://raw.githubusercontent.com/RazrFalcon/fontdb/master/README.md) · [usvg options.rs](https://raw.githubusercontent.com/linebender/resvg/main/crates/usvg/src/parser/options.rs) · [cosmic-text shape.rs](https://raw.githubusercontent.com/pop-os/cosmic-text/main/src/shape.rs) · [cosmic-text 0.19.0 dependencies](https://crates.io/api/v1/crates/cosmic-text/0.19.0/dependencies) · [satori README](https://raw.githubusercontent.com/vercel/satori/main/README.md) · [crates_io_og_image lib.rs](https://raw.githubusercontent.com/rust-lang/crates_io_og_image/main/src/lib.rs) · [takumi](https://docs.rs/takumi/latest/takumi/) · [ogp.me](https://ogp.me/) · [Meta sharing images](https://developers.facebook.com/docs/sharing/webmasters/images/) · [image WebPEncoder](https://docs.rs/image/latest/image/codecs/webp/struct.WebPEncoder.html) · [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.txt) · [RFC 8246](https://www.rfc-editor.org/rfc/rfc8246.txt) · [Vercel OG 블로그](https://vercel.com/blog/introducing-vercel-og-image-generation-fast-dynamic-social-card-images) · [Vercel OG API](https://vercel.com/docs/og-image-generation/og-image-api) · [카카오 DevTalk — og 캐시](https://devtalk.kakao.com/t/og/148829) · [카카오 DevTalk — 스크랩 체크리스트](https://devtalk.kakao.com/t/scrap-url/116202) · [insta assert_binary_snapshot!](https://docs.rs/insta/latest/insta/macro.assert_binary_snapshot.html) · [image-compare](https://docs.rs/image-compare/0.5.0/image_compare/fn.rgba_hybrid_compare.html) · [crates.io dssim-core](https://crates.io/api/v1/crates/dssim-core) — 검증일 2026-11-15 · ✅ verified (음절 분할은 research 로컬 실측, crates_io_og_image 의존성은 정정값; 카카오는 운영진 포럼 답변, 공식 문서 아님) / ⚠️ takumi 의 keep-all 지원과 feature 이름은 문서에서 확인 못 함; X(Twitter) `summary_large_image` 요구사항, Slack·LinkedIn 의 WebP 지원은 unverified (X 문서 402/404, 크롤러는 실제 공유로 확인해야 함) · subagent
