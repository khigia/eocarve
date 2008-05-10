#!/bin/bash

EXIT=0
OCAML_NODE_NAME=ocaml
ERLANG_NODE_NAME=erl
COOKIE=cookie
PWD=`pwd`

# start erlang first (ensure epmd is running)
echo; echo "Test $0: Run and stop an erlang node to ensure epmd is running."
erl -sname $ERLANG_NODE_NAME -setcookie $COOKIE -noshell -s init stop

echo; echo "Test $0: Run the ocaml server."
./carve.native -name $OCAML_NODE_NAME -cookie $COOKIE &
OCAML_PID=$!

echo; echo "Test $0: Run erlang node to interact with ocaml node."
erl -sname $ERLANG_NODE_NAME -setcookie $COOKIE -noshell -eval "
    OcamlNode = list_to_atom(\"$OCAML_NODE_NAME@\" ++ net_adm:localhost()),
    pong = net_adm:ping(OcamlNode),
    
    R1 = make_ref(),
    {eocarving, OcamlNode} ! {self(), R1},
    {ok, Carver} = receive {R1, P} -> {ok, P} after 1 -> error end,

    Carver ! {set_src_file, \"$PWD/test/river.jpg\"},
    Carver ! {carve_h, -50, \"$PWD/test/river_del50.jpg\"},
    Carver ! {carve_h, +50, \"$PWD/test/river_add50.jpg\"},

    Carver ! {set_src_file, \"$PWD/test/horses.jpg\"},
    Carver ! {carve_h, -50, \"$PWD/test/horses_del50.jpg\"},
    Carver ! {carve_h, +50, \"$PWD/test/horses_add50.jpg\"},

    Carver ! {self(), stop},
    ok = receive {Carver, stopped} -> ok after 5000 -> error end.
" -s init stop
EXIT=$?

echo; echo "Test $0: Kill ocaml server"
kill $OCAML_PID

echo; echo "Test $0: RESULT=${EXIT} (0=ok)"
exit ${EXIT}

