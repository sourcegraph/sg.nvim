let s:latest_callback = v:null

function sg#cody_request(ignored, cb)
  let s:latest_callback = a:cb

  call v:lua.require'sg.extensions.coc'.request(a:ignored)
endfunction

function sg#execute_callback(results)
  if s:latest_callback == v:null
    return
  endif

  call s:latest_callback(v:null, a:results)
  let s:latest_callback = v:null
endfunction
