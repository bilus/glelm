import gap
import gap/styled_comparison.{type StyledComparison}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import glelm/elm/parser
import glelm/transpile
import simplifile as file

type TestCase {
  TestCase(
    name: String,
    elm: String,
    expected_gleam: Result(String, transpile.Error),
  )
}

pub fn transpile_test() {
  use test_cases <- result.try(load_test_cases())
  test_cases
  |> list.each(run)
  Ok(Nil)
}

fn run(tc: TestCase) -> Nil {
  let elm_ast =
    tc.elm
    |> parser.parse(parser.module())
  case elm_ast {
    Ok(elm_ast) ->
      transpile.module(elm_ast)
      |> transpile.run(transpile.initial_ctx())
      |> result.map(transpile.print)
      |> should_equal(tc.expected_gleam, _, tc.name)
    Error(e) -> {
      io.println("Error in test: " <> tc.name <> " " <> string.inspect(e))
      should.fail()
    }
  }
}

fn load_test_cases() -> Result(List(TestCase), file.FileError) {
  use files <- result.try(file.get_files("./test/transpile"))
  let input_ext = ".elm.input"
  let expected_ext = ".gleam.expected"
  let test_cases =
    files
    |> list.filter(string.ends_with(_, input_ext))
    |> list.map(string.drop_end(_, string.length(input_ext)))
    |> list.map(fn(test_name) {
      use input <- result.try(file.read(test_name <> input_ext))
      use expected_gleam <- result.try(file.read(test_name <> expected_ext))
      Ok(TestCase(test_name, input, Ok(expected_gleam)))
    })
    |> result.all
  should.be_true(list.length(result.unwrap(test_cases, [])) > 0)
  test_cases
}

fn should_equal(
  expected: Result(String, e),
  actual: Result(String, e),
  test_name: String,
) {
  case actual != expected, actual, expected {
    True, Ok(actual), Ok(expected) -> {
      io.println("Test failed: " <> test_name)
      gap.compare_strings(expected, actual)
      |> gap.to_styled
      |> print_diff
      should.equal(actual, expected)
    }
    _, _, _ -> Nil
  }
}

fn print_diff(diff: StyledComparison) {
  io.println("")
  io.println("")
  io.println("-------------- Actual ---------------")
  io.println(diff.second)
  io.println("------------- Expected --------------")
  io.println(diff.first)
  io.println("-------------------------------------")
}
