# Kiro Settings

## MCP Configuration

The MCP (Model Context Protocol) configuration is stored in `mcp.json` and uses environment variables for sensitive data like tokens.

## Setting Up Tokens

1. Copy the example environment file:
   ```bash
   cp .kiro/settings/.env.local.example .kiro/settings/.env.local
   ```

2. Edit `.env.local` and add your actual tokens:
   ```bash
   GITHUB_PERSONAL_ACCESS_TOKEN=your_actual_token_here
   ```

3. Load the environment variables before starting Kiro:
   ```bash
   source .kiro/settings/load-env.sh
   ```

   Or add this to your `~/.zshrc` or `~/.bash_profile` to load automatically:
   ```bash
   # Load Kiro environment variables
   if [ -f "$HOME/path/to/project/.kiro/settings/load-env.sh" ]; then
       source "$HOME/path/to/project/.kiro/settings/load-env.sh"
   fi
   ```

## Security Notes

- `.env.local` is excluded from git via `.gitignore`
- Never commit tokens or sensitive data to version control
- The `mcp.json` file references environment variables using `${VAR_NAME}` syntax
- If you expose a token, revoke it immediately on GitHub and generate a new one

## GitHub Token Setup

To create a GitHub Personal Access Token:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name (e.g., "Kiro MCP Server")
4. Select required scopes (typically: `repo`, `read:org`, `read:user`)
5. Generate and copy the token
6. Add it to `.env.local`
