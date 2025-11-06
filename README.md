## Pre-commit

- Hooks are centrally managed at `your-org/precommit-shared` (tag `v2025.11.06`).
- First-time setup:
  ```bash
  pip install pre-commit "detect-secrets==1.5.0"
  pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
  if [ ! -f .secrets.baseline ]; then
    detect-secrets scan --exclude-files '(^|.*/)(build|dist|out|target|node_modules|vendor|generated|\\.cache|test|tests|__tests__|src/test|terraform|tools|packer|cwfa-performance-tests|cwfa-jenkins|cwfa-functional-test|cwfa-docs|cwfa-dev-env)/|(\\.properties$)|(^|.*/)docker-compose.*\\.ya?ml$' > .secrets.baseline
    detect-secrets audit .secrets.baseline
    git add .secrets.baseline
  fi
  pre-commit run --all-files
