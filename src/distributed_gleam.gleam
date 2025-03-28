import argv
import gleam/erlang/process
import gleam/erlang/node
import gleam/io
import gleam/list
import gleam/string
import gleam/dynamic
import gleam/erlang/atom
import glint

// This works but uses start/1, which is deprecated
// https://www.erlang.org/doc/apps/kernel/net_kernel.html#start/1
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
  NetStartOptions( // this will be called net_start_options inside Erlang
      name_domain: NameDomain,
      net_ticktime: Int,
      net_tickintensity: Int,
      dist_listen: Bool,
      hidden: Bool)
}

@external(erlang, "net_kernel_start_wrapper", "net_kernel_start_2")
fn net_kernel_start_2(name: String,
                      options: NetStartOptions)
    -> Result(process.Pid, dynamic.Dynamic)


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
  go_distributed(ego, illum)
  process.sleep(100)
}

fn go_distributed(ego: String, _illum: String) {
  let addr = "127.0.0.1"

  //  let _net_kernel_start_1_options = [
  //    // Choose short ot long names:
  //    // atom.create_from_string(ego),
  //    // atom.create_from_string("shortnames"),
  //    atom.create_from_string(ego <> "@" <> addr),
  //    atom.create_from_string("longnames"),
  //    ]

  let net_kernel_start_2_options = NetStartOptions(
    name_domain: Longnames, // ShortNames,
    net_ticktime: 60,
    net_tickintensity: 4,
    dist_listen: True,
    hidden: False)

  // let result = net_kernel_start_1(net_kernel_start_1_options)
  let result = net_kernel_start_2(ego <> "@" <> addr,
                                  net_kernel_start_2_options)

  case result {
    Ok(pid) -> io.println("Network Kernel started with PID: " <> string.inspect(pid))
    Error(e) -> io.println("Network Kernel failed to start: " <> string.inspect(e))
  }
  echo atom.to_string(node.to_atom(node.self()))
  echo list.map(node.visible(), fn (n) {atom.to_string(node.to_atom(n))})
}
