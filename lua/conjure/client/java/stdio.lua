-- [nfnl] fnl/conjure/client/java/stdio.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_["autoload"]
local define = _local_1_["define"]
local a = autoload("conjure.aniseed.core")
local client = autoload("conjure.client")
local config = autoload("conjure.config")
local log = autoload("conjure.log")
local mapping = autoload("conjure.mapping")
local stdio = autoload("conjure.remote.stdio")
local str = autoload("conjure.aniseed.string")
local ts = autoload("conjure.tree-sitter")
local M = define("conjure.client.java.stdio")
config.merge({client = {java = {stdio = {command = "jshell -q", ["prompt-pattern"] = "jshell> "}}}})
if config["get-in"]({"mapping", "enable_defaults"}) then
  config.merge({client = {java = {stdio = {mapping = {start = "cs", stop = "cS", interrupt = "ei"}}}}})
else
end
local cfg = config["get-in-fn"]({"client", "java", "stdio"})
local state
local function _3_()
  return {repl = nil}
end
state = client["new-state"](_3_)
M["buf-suffix"] = ".java"
M["comment-prefix"] = "// "
local function format_message(msg)
  local function _4_(_241)
    return ("" ~= _241)
  end
  return a.filter(_4_, str.split(msg.out, "\n"))
end
local function unbatch(msgs)
  local function _5_(_241)
    return (a.get(_241, "out") or a.get(_241, "err"))
  end
  return {out = str.join("", a.map(_5_, msgs))}
end
local function with_repl_or_warn(f, opts)
  local repl = state("repl")
  if repl then
    return f(repl)
  else
    return log.append({(M["comment-prefix"] .. "No REPL running"), (M["comment-prefix"] .. "Start REPL with " .. config["get-in"]({"mapping", "prefix"}) .. cfg({"mapping", "start"}))})
  end
end
local function display_repl_status(status)
  return log.append({(M["comment-prefix"] .. cfg({"command"}) .. " (" .. (status or "no status") .. ")")}, {["break?"] = true})
end
M.start = function()
  log.append({(M["comment-prefix"] .. "Starting Java client...")})
  if state("repl") then
    return log.append({(M["comment-prefix"] .. "Can't start, REPL is already running."), (M["comment-prefix"] .. "Stop the REPL with " .. config["get-in"]({"mapping", "prefix"}) .. cfg({"mapping", "stop"}))}, {["break?"] = true})
  else
    local function _7_()
      return ts["add-language"]("java")
    end
    if not pcall(_7_) then
      return log.append({(M["comment-prefix"] .. "(error) The java client requires a java treesitter parser in order to function."), (M["comment-prefix"] .. "(error) See https://github.com/nvim-treesitter/nvim-treesitter"), (M["comment-prefix"] .. "(error) for installation instructions.")})
    else
      local function _8_()
        return display_repl_status("started")
      end
      local function _9_(err)
        return display_repl_status(err)
      end
      local function _10_(code, signal)
        if (("number" == type(code)) and (code > 0)) then
          log.append({(M["comment-prefix"] .. "process exited with code " .. code)})
        else
        end
        if (("number" == type(signal)) and (signal > 0)) then
          log.append({(M["comment-prefix"] .. "process exited with signal " .. signal)})
        else
        end
        return M.stop()
      end
      local function _13_(msg)
        return log.append(format_message(msg))
      end
      return a.assoc(state(), "repl", stdio.start({["prompt-pattern"] = cfg({"prompt-pattern"}), cmd = cfg({"command"}), ["on-success"] = _8_, ["on-error"] = _9_, ["on-exit"] = _10_, ["on-stray-output"] = _13_}))
    end
  end
end
local function prep_code(s)
  if string.find(s, "\n") then
    return (s .. "")
  else
    return (s .. "\n")
  end
end
M["eval-str"] = function(opts)
  local function _17_(repl)
    local function _18_(msgs)
      local lines = format_message(unbatch(msgs))
      if opts["on-result"] then
        opts["on-result"](a.last(lines))
      else
      end
      return log.append(lines)
    end
    return repl.send(prep_code(opts.code), _18_, {["batch?"] = true})
  end
  return with_repl_or_warn(_17_)
end
local function stop()
  local repl = state("repl")
  if repl then
    repl.destroy()
    display_repl_status("stopped")
    return a.assoc(state(), "repl", nil)
  else
    return nil
  end
end
M["on-exit"] = function()
  return M.stop()
end
M.interrupt = function()
  local function _21_(repl)
    log.append({(M["comment-prefix"] .. " Sending interrupt signal.")}, {["break?"] = true})
    return repl["send-signal"]("sigint")
  end
  return with_repl_or_warn(_21_)
end
M["on-load"] = function()
  if config["get-in"]({"client_on_load"}) then
    return M.start()
  else
    return nil
  end
end
M["on-filetype"] = function()
  local function _23_()
    return M.start()
  end
  mapping.buf("JavaStart", cfg({"mapping", "start"}), _23_, {desc = "Start the Java REPL"})
  local function _24_()
    return M.stop()
  end
  mapping.buf("JavaStop", cfg({"mapping", "stop"}), _24_, {desc = "Stop the Java REPL"})
  local function _25_()
    return M.interrupt()
  end
  return mapping.buf("JavaInterrupt", cfg({"mapping", "interrupt"}), _25_, {desc = "Interrupt the current evaluation"})
end
return M
