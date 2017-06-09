type counter = {
    mutable pass: int;
    mutable fail: int;
}

let start () = {
    pass = 0;
    fail = 0;
}

let red s =
    "\027[0;31m" ^ s ^ "\027[0m"

let green s =
    "\027[0;32m" ^ s ^ "\027[0m"

let check counter name v x =
    let _ = Printf.printf "Running %s ..... " name in
    try
        if v () <> x then
            let _ = counter.fail <- counter.fail + 1 in
            print_endline (red "FAILED")
        else let _ = counter.pass <- counter.pass + 1 in
            print_endline (green "passed")
    with exc ->
        let _ = counter.fail <- counter.fail + 1 in
        Printf.printf "\027[0;31mFAILED\027[0m  with error:\n\t%s\n" (Printexc.to_string exc)

let check_raise counter name v =
    let _ = Printf.printf "Running %s ..... " name in
    try
        let _ = v () in
        let _ = counter.fail <- counter.fail + 1 in
        print_endline (red "FAILED")
    with _ ->
        let _ = counter.pass <- counter.pass + 1 in
        print_endline (green "passed")

let all t l =
    List.iter (fun fn -> fn t) l

let finish counter =
    Printf.printf "\nTotal: %d\n\nPassed: %d\nFailed: %d\n" (counter.pass + counter.fail) counter.pass counter.fail;
    exit counter.fail
