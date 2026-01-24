# Spring Security Patterns

Spring Security, OAuth2, JWT 인증/인가 패턴

## 설정

### 의존성
```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-security'
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'
    implementation 'io.jsonwebtoken:jjwt-api:0.12.3'
    runtimeOnly 'io.jsonwebtoken:jjwt-impl:0.12.3'
    runtimeOnly 'io.jsonwebtoken:jjwt-jackson:0.12.3'
}
```

---

## JWT 인증

### JWT 유틸리티
```java
@Component
public class JwtProvider {
    @Value("${jwt.secret}")
    private String secretKey;

    @Value("${jwt.access-token-validity}")
    private long accessTokenValidity;  // 15분

    @Value("${jwt.refresh-token-validity}")
    private long refreshTokenValidity;  // 7일

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(secretKey.getBytes(StandardCharsets.UTF_8));
    }

    public String createAccessToken(Long userId, String email, List<String> roles) {
        return Jwts.builder()
            .subject(String.valueOf(userId))
            .claim("email", email)
            .claim("roles", roles)
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + accessTokenValidity))
            .signWith(getSigningKey())
            .compact();
    }

    public String createRefreshToken(Long userId) {
        return Jwts.builder()
            .subject(String.valueOf(userId))
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + refreshTokenValidity))
            .signWith(getSigningKey())
            .compact();
    }

    public Claims parseToken(String token) {
        return Jwts.parser()
            .verifyWith(getSigningKey())
            .build()
            .parseSignedClaims(token)
            .getPayload();
    }

    public boolean validateToken(String token) {
        try {
            parseToken(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }
}
```

### JWT 필터
```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtProvider jwtProvider;
    private final UserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String token = extractToken(request);

        if (token != null && jwtProvider.validateToken(token)) {
            Claims claims = jwtProvider.parseToken(token);
            String userId = claims.getSubject();

            UserDetails userDetails = userDetailsService.loadUserByUsername(userId);
            UsernamePasswordAuthenticationToken auth =
                new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
            auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

            SecurityContextHolder.getContext().setAuthentication(auth);
        }

        chain.doFilter(request, response);
    }

    private String extractToken(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }
}
```

### Security 설정
```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {
    private final JwtAuthenticationFilter jwtFilter;
    private final AuthenticationEntryPoint authEntryPoint;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(ex ->
                ex.authenticationEntryPoint(authEntryPoint))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

---

## OAuth2 Resource Server

### application.yml
```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com
          # 또는 직접 jwk-set-uri 지정
          # jwk-set-uri: https://auth.example.com/.well-known/jwks.json
```

### 설정
```java
@Configuration
@EnableWebSecurity
public class OAuth2ResourceServerConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 ->
                oauth2.jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthConverter()))
            )
            .build();
    }

    // JWT claims를 Spring Security authorities로 변환
    @Bean
    public JwtAuthenticationConverter jwtAuthConverter() {
        JwtGrantedAuthoritiesConverter grantedAuthoritiesConverter = new JwtGrantedAuthoritiesConverter();
        grantedAuthoritiesConverter.setAuthoritiesClaimName("roles");
        grantedAuthoritiesConverter.setAuthorityPrefix("ROLE_");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(grantedAuthoritiesConverter);
        return converter;
    }
}
```

---

## Method Security

### 어노테이션 기반
```java
@Service
@RequiredArgsConstructor
public class UserService {

    // 역할 기반
    @PreAuthorize("hasRole('ADMIN')")
    public void deleteUser(Long id) {
        // 관리자만 삭제 가능
    }

    // 권한 기반
    @PreAuthorize("hasAuthority('USER_WRITE')")
    public User updateUser(Long id, UpdateUserRequest request) {
        // USER_WRITE 권한 필요
    }

    // 복합 조건
    @PreAuthorize("hasRole('ADMIN') or #id == authentication.principal.id")
    public User getUser(Long id) {
        // 관리자이거나 본인만 조회 가능
    }

    // 반환값 필터링
    @PostAuthorize("returnObject.ownerId == authentication.principal.id")
    public Resource getResource(Long id) {
        // 본인 소유 리소스만 반환
    }

