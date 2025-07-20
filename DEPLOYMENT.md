# Railway Deployment Guide

## Setup Steps:

### 1. Create Railway Account
- Go to [railway.app](https://railway.app)
- Sign up with GitHub account

### 2. Deploy from GitHub
- Click "New Project" 
- Select "Deploy from GitHub repo"
- Choose this repository
- Select the `server/` folder as root

### 3. Set Environment Variables
In Railway dashboard, go to Variables and add:
```
API_KEY=dc85c5606119223f78fba46cb2e422af22577709f6d9dbf48ac7afcd92f67c7d
PORT=3000
```

### 4. Deploy
- Railway will automatically deploy from the `server/` folder
- Your app will be available at: `https://[project-name].up.railway.app`

### 5. Update Client Apps
Update the `serverUrl` in:
- `windows/config.json`
- iOS app configuration
- Any other client apps

### 6. Test
- Health check: `GET https://[your-url]/health`
- Set clipboard: `POST https://[your-url]/clipboard` with API key
- Get clipboard: `GET https://[your-url]/clipboard` with API key

## Production URL
Once deployed, update all client configurations to use:
```
https://[your-project-name].up.railway.app
```

## Custom Domain (Optional)
Railway supports custom domains in their dashboard under Settings > Domains.