///|
priv struct Stock(Bool)

///|
impl Availability for Stock with fn available(self) {
  self.0
}

///|
test "不同模块的使用方只导入运行库" {
  @mock_runtime.with_mock(c => {
    let mock = MockCatalog::new(c)
    mock.expect_lookup(@mock_runtime.equal_to(42), Some(("book", 3)))
    assert_eq(Catalog::lookup(mock, 42), Some(("book", 3)))
  })
}

///|
test "调用带默认实现的方法时使用设定的返回值" {
  @mock_runtime.with_mock(c => {
    let mock = MockCatalog::new(c)
    mock.expect_status(
      @mock_runtime.matching("缺货", stock => !stock.available()),
      Stock(true),
    )
    let status = Catalog::status(mock, Stock(false))
    assert_true(status.available())
  })
}

///|
test "标签调用按声明顺序匹配并传给回调" {
  @mock_runtime.with_mock(c => {
    let mock = MockCatalog::new(c)
    mock.respond_search(@mock_runtime.equal_to(("book", 2, 3, 5, 7)), values => {
      let (_, action, arg, receiver, args) = values
      action + arg + receiver + args
    })
    let catalog : &Catalog = mock
    assert_eq(catalog.search("book", args=7, self=5, arg_0=3, action=2), 17)
    mock.expect_page_size(@mock_runtime.equal_to(None), 20)
    mock.expect_page_size(@mock_runtime.equal_to(Some(9)), 9)
    assert_eq(catalog.page_size(), 20)
    assert_eq(catalog.page_size(limit=9), 9)
  })
}

///|
test "同步签名可接收回调并返回可抛错的函数" {
  @mock_runtime.with_mock(c => {
    let mock = MockCatalog::new(c)
    mock.respond_apply(@mock_runtime.any(), args => {
      let (callback, number) = args
      callback(number)
    })
    mock.expect_fetcher(@mock_runtime.any(), fn() -> Int32 raise ReadError {
      raise Offline
    })
    assert_eq(Catalog::apply(mock, n => n * 2, 9), 18)
    let fetch = Catalog::fetcher(mock)
    let result = Ok(fetch()) catch { error => Err(error) }
    assert_true(result is Err(Offline))
  })
}

///|
async test "异步业务回调挂起后向调用者传播类型化错误" {
  @mock_runtime.with_mock_async(async fn(c) {
    let mock = MockCatalog::new(c)
    mock.respond_fetch_with(@mock_runtime.any(), async fn(
      callback,
    ) -> Int32 raise ReadError {
      callback(42)
    })
    let read = async fn(number : Int32) -> Int32 raise ReadError {
      @async.pause()
      if number == 42 {
        raise Offline
      }
      number
    }
    let result = Ok(Catalog::fetch_with(mock, read)) catch {
      error => Err(error)
    }
    assert_true(result is Err(Offline))
  })
}
