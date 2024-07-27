import gleam/http
import decode.{type Decoder}
import gleam/dynamic
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/json
import gleam/result
import gleam/dict
import gleam/option.{type Option}

// TODO: Find a better way of testing this...
// const v1 = "https://headless.tebex.io/api/accounts/"
const v1 = "http://localhost:8080/api/accounts/"

pub type TebexAPIError {
  NotFound
  MethodNotAllowed
  NoAuth
  BadRequest(body: Response(String))
  UnknownError(status_code: Int, body: Response(String))
  ParseFail
}

pub type TebexAPIResponse(t) =
  Result(t, TebexAPIError)

fn check_status(response: Response(String)) -> TebexAPIResponse(Nil) {
  let status = response.status
  case Nil {
    _ if status >= 200 && status < 300 -> {
      Ok(Nil)
    }

    _ if status == 400 -> Error(BadRequest(body: response))
    _ if status == 401 -> Error(NoAuth)
    _ if status == 404 -> Error(NotFound)
    _ if status == 405 -> Error(MethodNotAllowed)

    _ -> Error(UnknownError(status_code: status, body: response))
  }
}

fn decode_response(
  response: Response(String),
  decoder: decode.Decoder(t),
) -> TebexAPIResponse(t) {
  case
    json.decode(response.body, fn(data: dynamic.Dynamic) -> Result(
      t,
      List(dynamic.DecodeError),
    ) {
      decode.from(decoder, data)
    })
  {
    Ok(json) -> Ok(json)
    Error(_) -> {
      Error(ParseFail)
    }
  }
}

pub type Webstore {
  Webstore(
    id: Int,
    description: String,
    name: String,
    webstore_url: String,
    currency: String,
    lang: String,
    logo: Option(String),
    platform_type: String,
    platform_type_id: String,
    created_at: String,
  )
}

pub fn webstore_decoder() -> decode.Decoder(Webstore) {
  decode.into({
    use id <- decode.parameter
    use description <- decode.parameter
    use name <- decode.parameter
    use webstore_url <- decode.parameter
    use currency <- decode.parameter
    use lang <- decode.parameter
    use logo <- decode.parameter
    use platform_type <- decode.parameter
    use platform_type_id <- decode.parameter
    use created_at <- decode.parameter

    Webstore(
      id,
      description,
      name,
      webstore_url,
      currency,
      lang,
      logo,
      platform_type,
      platform_type_id,
      created_at,
    )
  })
  |> decode.subfield(["data", "id"], decode.int)
  |> decode.subfield(["data", "description"], decode.string)
  |> decode.subfield(["data", "name"], decode.string)
  |> decode.subfield(["data", "webstore_url"], decode.string)
  |> decode.subfield(["data", "currency"], decode.string)
  |> decode.subfield(["data", "lang"], decode.string)
  |> decode.subfield(["data", "logo"], decode.optional(decode.string))
  |> decode.subfield(["data", "platform_type"], decode.string)
  |> decode.subfield(["data", "platform_type_id"], decode.string)
  |> decode.subfield(["data", "created_at"], decode.string)
}

pub type CMSPage {
  CMSPage(
    id: Int,
    created_at: String,
    updated_at: String,
    account_id: Int,
    title: String,
    slug: String,
    private: Bool,
    hidden: Bool,
    disabled: Bool,
    sequence: Bool,
    content: String,
  )
}

type Pages {
  Pages(data: List(CMSPage))
}

fn pages_decoder() -> Decoder(Pages) {
  let page_decoder: Decoder(CMSPage) =
    decode.into({
      use id <- decode.parameter
      use created_at <- decode.parameter
      use updated_at <- decode.parameter
      use account_id <- decode.parameter
      use title <- decode.parameter
      use slug <- decode.parameter
      use private <- decode.parameter
      use hidden <- decode.parameter
      use disabled <- decode.parameter
      use sequence <- decode.parameter
      use content <- decode.parameter

      CMSPage(
        id,
        created_at,
        updated_at,
        account_id,
        title,
        slug,
        private,
        hidden,
        disabled,
        sequence,
        content,
      )
    })
    |> decode.field("id", decode.int)
    |> decode.field("created_at", decode.string)
    |> decode.field("updated_at", decode.string)
    |> decode.field("account_id", decode.int)
    |> decode.field("title", decode.string)
    |> decode.field("slug", decode.string)
    |> decode.field("private", decode.bool)
    |> decode.field("hidden", decode.bool)
    |> decode.field("disabled", decode.bool)
    |> decode.field("sequence", decode.bool)
    |> decode.field("content", decode.string)

  decode.into({
    use data <- decode.parameter

    Pages(data)
  })
  |> decode.field("data", decode.list(page_decoder))
}

pub type Coupon {

}

pub type GiftCard {

}

pub type BasketPackage {
  BasketPackage(
    qty: Int,
    type_: String,
  )
}

pub type Basket {
  Basket(
    id: String,
    ident: String,
    complete: Bool,
    email: Option(String),
    username: Option(String),
    coupons: List(Coupon),
    giftcards: List(GiftCard),
    creator_code: String,
    cancel_url: String,
    complete_url: Option(String),
    complete_auto_redirect: Bool,
    country: String,
    ip: String,
    username_id: Int,
    base_price: Float,
    sales_tax: Float,
    total_price: Float,
    /// 3 character currency code (eg. AUD)
    currency: String,
    packages: List(BasketPackage),
    custom: dict.Dict(String, dynamic.Dynamic),
    links: String, // Get actual type here
  )
}

pub fn get_webstore(account_id: String) -> TebexAPIResponse(Webstore) {
  let assert Ok(req) = request.to(v1 <> account_id)
  let assert Ok(response) = httpc.send(req)
  use _ <- result.try(check_status(response))

  decode_response(response, webstore_decoder())
}

pub fn get_pages(account_id: String) -> TebexAPIResponse(List(CMSPage)) {
  let req = request.new()
  |> request.set_path(v1 <> account_id <> "/pages")
  |> request.set_method(http.Post)

  let assert Ok(response) = httpc.send(req)
  use _ <- result.try(check_status(response))

  case decode_response(response, pages_decoder()) {
    Ok(d) -> Ok(d.data)
    Error(e) -> Error(e)
  }
}
