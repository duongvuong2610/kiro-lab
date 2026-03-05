# GitHub Personal Access Token Setup

To use the GitHub MCP server, you need to create a Personal Access Token (PAT) and configure it.

## Step 1: Create GitHub Personal Access Token

1. **Go to GitHub Settings:**
   - Visit: https://github.com/settings/tokens
   - Or: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)

2. **Click "Generate new token" → "Generate new token (classic)"**

3. **Configure the token:**
   - **Note:** `Kiro MCP GitHub Access`
   - **Expiration:** Choose your preference (90 days recommended)
   - **Select scopes:**
     - ✅ `repo` (Full control of private repositories)
       - This includes: repo:status, repo_deployment, public_repo, repo:invite, security_events
     - ✅ `workflow` (Update GitHub Action workflows)
     - ✅ `read:org` (Read org and team membership, read org projects)
     - ✅ `gist` (Create gists) - Optional

4. **Click "Generate token"**

5. **Copy the token immediately** (you won't be able to see it again!)
   - It will look like: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## Step 2: Configure the Token

### Option A: Using .env.local (Recommended)

1. **Check if `.env.local` exists:**
   ```bash
   ls -la .kiro/settings/.env.local
   ```

2. **If it doesn't exist, create it from the example:**
   ```bash
   cp .kiro/settings/.env.local.example .kiro/settings/.env.local
   ```

3. **Edit `.env.local` and add your token:**
   ```bash
   # Open in your editor
   nano .kiro/settings/.env.local
   # or
   code .kiro/settings/.env.local
   ```

4. **Add this line (replace with your actual token):**
   ```bash
   GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_actual_token_here
   ```

5. **Save and close the file**

6. **Load the environment variables:**
   ```bash
   source .kiro/settings/load-env.sh
   ```

### Option B: Using Shell Profile (Alternative)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_your_actual_token_here"
```

Then reload:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

## Step 3: Verify the Token is Set

```bash
# Check if the variable is set (should show the token)
echo $GITHUB_PERSONAL_ACCESS_TOKEN

# Or check without revealing the full token
echo ${GITHUB_PERSONAL_ACCESS_TOKEN:0:10}...
```

## Step 4: Restart Kiro IDE

After setting the token, restart Kiro IDE so it picks up the new environment variable.

## Step 5: Test GitHub MCP

Once configured, you should be able to use GitHub MCP commands to:
- List commits
- Check repository status
- View GitHub Actions workflows
- Create issues and pull requests
- And more!

## Security Notes

⚠️ **Important:**
- Never commit `.env.local` to git (it's already in `.gitignore`)
- Keep your token secure
- Rotate tokens periodically
- Use the minimum required scopes

## Troubleshooting

### Issue: "Bad credentials" error

**Solution:**
1. Verify token is set: `echo $GITHUB_PERSONAL_ACCESS_TOKEN`
2. Check token hasn't expired on GitHub
3. Ensure token has correct scopes
4. Restart Kiro IDE after setting the token

### Issue: Token not loading

**Solution:**
1. Check `.env.local` file exists and has correct format
2. Run: `source .kiro/settings/load-env.sh`
3. Restart your terminal/IDE

## Quick Setup Commands

```bash
# Create .env.local from example
cp .kiro/settings/.env.local.example .kiro/settings/.env.local

# Edit and add your token
nano .kiro/settings/.env.local

# Load environment variables
source .kiro/settings/load-env.sh

# Verify
echo ${GITHUB_PERSONAL_ACCESS_TOKEN:0:10}...

# Restart Kiro IDE
```

---

**After setup, you'll be able to use GitHub MCP to check repository status, commits, and GitHub Actions!**
