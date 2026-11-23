///|
fn cache_policy() -> CachePolicy {
  {
    ttl_seconds: 60,
    fallback_on_read_error: true,
    write_required: false,
    max_payload_chars: 1024,
  }
}

///|
async test "缓存命中不访问上游也不回写" {
  @mock_runtime.with_mock_history_async(8, async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.expect_get(@matchers.starts_with("user:"), Some("cached"))
    origin.expect_fetch(@mock_runtime.any(), "unexpected", times=0)
    cache.expect_put(@mock_runtime.any(), (), times=0)
    let result = load(cache, origin, "user:1", cache_policy())
    assert_eq(result.value, "cached")
    assert_true(result.source is CacheHit)
    assert_eq(result.warnings.length(), 0)
    assert_eq(c.history().length(), 1)
  })
}

///|
async test "缓存缺失按顺序回源并传递TTL" {
  @mock_runtime.with_mock_history_async(8, async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    let order = @mock_runtime.Sequence::new()
    cache.expect_get(@mock_runtime.equal_to("user:1"), None, sequence=order)
    origin.respond_fetch(
      @mock_runtime.equal_to("user:1"),
      async fn(key) -> String raise CacheError {
        @async.pause()
        if key != "user:1" {
          raise OriginUnavailable
        }
        "fresh"
      },
      sequence=order,
    )
    cache.expect_put(
      @mock_runtime.equal_to(("user:1", "fresh", 60)),
      (),
      sequence=order,
    )
    let result = load(cache, origin, "user:1", cache_policy())
    assert_eq(result.value, "fresh")
    assert_true(result.source is OriginFetch)
    assert_eq(result.warnings.length(), 0)
    assert_eq(c.history().length(), 3)
  })
}

///|
async test "读缓存故障降级成功仍保留故障说明" {
  @mock_runtime.with_mock_async(async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.raise_get(@mock_runtime.any(), ReadUnavailable)
    origin.expect_fetch(@mock_runtime.any(), "fresh")
    cache.expect_put(@mock_runtime.any(), ())
    let result = load(cache, origin, "user:2", cache_policy())
    assert_eq(result.value, "fresh")
    assert_eq(result.warnings.length(), 1)
    assert_eq(result.warnings[0].phase, "read")
    assert_true(result.warnings[0].cause is ReadUnavailable)
  })
}

///|
async test "关闭读降级后缓存错误直接传播" {
  @mock_runtime.with_mock_async(async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.raise_get(@mock_runtime.any(), ReadUnavailable)
    origin.expect_fetch(@mock_runtime.any(), "unexpected", times=0)
    cache.expect_put(@mock_runtime.any(), (), times=0)
    let policy = {
      ttl_seconds: 60,
      fallback_on_read_error: false,
      write_required: false,
      max_payload_chars: 1024,
    }
    let result = Ok(load(cache, origin, "key", policy)) catch {
      error => Err(error)
    }
    assert_true(result is Err(ReadUnavailable))
  })
}

///|
async test "读和回写都故障时成功数据保留两项警告" {
  @mock_runtime.with_mock_async(async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.raise_get(@mock_runtime.any(), ReadUnavailable)
    origin.expect_fetch(@mock_runtime.any(), "fresh")
    cache.raise_put(@mock_runtime.any(), WriteUnavailable)
    let result = load(cache, origin, "key", cache_policy())
    assert_eq(result.value, "fresh")
    assert_eq(result.warnings.length(), 2)
    assert_eq(result.warnings[0].phase, "read")
    assert_eq(result.warnings[1].phase, "write")
    assert_true(result.warnings[1].cause is WriteUnavailable)
  })
}

///|
async test "要求回写成功时写故障直接传播" {
  @mock_runtime.with_mock_async(async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.expect_get(@mock_runtime.any(), None)
    origin.expect_fetch(@mock_runtime.any(), "fresh")
    cache.raise_put(@mock_runtime.any(), WriteUnavailable)
    let policy = {
      ttl_seconds: 60,
      fallback_on_read_error: true,
      write_required: true,
      max_payload_chars: 1024,
    }
    let result = Ok(load(cache, origin, "key", policy)) catch {
      error => Err(error)
    }
    assert_true(result is Err(WriteUnavailable))
  })
}

///|
async test "上游失败从不向缓存写入伪造数据" {
  @mock_runtime.with_mock_async(async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.expect_get(@mock_runtime.any(), None)
    origin.raise_fetch(@mock_runtime.any(), OriginUnavailable)
    cache.expect_put(@mock_runtime.any(), (), times=0)
    let result = Ok(load(cache, origin, "key", cache_policy())) catch {
      error => Err(error)
    }
    assert_true(result is Err(OriginUnavailable))
  })
}
