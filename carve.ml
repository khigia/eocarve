open Ocamerl
open Seamcarving


module Energy = Sobel.Energy
module Carving = Make(Energy)
module BiasedEnergy = EnergyBias.Make(Energy)
module BiasedCarving = Make(BiasedEnergy)
module Insertion = Seaminsertion.Make(Carving)


let time msg f x =
    let t0 = Sys.time() in
    let ret = f x in
    Trace.dbg "carve" "%s executed in %.2fs." msg (Sys.time() -. t0);
    ret


module Carver = struct
    
    type t = {
        mutable srcfn: string option;
        mutable dstfn: string option;
    }

    let create () = {
        srcfn = None;
        dstfn = None;
    }

    let set_src_data self bin =
        let fn = Tmpfile.new_tmp_file_name "oecarving" in
        let oc = open_out_bin fn in
        Array.iter (output_char oc) bin;
        flush oc;
        close_out oc;
        self.srcfn <- Some fn
    
    let set_src_file self fn =
        self.srcfn <- Some fn

    let _seam_del img eproc n =
        if n >= img.width - 10 then failwith "Excessive horizontal downsizing.";
        let rec _carve_h i carved =
            if i > 0 then
                _carve_h (i-1) (Carving.seam_carve_h carved)
            else
                carved
        in
        let carved = Carving.make eproc img in
        let carved = time "Horizontal carving" (_carve_h n) carved in
        Carving.image carved

    let _seam_add img eproc n =
        let carved = Insertion.make eproc img in
        let carved = time "Horizontal carving" (Insertion.insert_seams carved) n in
        carved

    let carve_h self i dstfn =
        let src = match self.srcfn with None -> failwith "no data source" | Some x -> x in
        let dst = match dstfn with None -> src ^ ".carved_h.png" | Some x -> x in
        let img = Seamcarving.load_image src in
        let eproc =  Energy.processor in (* biased image could be used here *)
        let carved = if i < 0 then _seam_del img eproc (-i) else _seam_add img eproc i in
        Seamcarving.save_image carved dst;
        self.dstfn <- Some dst
        
    let get_dst_file self =
        self.dstfn

end (* module Carver *)


let create_worker_process node =
    let carver = Carver.create () in
    let mbox = Enode.create_mbox node in
    let recvCB = fun msg -> match msg with
    | Eterm.ET_tuple [|Eterm.ET_atom "set_src_file"; Eterm.ET_string fn;|] ->
        Carver.set_src_file carver fn
    | Eterm.ET_tuple [|Eterm.ET_atom "set_src_data"; Eterm.ET_bin b;|] ->
        Carver.set_src_data carver b
    | Eterm.ET_tuple [|Eterm.ET_atom "carve_h"; Eterm.ET_int i;|] ->
        Carver.carve_h carver (Int32.to_int i) None
    | Eterm.ET_tuple [|pid; Eterm.ET_atom "get_dst_file";|] ->
        begin
        match Carver.get_dst_file carver with
        | Some fn ->
            Enode.send node pid (Eterm.ET_tuple [|Eterm.ET_atom "ok"; Eterm.ET_string fn;|])
        | None ->
            Enode.send node pid (Eterm.ET_atom "no_file")
        end
    | msg ->
        (* skip unknown message *)
        Trace.dbg "carve" "Worker skiping unknown message: %s\n" (Eterm.to_string msg);
        ()
    in
    Enode.Mbox.create_activity mbox recvCB;
    Enode.Mbox.pid mbox


let create_main_process node name =
    let mbox = Enode.create_mbox node in
    let _ = Enode.register_mbox node mbox name in
    let recvCB = fun msg -> match msg with
    | Eterm.ET_tuple [|pid; Eterm.ET_ref r;|] ->
        let worker = create_worker_process node in
        Enode.send node pid (Eterm.ET_tuple [|Eterm.ET_ref r; worker;|])
    | msg ->
        (* skip unknown message *)
        Trace.dbg "carve" "Skip unknown message: %s\n" (Eterm.to_string msg);
    in
    Enode.Mbox.create_activity mbox recvCB


let doit () =
    try
        Trace.inf "carve" "Creating node\n";
        let name = ref "ocaml" in
        let cookie = ref "" in
        Arg.parse
            [
                ("-cookie", Arg.String ((:=) cookie), "erlang node cookie");
                ("-name", Arg.String ((:=) name), "erlang node name");
            ]
            ignore
            "";
        Trace.dbg "carve" "name: %s; cookie: %s\n" !name !cookie;
        let n = Enode.create !name ~cookie:!cookie in
        let _ = Thread.sigmask Unix.SIG_BLOCK [Sys.sigint] in
        let _ = Enode.start n in
        let _ = create_main_process n "eocarving" in
        let _ = Thread.wait_signal [Sys.sigint] in
        Enode.stop n
    with
        exn -> Printf.printf "ERROR:%s\n" (Printexc.to_string exn)


let _  = doit ()

