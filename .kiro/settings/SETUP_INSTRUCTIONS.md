# Automatic Environment Loading Setup

## Permanent Loading (Recommended)

The GitHub token will be loaded automatically every time you open a terminal and will stay loaded permanently.

### Setup Steps:

1. Add this to your `~/.zshrc`:

```bash
# Auto-load Kiro environment variables
if [ -f "/Users/vuongduongvan/Documents/CMC/repositories/kiro-lab/.kiro/settings/load-env.sh" ]; then
    source "/Users/vuongduongvan/Documents/CMC/repositories/kiro-lab/.kiro/settings/load-env.sh"
fi
```

2. Reload your shell:
```bash
source ~/.zshrc
```

3. Verify it works:
```bash
echo $GITHUB_PERSONAL_ACCESS_TOKEN
```

The token will now be available in all your terminal sessions permanently.

---

## Alternative: Project-specific with direnv (NOT RECOMMENDED for your use case)

If you wanted the token to only be available when in the project directory and unload when you leave, you would use direnv. But since you want it to stay loaded, use the permanent loading method above instead.
