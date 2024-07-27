import gleeunit
//import startest
import startest/expect
import tebex_sdk


pub fn main() {
//  startest.run(startest.default_config())
  gleeunit.main()
}

pub fn webstore_test() {
  let webstore = tebex_sdk.get_webstore("1234")

  webstore
  |> expect.to_be_ok()

  let assert Ok(w) = webstore

  w.name
  |> expect.to_equal("Minecraft Store")
}

pub fn page_test() {
  let pages = tebex_sdk.get_pages("1234")

  pages
  |> expect.to_be_ok()
}
