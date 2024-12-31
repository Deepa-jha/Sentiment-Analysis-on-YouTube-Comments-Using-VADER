from flask import Flask, request, render_template, jsonify
from googleapiclient.discovery import build
import re
import emoji
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
import matplotlib.pyplot as plt
import io
import base64

API_KEY = 'AIzaSyDccELbDIWfVk-x28YEWnqkYa3lwljbyEM'  # Replace with your new API key

app = Flask(__name__)

def fetch_comments(video_id):
    youtube = build('youtube', 'v3', developerKey=API_KEY)
    
    video_response = youtube.videos().list(
        part='snippet',
        id=video_id
    ).execute()

    video_snippet = video_response['items'][0]['snippet']
    uploader_channel_id = video_snippet['channelId']

    comments = []
    nextPageToken = None
    while len(comments) < 600:
        request = youtube.commentThreads().list(
            part='snippet',
            videoId=video_id,
            maxResults=100,
            pageToken=nextPageToken
        )
        response = request.execute()
        for item in response['items']:
            comment = item['snippet']['topLevelComment']['snippet']
            if comment['authorChannelId']['value'] != uploader_channel_id:
                comments.append(comment['textDisplay'])
        nextPageToken = response.get('nextPageToken')
        if not nextPageToken:
            break
    return comments

def filter_comments(comments):
    hyperlink_pattern = re.compile(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+')
    threshold_ratio = 0.65
    relevant_comments = []

    for comment_text in comments:
        comment_text = comment_text.lower().strip()
        emojis = emoji.emoji_count(comment_text)
        text_characters = len(re.sub(r'\s', '', comment_text))
        if (any(char.isalnum() for char in comment_text)) and not hyperlink_pattern.search(comment_text):
            if emojis == 0 or (text_characters / (text_characters + emojis)) > threshold_ratio:
                relevant_comments.append(comment_text)
    return relevant_comments

def analyze_sentiments(comments):
    sentiment_object = SentimentIntensityAnalyzer()
    polarity = []
    positive_comments = []
    negative_comments = []
    neutral_comments = []

    for comment in comments:
        sentiment_dict = sentiment_object.polarity_scores(comment)
        polarity.append(sentiment_dict['compound'])
        if sentiment_dict['compound'] > 0.05:
            positive_comments.append(comment)
        elif sentiment_dict['compound'] < -0.05:
            negative_comments.append(comment)
        else:
            neutral_comments.append(comment)
    
    avg_polarity = sum(polarity) / len(polarity) if polarity else 0
    if avg_polarity > 0.05:
        sentiment = "The Video has got a Positive response"
    elif avg_polarity < -0.05:
        sentiment = "The Video has got a Negative response"
    else:
        sentiment = "The Video has got a Neutral response"
    
    return positive_comments, negative_comments, neutral_comments, sentiment

def create_plots(positive_count, negative_count, neutral_count):
    labels = ['Positive', 'Negative', 'Neutral']
    comment_counts = [positive_count, negative_count, neutral_count]

    fig, ax = plt.subplots()
    ax.bar(labels, comment_counts, color=['blue', 'red', 'grey'])
    ax.set_xlabel('Sentiment')
    ax.set_ylabel('Comment Count')
    ax.set_title('Sentiment Analysis of Comments')
    bar_img = io.BytesIO()
    plt.savefig(bar_img, format='png')
    bar_img.seek(0)
    bar_plot_url = base64.b64encode(bar_img.getvalue()).decode()

    fig, ax = plt.subplots()
    ax.pie(comment_counts, labels=labels, autopct='%1.1f%%')
    pie_img = io.BytesIO()
    plt.savefig(pie_img, format='png')
    pie_img.seek(0)
    pie_plot_url = base64.b64encode(pie_img.getvalue()).decode()

    return bar_plot_url, pie_plot_url

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/process', methods=['POST'])
def process_video():
    video_url = request.form['video_url']
    video_id = video_url[-11:]
    comments = fetch_comments(video_id)
    relevant_comments = filter_comments(comments)
    positive_comments, negative_comments, neutral_comments, sentiment = analyze_sentiments(relevant_comments)
    
    bar_plot_url, pie_plot_url = create_plots(len(positive_comments), len(negative_comments), len(neutral_comments))

    return render_template('results.html', sentiment=sentiment, 
                           bar_plot_url=bar_plot_url, pie_plot_url=pie_plot_url,
                           positive_comments=positive_comments, 
                           negative_comments=negative_comments, 
                           neutral_comments=neutral_comments)

if __name__ == '__main__':
    app.run(debug=True)
