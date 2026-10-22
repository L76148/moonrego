///|
/// The text printed for `moonrego help`.
let usage : String = "moonrego - a Rego implementation for MoonBit\n\nUsage: moonrego <command> [options]\n\nCommands:\n  eval     evaluate a query against modules, data and input\n  check    parse and type-check Rego modules\n  parse    print the parsed modules\n  version  print the version\n  help     show this message\n\nThe evaluator and the commands arrive in the next increments."

///|
fn main {
  let args = @env.args()
  let command = if args.length() > 1 { args[1] } else { "help" }
  match command {
    "help" | "--help" | "-h" => println(usage)
    "version" | "--version" => println("moonrego " + @rego.version())
    _ => {
      println("error: unknown command '" + command + "'")
      println(usage)
      abort("unknown command")
    }
  }
}
