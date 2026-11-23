///|
async test "无效策略在任何依赖调用之前拒绝" {
  for
    policy in [
      {
        ttl_seconds: 0,
        fallback_on_read_error: true,
        write_required: false,
        max_payload_chars: 3,
      },
      {
        ttl_seconds: -1,
        fallback_on_read_error: true,
        write_required: false,
        max_payload_chars: 3,
      },
      {
        ttl_seconds: 86401,
        fallback_on_read_error: true,
        write_required: false,
        max_payload_chars: 3,
      },
      {
        ttl_seconds: 60,
        fallback_on_read_error: true,
        write_required: false,
        max_payload_chars: -1,
      },
      {
        ttl_seconds: 60,
        fallback_on_read_error: true,
        write_required: false,
        max_payload_chars: 1048577,
      },
    ] {
    @mock_runtime.with_mock_history_async(8, async fn(c) {
      let cache = MockCacheStore::new(c)
      let origin = MockOrigin::new(c)
      let result = Ok(load(cache, origin, "key", policy)) catch {
        error => Err(error)
      }
      assert_true(result is Err(InvalidConfig(_)))
      assert_eq(c.history().length(), 0)
    })
  }
}

///|
async test "空键和空白键不会触发缓存调用" {
  for key in ["", " ", "\t\n"] {
    @mock_runtime.with_mock_async(async fn(c) {
      let result = Ok(
        load(MockCacheStore::new(c), MockOrigin::new(c), key, cache_policy()),
      ) catch {
        error => Err(error)
      }
      assert_true(result is Err(InvalidConfig(_)))
    })
  }
}

///|
async test "Unicode标量长度边界对缓存命中和回源一致" {
  for cached in [false, true] {
    for
      (value, limit, allowed) in [
        ("🚲书", 2, true),
        ("🚲书", 1, false),
        ("", 0, true),
        ("a", 0, false),
      ] {
      @mock_runtime.with_mock_async(async fn(c) {
        let cache = MockCacheStore::new(c)
        let origin = MockOrigin::new(c)
        cache.expect_get(
          @mock_runtime.any(),
          if cached {
            Some(value)
          } else {
            None
          },
        )
        if !cached {
          origin.expect_fetch(@mock_runtime.any(), value)
          if allowed {
            cache.expect_put(@mock_runtime.equal_to(("键🚲", value, 1)), ())
          }
        }
        let policy = {
          ttl_seconds: 1,
          fallback_on_read_error: true,
          write_required: false,
          max_payload_chars: limit,
        }
        let result = Ok(load(cache, origin, "键🚲", policy)) catch {
          error => Err(error)
        }
        if allowed {
          guard result is Ok(loaded) else { fail("长度边界内应成功") }
          assert_eq(loaded.value, value)
        } else {
          assert_true(result is Err(PayloadTooLarge))
        }
      })
    }
  }
}

///|
async test "TTL边界原样转发，不在工具内部推算时间" {
  for ttl in [1, 86400] {
    @mock_runtime.with_mock_async(async fn(c) {
      let cache = MockCacheStore::new(c)
      let origin = MockOrigin::new(c)
      cache.expect_get(@mock_runtime.any(), None)
      origin.expect_fetch(@mock_runtime.any(), "value")
      cache.expect_put(@mock_runtime.equal_to(("key", "value", ttl)), ())
      let policy = {
        ttl_seconds: ttl,
        fallback_on_read_error: false,
        write_required: true,
        max_payload_chars: 5,
      }
      let result = load(cache, origin, "key", policy)
      assert_eq(result.value, "value")
    })
  }
}

///|
async test "读失败后上游错误仍为上游原错误" {
  @mock_runtime.with_mock_async(async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.raise_get(@mock_runtime.any(), ReadUnavailable)
    origin.raise_fetch(@mock_runtime.any(), OriginUnavailable)
    cache.expect_put(@mock_runtime.any(), (), times=0)
    let result = Ok(load(cache, origin, "key", cache_policy())) catch {
      error => Err(error)
    }
    assert_true(result is Err(OriginUnavailable))
  })
}

///|
async test "有限历史能解释回源调用而不存储内容" {
  @mock_runtime.with_mock_history_async(2, async fn(c) {
    let cache = MockCacheStore::new(c)
    let origin = MockOrigin::new(c)
    cache.expect_get(@mock_runtime.any(), None)
    origin.expect_fetch(@mock_runtime.any(), "private-value")
    cache.expect_put(@mock_runtime.any(), ())
    let result = load(cache, origin, "private-key", cache_policy())
    assert_eq(result.value, "private-value")
    let history = c.history()
    assert_eq(history.length(), 2)
    assert_eq(history[0].method_name, "Origin.fetch")
    assert_eq(history[1].method_name, "CacheStore.put")
    assert_eq(c.history_dropped(), 1L)
    assert_false(c.history_report().stringify().contains("private-"))
  })
}
