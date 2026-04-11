test_that("get_api_key returns the anthropic key from golem config", {
  withr::with_envvar(
    c(ANTHROPIC_API_KEY = "test-anthropic-key"),
    {
      key <- get_api_key("anthropic")
      expect_equal(key, "test-anthropic-key")
    }
  )
})

test_that("get_api_key defaults to anthropic provider", {
  withr::with_envvar(
    c(ANTHROPIC_API_KEY = "default-key"),
    {
      key <- get_api_key()
      expect_equal(key, "default-key")
    }
  )
})

test_that("get_api_key returns openai key for openai provider", {
  withr::with_envvar(
    c(OPENAI_API_KEY = "test-openai-key"),
    {
      key <- get_api_key("openai")
      expect_equal(key, "test-openai-key")
    }
  )
})

test_that("get_api_key returns azure key for azure provider", {
  withr::with_envvar(
    c(AZURE_OPENAI_KEY = "test-azure-key"),
    {
      key <- get_api_key("azure")
      expect_equal(key, "test-azure-key")
    }
  )
})
