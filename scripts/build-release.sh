#!/usr/bin/env bash
# 打可上架的签名版 .app
#
# 用法：
#   KEY_STORE_PASS='你的密码' ./scripts/build-release.sh
#
# 可选环境变量：
#   KEY_STORE      默认 ~/keys/shipenergy/shipenergy.p12
#   KEY_ALIAS      默认 shipenergy
#   SIGN_CERT      默认 ~/keys/shipenergy/shipconsumecalculator.cer
#   SIGN_PROFILE   默认 ~/keys/shipenergy/shipenergyRelease.p7b
#
# 流程：hvigor 出未签名 .app → hap-sign-tool 本地签名 → 验签
# 密码只通过环境变量传入，不写入任何工程文件。
set -euo pipefail

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
KEY_STORE="${KEY_STORE:-$HOME/keys/shipenergy/shipenergy.p12}"
KEY_ALIAS="${KEY_ALIAS:-shipenergy}"
SIGN_CERT="${SIGN_CERT:-$HOME/keys/shipenergy/shipconsumecalculator.cer}"
SIGN_PROFILE="${SIGN_PROFILE:-$HOME/keys/shipenergy/shipenergyRelease.p7b}"
: "${KEY_STORE_PASS:?请先设置 KEY_STORE_PASS 环境变量（keystore 密码）}"

for f in "$KEY_STORE" "$SIGN_CERT" "$SIGN_PROFILE"; do
  [ -f "$f" ] || { echo "缺少文件：$f" >&2; exit 1; }
done

export NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH="$JAVA_HOME/bin:$NODE_HOME/bin:$PATH"
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk

JAVA="$JAVA_HOME/bin/java"
SIGN_TOOL="$DEVECO_SDK_HOME/default/openharmony/toolchains/lib/hap-sign-tool.jar"

cd "$PROJ"

echo "==> 1/3 构建未签名 .app"
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleApp --mode project -p product=default -p buildMode=release --no-daemon \
  | grep -E "BUILD|ERROR" | tail -3

UNSIGNED=$(ls -t build/outputs/default/*unsigned.app 2>/dev/null | head -1)
[ -n "$UNSIGNED" ] || { echo "未找到未签名 .app" >&2; exit 1; }
echo "    输入：$UNSIGNED"

VERSION=$(unzip -p "$UNSIGNED" pack.info 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['summary']['app']['version']['name'])" 2>/dev/null || echo "1.0.0")
OUT="store-assets/shipenergy-${VERSION}-signed.app"

echo "==> 2/3 使用发布证书签名"
"$JAVA" -jar "$SIGN_TOOL" sign-app \
  -mode localSign \
  -keyAlias "$KEY_ALIAS" \
  -keyPwd "$KEY_STORE_PASS" \
  -appCertFile "$SIGN_CERT" \
  -profileFile "$SIGN_PROFILE" \
  -inFile "$UNSIGNED" \
  -outFile "$OUT" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$KEY_STORE" \
  -keystorePwd "$KEY_STORE_PASS"

echo "==> 3/3 验签"
"$JAVA" -jar "$SIGN_TOOL" verify-app \
  -inFile "$OUT" \
  -outCertChain /tmp/verify-certs.cer \
  -outProfile /tmp/verify-profile.p7b 2>&1 | tail -3

echo
echo "产物：$OUT"
ls -lh "$OUT" | awk '{print "大小:", $5}'
shasum -a 256 "$OUT"
