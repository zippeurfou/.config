# Spark
export SPARK_HOME="$HOME/spark-3.3.1-bin-hadoop3"
export PATH="$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin"
# poetry / local bin
export PATH="$HOME/.local/bin:$PATH"
# Lua / luarocks
export LUA_DIR="$HOME/Developer/lua"
export PATH="$PATH:${LUA_DIR}/bin:$HOME/.luarocks/bin"
export LUA_CPATH="${LUA_DIR}/lib/lua/5.1/?.so"
export LUA_PATH="${LUA_DIR}/share/lua/5.1/?.lua;;"
export MANPATH="${LUA_DIR}/share/man:$MANPATH"
eval "$(luarocks path --no-bin)"
