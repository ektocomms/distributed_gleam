# Distributed Gleam Simple Example

## Context

We approached [Gleam](https://gleam.run) expecting a modern, friendly way
of writing concurrent and distributed systems for the
[Erlang runtime](https://en.wikipedia.org/wiki/BEAM_(Erlang_virtual_machine)).

As of April 2025, I found no example of how to communicate
two BEAM instances using Gleam that is both simple and up to date.

The goal of this repository is to reflect my attempt at it
and allow others to give feedback.

I had no prior experience with Gleam or Erlang.

## What I tried to achieve

* [x] All logic must be inside Gleam: no external parameters to `erl`.
    * Reason: not exposing users to such details.
* [x] Just connect, send and receive messages.
* [x] Messages must be of the same types one would use between
      two internal processes.

## Remarks

* The connection can be stablished with `net_kernel:start/1` which can be
externalized directly, but is deprecated in favor of `/2`.
  * `net_kernel:start/2` required an [Erlang wrapper](src/net_kernel_start_wrapper.erl)
     to convert Erlang Maps into Gleam Records, which took me a lot of time
     to get "right" (if I may say).
* I had to `systemctl start epmd.service`.
  * I would like to learn how not to depend on it [maybe this](https://blog.erlware.org/epmdlessless/). 
* Gleam `process.Subject` can't be used from other instances (as far as I know).
  * Processes can only send messages to **named** processes of the other instance.
  * The receiving process will receive a `dynamic.Dynamic` value that
    I had to "manually" decode. This took me a lot of time to get "right".
    * Gleam Records will arrive as a Tuple of an Atom (with the constructor's name)
      and the values of the fields.
      * I ignore if this imposes any limitation.

## How to use this repo

* Install `gleam` and `erlang`.
* `systemctl start epmd.service`.
* Open two terminals and run one on each:
  * `$ gleam run -- --ego=mike --illum=joe`
  * `$ gleam run -- --ego=joe  --illum=mike`

Exit with double `CTRL+C`.

## References

* [erlang net_kernel docs](https://www.erlang.org/doc/apps/kernel/net_kernel.html)
* [gleam-distribution-demo](https://github.com/wmealing/gleam-distribution-demo)
* [Learn OTP with Gleam](https://github.com/bcpeinhardt/learn_otp_with_gleam)
* [Gleam coming from Erlang](https://olano.dev/blog/gleam-coming-from-erlang)
* [gleam/erlang docs](https://hexdocs.pm/gleam_erlang/0.34.0/index.html)
* [Gleam's Discord](https://discord.gg/Fm8Pwmy): people are very helpful (specially Gleam's author).
* [gleam/dynamic/decode docs](https://hexdocs.pm/gleam_stdlib/gleam/dynamic/decode.html)
