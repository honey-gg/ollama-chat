#!/bin/bash
# 启动「本地 Qwen 对话 · 实时速度监控」页面
#
# 为什么需要这个脚本：Ollama 的 CORS 只允许 127.0.0.1 来源的请求，
# 直接双击 HTML（file:// 协议，Origin 为 null）会被 403 拒绝。
# 所以必须用一个只绑 127.0.0.1 的本地静态服务器把页面端起来。

# 自动定位脚本所在目录，换机器/换路径都不用改
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8777

# 用哪个浏览器打开页面。留空 "" 则用系统默认浏览器。
# 改成 "Google Chrome" / "Microsoft Edge" / "Firefox" 等也可以。
BROWSER="Safari"

printf '\033[1m本地 Qwen 对话页\033[0m\n\n'

# ── 1. 确保 Ollama 在跑 ─────────────────────────────────────
if curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "  OK  Ollama 已在运行"
else
  echo "  ..  Ollama 未运行，正在启动"
  open -a Ollama
  for _ in $(seq 1 40); do
    sleep 1
    curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
  done
  if curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "  OK  Ollama 已启动"
  else
    echo "  !!  Ollama 启动失败，请手动打开 Ollama 后重跑"
    exit 1
  fi
fi

# ── 2. 找一个空闲端口 ───────────────────────────────────────
while lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
  PORT=$((PORT + 1))
done
echo "  OK  使用端口 $PORT"

# ── 3. 选一个 python ────────────────────────────────────────
PY="$(command -v python3 2>/dev/null || true)"
[ -x "$PY" ] || PY=/usr/bin/python3
[ -x "$PY" ] || { echo "  !!  找不到 python3"; exit 1; }

# ── 4. 只绑 127.0.0.1 起服务 ────────────────────────────────
"$PY" -m http.server "$PORT" --bind 127.0.0.1 --directory "$DIR" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT INT TERM

sleep 1
if ! kill -0 $SRV 2>/dev/null; then
  echo "  !!  静态服务器启动失败"; exit 1
fi

URL="http://127.0.0.1:$PORT/"

# ── 5. 用指定浏览器打开（找不到就回落系统默认）────────────────
if [ -n "$BROWSER" ] && [ -d "/Applications/$BROWSER.app" ]; then
  open -a "$BROWSER" "$URL"
  OPENED_IN="$BROWSER"
elif [ -n "$BROWSER" ]; then
  echo "  !!  没找到 /Applications/$BROWSER.app，改用系统默认浏览器"
  open "$URL"
  OPENED_IN="系统默认浏览器"
else
  open "$URL"
  OPENED_IN="系统默认浏览器"
fi

cat <<EOF

  ────────────────────────────────────────────
   页面已打开: $URL
   打开方式:   $OPENED_IN
   关掉这个终端窗口即停止服务。
  ────────────────────────────────────────────

  侧边栏会实时显示：
    实时生成速度 (tok/s) + 速度曲线
    首字延迟 / 预填充速度 / 前缀缓存命中率
    输出 token / 本轮实测 / 模型加载耗时
    会话平均 / 峰值 / 累计 token / 推理设备

  提示：改顶部「上下文」会让 Ollama 重载模型，首次要等十几秒。

EOF

wait $SRV
