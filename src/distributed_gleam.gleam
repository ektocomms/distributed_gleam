import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/node
import gleam/erlang/process
import gleam/io
import gleam/string
import argv
import glint

// This works but uses start/1, which is deprecated
// https://www.erlang.org/doc/apps/kernel/net_kernel.html#start/1
//
//    @external(erlang, "net_kernel", "start")
//    fn net_kernel_start_1(
//      name: List(atom.Atom),
//    ) -> Result(process.Pid, dynamic.Dynamic)

// I was not able to externalize start/2 directly
// because I could not handle the 2nd argument
// which is an Erlang Map.
// I had to create a wrapper to transform
// a Gleam record into an Erlang Map.

type NameDomain {
  // no camel-case to take profit of
  // "auto lowercase" when entering Erlang's realm.
  Shortnames
  Longnames
}

type NetStartOptions {
  NetStartOptions(
    // this will be called net_start_options inside Erlang
    name_domain: NameDomain,
    net_ticktime: Int,
    net_tickintensity: Int,
    dist_listen: Bool,
    hidden: Bool,
  )
}

@external(erlang, "net_kernel_start_wrapper", "net_kernel_start_2")
fn net_kernel_start_2(
  name: String,
  options: NetStartOptions,
) -> Result(process.Pid, dynamic.Dynamic)

@external(erlang, "erlang", "set_cookie")
fn set_cookie(cookie: atom.Atom) -> Bool

type Message {
  Hello(to: String)
}

pub fn main() {
  glint.new()
  |> glint.with_name("Distributed Gleam simple example")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add([], do: from_cli())
  |> glint.run(argv.load().arguments)
}

fn from_cli() -> glint.Command(Nil) {
  use ego_flag <- glint.flag(
    glint.string_flag("ego")
    |> glint.flag_default("joe")
    |> glint.flag_help("name of this node"),
  )

  use illum_flag <- glint.flag(
    glint.string_flag("illum")
    |> glint.flag_default("mike")
    |> glint.flag_help("name of the other node"),
  )

  use _, _, flags <- glint.command()

  let assert Ok(ego) = ego_flag(flags)
  let assert Ok(illum) = illum_flag(flags)

  up(ego, illum)
}

fn up(ego: String, illum: String) {
  let addr = "127.0.0.1"
  let assert Ok(_) = go_distributed(ego, addr)

  // Connect to the other node
  let illum_node = connect(illum <> "@" <> addr)

  // Spawn a listener named process than can be
  // reached by the other node
  let listener_name = spawn_named_listener()

  // Now we can send something to the other "listener":
  speaker_loop(illum_node, listener_name, Hello(illum))
}

fn go_distributed(ego: String, addr: String) {
  //  let net_kernel_start_1_options = [
  //    // Choose short ot long names:
  //    // atom.create_from_string(ego),
  //    // atom.create_from_string("shortnames"),
  //    atom.create_from_string(ego <> "@" <> addr),
  //    atom.create_from_string("longnames"),
  //    ]

  let net_kernel_start_2_options =
    NetStartOptions(
      name_domain: Longnames,
      // ShortNames,
      net_ticktime: 60,
      net_tickintensity: 4,
      dist_listen: True,
      hidden: False,
    )

  //   net_kernel_start_1(net_kernel_start_1_options)
  case net_kernel_start_2(ego <> "@" <> addr, net_kernel_start_2_options) {
    Ok(pid) -> {
      io.println("Network Kernel started with PID: " <> string.inspect(pid))
      set_cookie(atom.create_from_string("secret_cookie"))
      Ok(pid)
    }
    Error(e) -> {
      io.println("Network Kernel failed to start: " <> string.inspect(e))
      Error(e)
    }
  }
}

fn connect(to: String) -> node.Node {
  io.println("Trying to connect to: " <> to)
  case node.connect(atom.create_from_string(to)) {
    Ok(n) -> {
      io.println("Connected to: " <> to)
      n
    }
    Error(_) -> {
      process.sleep(100)
      connect(to)
    }
  }
}

fn spawn_named_listener() -> atom.Atom {
  let listener_name = atom.create_from_string("listener")
  let _ =
    process.start(
      fn() {
        let _ = process.register(process.self(), listener_name)
        listener_loop()
      },
      True,
    )
  listener_name
}

fn listener_loop() {
  case
    process.select_forever(process.selecting_anything(
      process.new_selector(),
      decode_message,
    ))
  {
    Ok(msg) ->
      case msg {
        Hello(to) -> io.println("Received Hello: " <> to)
      }
    Error(e) -> io.println("Error decoding: " <> string.inspect(e))
  }
  listener_loop()
}

fn speaker_loop(node: node.Node, name: atom.Atom, msg: Message) {
  node.send(node, name, msg)
  process.sleep(1000)
  speaker_loop(node, name, msg)
}

fn atom_decoder() -> decode.Decoder(atom.Atom) {
  use data <- decode.new_primitive_decoder("Atom")
  case atom.from_dynamic(data) {
    Ok(a) -> Ok(a)
    Error(_) -> Error(atom.create_from_string("null"))
  }
}

fn decode_message(
  data: dynamic.Dynamic,
) -> Result(Message, List(decode.DecodeError)) {
  // Erlang sends Gleam Records as Tuples
  // The first element is an atom with the name of the constructor
  let decoder = {
    use constructor <- decode.field(0, atom_decoder())
    use to <- decode.field(1, decode.string)
    let constructor_string = atom.to_string(constructor)
    case constructor_string {
      "hello" -> decode.success(Hello(to))
      x -> decode.failure(Hello(""), x)
    }
  }
  decode.run(data, decoder)
}
