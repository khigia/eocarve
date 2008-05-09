open Ocamerl
open Seamcarving

let create_worker_process node bin =
    let fn = Tmpfile.new_tmp_file_name "oecarv" in
    let oc = open_out_bin fn in
    Array.iter (output_char oc) bin;
    flush oc;
    close_out oc;

    let mbox = Enode.create_mbox node in
    let recvCB = fun msg -> match msg with
    | msg ->
        (* skip unknown message *)
        Trace.dbg "Ex_carv" "Worker skiping unknown message: %s\n" (Eterm.to_string msg);
        ()
    in
    Enode.Mbox.create_activity mbox recvCB;
    Enode.Mbox.pid mbox

let create_main_process node name =
    let mbox = Enode.create_mbox node in
    let _ = Enode.register_mbox node mbox name in
    let recvCB = fun msg -> match msg with
    | Eterm.ET_tuple [|pid; Eterm.ET_ref r; Eterm.ET_bin b;|] ->
        let worker = create_worker_process node b in
        Enode.send node pid (Eterm.ET_tuple [|Eterm.ET_ref r; worker;|])
    | msg ->
        (* skip unknown message *)
        Trace.dbg "Ex_carv" "Skip unknown message: %s\n" (Eterm.to_string msg);
    in
    Enode.Mbox.create_activity mbox recvCB

let doit () =
    try
        Trace.inf "Ex_carv" "Creating node\n";
        let name = ref "ocaml" in
        let cookie = ref "" in
        Arg.parse
            [
                ("-cookie", Arg.String ((:=) cookie), "erlang node cookie");
                ("-name", Arg.String ((:=) name), "erlang node name");
            ]
            ignore
            "";
        Trace.dbg "Ex_carv" "name: %s; cookie: %s\n" !name !cookie;
        let n = Enode.create !name ~cookie:!cookie in
        let _ = Thread.sigmask Unix.SIG_BLOCK [Sys.sigint] in
        let _ = Enode.start n in
        let _ = create_main_process n "carv" in
        let _ = Thread.wait_signal [Sys.sigint] in
        Enode.stop n
    with
        exn -> Printf.printf "ERROR:%s\n" (Printexc.to_string exn)

let _  = doit ()

