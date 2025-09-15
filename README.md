# Reddit + ChatGPT Shiny App

This Shiny app connects to Reddit and the OpenAI API to analyze or respond to Reddit posts.  
In order for reproducability, you must provide your **own API keys**.

---

## Features
- Authenticate with Reddit using the official API  
- Connect to the OpenAI API (e.g., GPT-4.1-mini)  
- Run inside R/Shiny with an interactive interface  

---

## Setup Instructions

### 1. Get your Reddit API credentials
1. Go to [Reddit Apps](https://www.reddit.com/prefs/apps).  
2. Click **Create App** or **Create Another App**.  
3. Choose **script** as the app type.  
4. Fill in:
   - **name**: anything you like (e.g., *StatisticsProject*)  
   - **redirect URI**: `http://localhost:1410/` (placeholder)  
5. Save → you’ll see your:
   - **client ID** (under the app name)  
   - **secret**  

You’ll also need your Reddit **username** and **password**.

---

### 2. Get your OpenAI API key
1. Go to [OpenAI API Keys](https://platform.openai.com/account/api-keys).  
2. Click **Create new secret key**.  
3. Copy the key (starts with `sk-...`) and keep it safe.  

---

### 3. Store credentials securely
Instead of hardcoding, save them in a hidden file called **`.Renviron`** in your project folder:

```r
REDDIT_CLIENT_ID=your_client_id_here
REDDIT_SECRET=your_secret_here
REDDIT_USERNAME=your_username_here
REDDIT_PASSWORD=your_password_here
REDDIT_USER_AGENT=StatisticsProject/0.1 by your_username_here

OPENAI_API_KEY=sk-your_api_key_here
OPENAI_MODEL=gpt-4.1-mini
```
---

### 4. Run the app locally
1. Open R or RStudio.  
2. Install the required packages:

```r
install.packages(c("shiny", "bslib", "httr", "jsonlite"))


library(shiny)

# Set working directory to where your app files are
setwd("path/to/your/project")

# Run the apprunApp("app.R")
runApp("app.R")
```
















