-module(net_kernel_start_wrapper).
-export([net_kernel_start_2/2]).

net_kernel_start_2(Name, Options)
    when is_binary(Name), % Gleam String, actually
         is_tuple(Options) % Gleam Record, actually
         ->
    case Options of
        {net_start_options, % lower case Gleam Record name
            NameDomain,
            NetTickTime,
            NetTickIntensity,
            DistListen,
            Hidden
        } -> net_kernel:start(list_to_atom(binary_to_list(Name)),
                #{
                    name_domain => NameDomain,
                    net_ticktime => NetTickTime,
                    net_tickintensity => NetTickIntensity,
                    dist_listen => DistListen,
                    hidden => Hidden
                 });
        _ -> {error, {invalid_record_format}, Options}
    end.
