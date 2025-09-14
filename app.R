library(shiny)
library(bslib)
library(httr)
library(jsonlite)
library(chatgpt)

## Reddit Setup & ChatGPT
client_id <- Sys.getenv("CLIENT_ID") 
secret <- Sys.getenv("SECRET")
username <- Sys.getenv("USERNAME")
password <- Sys.getenv("PASSWORD")
user_agent <- Sys.getenv("USER_AGENT")

Sys.setenv(OPENAI_MODEL = Sys.getenv("OPENAI_MODEL"))
Sys.setenv(OPENAI_API_KEY = Sys.getenv("OPENAI_API_KEY"))


## Get OAuth access token
get_reddit_token <- function() { # Needed to communicate with Reddit
  auth <- POST(
    "https://www.reddit.com/api/v1/access_token",
    authenticate(client_id, secret),
    body = list(
      grant_type = "password",
      username = username,
      password = password
    ),
    encode = "form",
    add_headers(`User-Agent` = user_agent)
  )
  content(auth)$access_token
}

fetch_posts <- function(subreddit, n_posts = 10) {
  token <- get_reddit_token()
  res <- GET(
    paste0("https://oauth.reddit.com/r/", subreddit, "/hot"),
    query = list(limit = n_posts),
    add_headers(
      Authorization = paste("bearer", token),
      `User-Agent` = user_agent
    )
  )
  res_json <- fromJSON(content(res, as = "text"), simplifyVector = FALSE)
  posts <- res_json$data$children
  
  posts_df <- do.call(rbind, lapply(posts, function(x) {
    if (!is.null(x$data) && !isTRUE(x$data$stickied)) {
      df <- as.data.frame(
        x$data[c("title", "selftext", "score", "author", "url")],
        stringsAsFactors = FALSE
      )
      df$selftext <- paste(head(strsplit(df$selftext, "\\s+")[[1]], 10000), collapse = " ") # Cap the body text to avoid maxing out the tokens
      return(df)
    }
  }))
  posts_df
}

## ChatGPT prompts 
chatgpt_sentiment <- function(prompt) { # For gauging sentiments
  full_prompt <- paste(
  "Act as a sentiment analysis bot where you give a summary of the text I give you.
  Take the whole input into consideration in terms of sentiment where you keep in mind the context.
  Return just with the word 'Positive', 'Negative', or 'Neutral' depending on what sentiment you feel fits the prompt. 
  I will give you the prompt as Title: ___ and Body: ___ \n\n", prompt)
  
  ask_chatgpt(full_prompt)
}

chatgpt_summary <- function(prompt) { # For short summaries
  full_prompt <- paste(
    "Act as a sentiment analysis bot where you give a summary of the text I give you.
  Take the whole input into consideration in terms of sentiment where you keep in mind the context.
  Return a brief summary of what the prompt is about. 
  I will give you the prompt as Title: ___ and Body: ___ \n\n", prompt)
  
  ask_chatgpt(full_prompt)
}


## Define UI
ui <- page_sidebar(
  title = "Sentiment Analysis App (Stats 399)",
  sidebar = sidebar(
    textInput("subreddit", "Enter subreddit:", "universityofauckland"),
    numericInput("n_posts", "Number of posts to fetch (between 1 and 10):", 5, min = 1, max = 10),
    actionButton("go", "Run Analysis")
  ),
  card(
    card_header("Results"),
    card_body(
      tabsetPanel(
        tabPanel("Posts", uiOutput("posts_table")),
        tabPanel("Sentiment", tableOutput("sentiment_table")),
      )
    )
  )
)

## Define server logic
server <- function(input, output, session) {
  
  posts <- reactiveVal(data.frame())
  
  observeEvent(input$n_posts, {
    if (input$n_posts > 10) updateNumericInput(session, "n_posts", value = 10)
    if (input$n_posts < 1) updateNumericInput(session, "n_posts", value = 1)
  })
  
  observeEvent(input$go, {
    
    # Fetch posts from the subreddit entered by the user
    req(input$subreddit)
    tryCatch({
      df <- fetch_posts(input$subreddit, input$n_posts)
      posts(df)
    }, error = function(e) {
      showNotification(paste("Error fetching posts:", e$message), type = "error")
      posts(data.frame())
    })
  })
  
  # Posts Tab 
  output$posts_table <- renderUI({ # Use renderUI so that we can put the hyperlink URL 
    req(nrow(posts()) > 0) # Only render something if at least one post is loaded
    df <- posts()[, c("title", "selftext", "score", "author", "url")]
    
    # Rename columns 
    colnames(df) <- c("Title", "Body Text", "Upvotes", "Author", "URL")
    
    # Turn URL column into hyperlinks
    df$URL <- paste0("<a href='", df$URL, "' target='_blank'>", df$URL, "</a>")
    
    # Numeric columns are auto right aligned(?) So change to char
    # THIS IS NOT GOOD CODE PRACTICE
    df$Upvotes <- as.character(df$Upvotes)
    
    # Render as HTML table with hyperlinks and better spaced table
    table_html <- HTML(knitr::kable(df, format = "html", escape = FALSE))
    
    HTML(
      paste0(
        "<style>
        table {table-layout: fixed; width: 100%;}
        table th:nth-child(2), table td:nth-child(2) {width: 60%;} # Make body text column wider
        table th:nth-child(5), table td:nth-child(5) {width: 15%;} # Make url column thinner
        table th, table td { word-wrap: break-word; }
      </style>",
        table_html
      )
    )
  })

  
  # Sentiment Tab
  output$sentiment_table <- renderTable({
    df <- posts()
    req(nrow(df) > 0) # Only render something if at least one post is loaded
    
    # Combine all posts into one prompt
    posts_text <- apply(df[, c("title", "selftext")], 1, function(row) {
      paste("Title:", row["title"], "\nBody:", row["selftext"])
    })
    
    # Create a single prompt for ChatGPT
    batch_prompt <- paste(
      "You are a sentiment analysis bot.\n",
      "For each of the following posts, return 'Positive', 'Negative', or 'Neutral' in order, one per line.\n\n",
      paste0(seq_along(posts_text), ". ", posts_text, collapse = "\n\n")
    )
    
    # Ask ChatGPT once
    sentiments_raw <- chatgpt_sentiment(batch_prompt)
    
    # Split ChatGPT response into individual sentiments
    sentiments <- trimws(strsplit(sentiments_raw, "\\n")[[1]])
    
    summaries <- sapply(posts_text, function(post) {
      chatgpt_summary(post)
    })
    
    data.frame(
      Title = df$title,
      Sentiment = sentiments,
      Summary = summaries,
      stringsAsFactors = FALSE
    )
  })
  
}

## Run the app
shinyApp(ui = ui, server = server)

