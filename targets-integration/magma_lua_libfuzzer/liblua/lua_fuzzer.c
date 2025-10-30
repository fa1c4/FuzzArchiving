#include <stdint.h>
#include <stddef.h>
#include <signal.h>
#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static lua_State *gL = NULL;

static void lstop(lua_State *L, lua_Debug *ar) {
  (void)ar;
  lua_sethook(L, NULL, 0, 0);
  luaL_error(L, "interrupted!");
}

static void laction(int sig) {
  int mask = LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT;
  signal(sig, SIG_DFL);
  lua_sethook(gL, lstop, mask, 1);
}

static int msghandler(lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {
    if (luaL_callmeta(L, 1, "__tostring") && lua_type(L, -1) == LUA_TSTRING)
      return 1;
    else
      msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
  }
  luaL_traceback(L, L, msg, 1);
  return 1;
}

static int docall(lua_State *L, int narg, int nres) {
  int base = lua_gettop(L) - narg;
  lua_pushcfunction(L, msghandler);
  lua_insert(L, base);
  gL = L;
  signal(SIGINT, laction);
  int status = lua_pcall(L, narg, nres, base);
  signal(SIGINT, SIG_DFL);
  lua_remove(L, base);
  return status;
}

// 可选：限步，避免超长执行；如需启用可把注释去掉
// static void hook_limit(lua_State *L, lua_Debug *ar) {
//   (void)ar;
//   static int steps = 0;
//   if (++steps > 100000) luaL_error(L, "step limit");
// }

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  lua_State *L = luaL_newstate();
  if (!L) return 0;

  // 需要时可以只开安全子集；先全开以复刻 OSS-Fuzz 语义
  luaL_openlibs(L);

  // 启用限步（可选）
  // lua_sethook(L, hook_limit, LUA_MASKCOUNT, 1000);

  // 以文本模式加载（与 OSS-Fuzz 一致 "t"）；也可试 "bt" 同时接受字节码
  int st = luaL_loadbufferx(L, (const char *)data, size, "fuzz.lua", "t");
  if (st == LUA_OK) {
    (void)docall(L, 0, 0);
  } else {
    // 语法错误等：对覆盖率也有意义；清栈避免泄露
    lua_pop(L, 1);
  }

  lua_close(L);
  return 0;
}
