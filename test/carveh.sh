#!/bin/bash


# some rubish code to locate the file ...

simplify_path () {
    curfile=$2
    # simplify path by transforming "//" in "/"
    pattern="/\{2,\}"
    while ( echo "${curfile}" | grep "${pattern}" >/dev/null 2>&1 ) ; do
      curfile=`echo "${curfile}" | sed -e s%"${pattern}"%"/"%`
    done
    # simplify path by removing "./"
    pattern="/\./"
    while ( echo "${curfile}" | grep "${pattern}" >/dev/null 2>&1 ) ; do
      curfile=`echo "${curfile}" | sed -e s%"${pattern}"%"/"%`
    done
    # simplify path by transforming "x/y/.." in "x"
    pattern="/[^/]\{1,\}/\.\./"
    while ( echo "${curfile}" | grep "${pattern}" >/dev/null 2>&1 ) ; do
      curfile=`echo "${curfile}" | sed -e s%"${pattern}"%"/"%`
    done
    eval "$1=$curfile"
}

locate () {
    # Extract the path where this file is located (not where it is run
    # from), taking care of dereferencing link and simplifying path.
    # (code from FHT commented/set-in-function by LCE)
    #
    # locate $2 dereferencing link
    curpath=$2
    curfile=""
    while [ "${curpath}" != "/" ] ; do
      if [ -h "${curpath}" ] ; then
        lnk=`ls -l ${curpath} | sed -e s%"^.\\{0,\\}[ ]->[ ]\\{1,\\}"%%`
        if ( echo "${lnk}" | grep "^/" >/dev/null 2>&1 ) ; then
          curpath="${lnk}"
        else
          curpath="`dirname ${curpath}`/${lnk}"
        fi
      else
        curfile="/`basename ${curpath}`${curfile}"
        curpath=`dirname ${curpath}`
      fi
    done
    simplify_path locfile $curfile
    eval "$1=$locfile"
}

# extract application path
if ( echo "${0}" | grep "^/" >/dev/null 2>&1) ; then
  CURPATH="${0}"
else
  CURPATH="`pwd`/${0}"
fi
locate CURFILE $CURPATH

# directory where is the current file (file $0)
ROOT=`dirname ${CURFILE}`/..


# running the example start here

EXIT=0
OCAML_NODE_NAME=ocaml
ERLANG_NODE_NAME=erl
COOKIE=cookie
APP=$ROOT/carve.native

# start erlang first (ensure epmd is running)
echo; echo "Test $0: Run and stop an erlang node to ensure epmd is running."
erl -sname $ERLANG_NODE_NAME -setcookie $COOKIE -noshell -s init stop

echo; echo "Test $0: Run the ocaml server."
$APP -name $OCAML_NODE_NAME -cookie $COOKIE &
OCAML_PID=$!

echo; echo "Test $0: Run erlang node to interact with ocaml node."
erl -sname $ERLANG_NODE_NAME -setcookie $COOKIE -noshell -eval "
    OcamlNode = list_to_atom(\"$OCAML_NODE_NAME@\" ++ net_adm:localhost()),
    pong = net_adm:ping(OcamlNode),
    
    R1 = make_ref(),
    {eocarving, OcamlNode} ! {self(), R1},
    {ok, Carver} = receive {R1, P} -> {ok, P} after 1 -> error end,

    Carver ! {set_src_file, \"$ROOT/test/river.jpg\"},
    Carver ! {carve_h, -50, \"$ROOT/test/river_del50.jpg\"},
    Carver ! {carve_h, +50, \"$ROOT/test/river_add50.jpg\"},

    Carver ! {set_src_file, \"$ROOT/test/horses.jpg\"},
    Carver ! {carve_h, -50, \"$ROOT/test/horses_del50.jpg\"},
    Carver ! {carve_h, +50, \"$ROOT/test/horses_add50.jpg\"},

    Carver ! {self(), stop},
    ok = receive {Carver, stopped} -> ok after 5000 -> error end.
" -s init stop
EXIT=$?

echo; echo "Test $0: Kill ocaml server"
kill $OCAML_PID

echo; echo "Test $0: RESULT=${EXIT} (0=ok)"
exit ${EXIT}

