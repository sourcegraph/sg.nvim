local uv = vim.loop

local redirect_server = function(callback)
  print "starting server..."

  local contents = ""

  local server = uv.new_tcp()
  server:bind("127.0.0.1", 8080)
  server:listen(1024 * 1000, function(err)
    assert(not err, err)

    local client = uv.new_tcp()
    server:accept(client)
    client:read_start(function(client_err, chunk)
      assert(not client_err, client_err)
      if chunk then
        contents = contents .. chunk

        client:write [[
HTTP/1.1 200 OK
Content-Type: html

<html>
  <div>Success - Navigate back to Neovim</div>
</html>]]

        client:shutdown()
        client:close()

        callback(contents)
      end

      server:shutdown()
      server:close()
    end)
  end)

  print "server started..."
end

redirect_server(function(contents)
  print("server stopping...", contents)
end)