    // 컬렉션 필터링
    @PostFilter("filterObject.ownerId == authentication.principal.id")
    public List<Resource> getAllResources() {
        // 본인 소유 리소스만 필터링
    }
}
```

### 커스텀 Security Expression
```java
@Component("authz")
@RequiredArgsConstructor
public class AuthorizationService {
    private final ResourceRepository resourceRepository;

    public boolean isOwner(Long resourceId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        Long userId = ((CustomUserDetails) auth.getPrincipal()).getId();

        return resourceRepository.findById(resourceId)
            .map(r -> r.getOwnerId().equals(userId))
            .orElse(false);
    }

    public boolean canAccess(Long resourceId, String permission) {
        // 복잡한 권한 로직
        return true;
    }
}

// 사용
@PreAuthorize("@authz.isOwner(#resourceId)")
public void updateResource(Long resourceId, UpdateRequest request) { }

@PreAuthorize("@authz.canAccess(#id, 'READ')")
public Resource getResource(Long id) { }
```

---

## 인증 컨트롤러

```java
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
    private final AuthService authService;

    @PostMapping("/signup")
    public ResponseEntity<UserResponse> signup(@Valid @RequestBody SignupRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(authService.signup(request));
    }

    @PostMapping("/login")
    public ResponseEntity<TokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/refresh")
    public ResponseEntity<TokenResponse> refresh(@RequestBody RefreshTokenRequest request) {
        return ResponseEntity.ok(authService.refresh(request.getRefreshToken()));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@AuthenticationPrincipal CustomUserDetails user) {
        authService.logout(user.getId());
        return ResponseEntity.noContent().build();
    }
}

@Service
@RequiredArgsConstructor
public class AuthService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;
    private final RefreshTokenRepository refreshTokenRepository;

    @Transactional
    public TokenResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
            .orElseThrow(() -> new UnauthorizedException("Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new UnauthorizedException("Invalid credentials");
        }

        String accessToken = jwtProvider.createAccessToken(
            user.getId(), user.getEmail(), user.getRoles());
        String refreshToken = jwtProvider.createRefreshToken(user.getId());

        // Refresh Token 저장 (Redis 또는 DB)
        refreshTokenRepository.save(new RefreshToken(user.getId(), refreshToken));

        return new TokenResponse(accessToken, refreshToken);
    }

    @Transactional
    public TokenResponse refresh(String refreshToken) {
        if (!jwtProvider.validateToken(refreshToken)) {
            throw new UnauthorizedException("Invalid refresh token");
        }

        Claims claims = jwtProvider.parseToken(refreshToken);
        Long userId = Long.parseLong(claims.getSubject());

        // 저장된 Refresh Token과 비교
        RefreshToken stored = refreshTokenRepository.findByUserId(userId)
            .orElseThrow(() -> new UnauthorizedException("Refresh token not found"));

        if (!stored.getToken().equals(refreshToken)) {
            throw new UnauthorizedException("Refresh token mismatch");
        }

        User user = userRepository.findById(userId)
            .orElseThrow(() -> new UnauthorizedException("User not found"));

        String newAccessToken = jwtProvider.createAccessToken(
            user.getId(), user.getEmail(), user.getRoles());

        return new TokenResponse(newAccessToken, refreshToken);
    }
}
```

---

## CORS 설정

```java
@Configuration
public class CorsConfig {

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("https://example.com", "http://localhost:3000"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "PATCH"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }
}
```

---

## Common Mistakes

| 실수 | 올바른 방법 |
|------|------------|
| JWT Secret 하드코딩 | 환경변수 또는 Vault 사용 |
| Access Token 만료 너무 긺 | 15분 이하 권장 |
| Refresh Token DB 미저장 | Redis/DB에 저장하여 무효화 가능하게 |
| HTTPS 미사용 | 프로덕션에서 필수 |
| 비밀번호 평문 저장 | BCrypt 해시 필수 |
| 권한 체크 컨트롤러에만 | @PreAuthorize로 서비스에도 적용 |

---

## 체크리스트

- [ ] HTTPS 적용
- [ ] JWT Secret 환경변수화
- [ ] Access Token TTL 15분 이하
- [ ] Refresh Token 저장 및 무효화 로직
- [ ] 비밀번호 BCrypt 해시
- [ ] CORS 적절히 설정
- [ ] Method Security 적용
- [ ] Actuator 엔드포인트 보호
