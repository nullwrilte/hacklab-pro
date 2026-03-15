#!/bin/bash
# categories/utils/install.sh
HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
bash "$HACKLAB_ROOT/tools/manager.sh" install-category utils
