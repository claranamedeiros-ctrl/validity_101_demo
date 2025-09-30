# Deployment Instructions

## Step 1: Create GitHub Repository

1. **Go to GitHub**: https://github.com/claranamedeiros-ctrl

2. **Click the green "New" button** (should be near your profile/repositories)

3. **Fill out the form**:
   - Repository name: `validity_101_demo`
   - Description: `Patent validity evaluation system with AI analysis`
   - Make it **Public**
   - **DO NOT** check "Add a README file"
   - **DO NOT** check "Add .gitignore"
   - **DO NOT** check "Choose a license"

4. **Click "Create repository"**

5. **Copy the repository URL** from the page that appears (should look like: `https://github.com/claranamedeiros-ctrl/validity_101_demo.git`)

6. **Give me the URL** so I can push the code

## Step 2: Railway Deployment (After GitHub Setup)

1. Go to https://railway.app
2. Sign up/login with your GitHub account
3. Click "New Project"
4. Select "Deploy from GitHub repo"
5. Choose the `validity_101_demo` repository
6. Add environment variable: `OPENAI_API_KEY` with your API key
7. Deploy!

## What's Already Done

✅ App prepared for Railway deployment
✅ PostgreSQL configured for production
✅ Railway.toml configuration file created
✅ Git repository initialized and committed
✅ .gitignore file created (excludes .env, .claude, groundt folder)

## Next: Give me the GitHub repository URL so I can push the code!