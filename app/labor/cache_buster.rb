class CacheBuster
  def bust(path)
    return unless Rails.env.production?
    request = HTTParty.post("https://api.fastly.com/purge/https://dev.to#{path}",
    headers: { "Fastly-Key" => "f15066a3abedf47238b08e437684c84f" })
    request = HTTParty.post("https://api.fastly.com/purge/https://dev.to#{path}?i=i",
    headers: { "Fastly-Key" => "f15066a3abedf47238b08e437684c84f" })
    request
  end

  def bust_comment(comment)
    if comment.commentable.featured_number.to_i > (Time.now.to_i - 5.hours.to_i)
      bust("/")
      bust("/?i=i")
      bust("?i=i")
    end
    if comment.commentable.decorate.cached_tag_list_array.include?("discuss") &&
        comment.commentable.featured_number.to_i > (Time.now.to_i - 35.hours.to_i)
      bust("/")
      bust("/?i=i")
      bust("?i=i")
    end
    bust("#{comment.commentable.path}/comments/")
    bust(comment.commentable.path.to_s)
    comment.commentable.comments.each do |c|
      bust(c.path)
      bust(c.path + "?i=i")
    end
    bust("#{comment.commentable.path}/comments/*")
    bust("/#{comment.user.username}")
    bust("/#{comment.user.username}/comments")
    bust("/#{comment.user.username}/comments?i=i")
    bust("/#{comment.user.username}/comments/?i=i")
  end

  def bust_article(article)
    bust("/" + article.user.username)
    bust(article.path + "/")
    bust(article.path + "?i=i")
    bust(article.path + "/?i=i")
    bust(article.path + "/comments")
    bust(article.path + "?preview=" + article.password)
    bust(article.path + "?preview=" + article.password + "?i=i")
    if article.organization.present?
      bust("/#{article.organization.slug}")
    end
    bust_home_pages(article)
    bust_tag_pages(article)
    bust("/api/articles/#{article.id}")
    bust("/api/articles/by_path?url=#{article.path}")

    article.collection&.articles&.each do |a|
      bust(a.path)
    end
  end

  def bust_home_pages(article)
    if article.featured_number.to_i > Time.now.to_i
      bust("/")
      bust("?i=i")
    end
    [[1.week.ago, "week"], [1.month.ago, "month"], [1.year.ago, "year"], [5.years.ago, "infinity"]].each do |timeframe|
      if Article.where(published: true).where("published_at > ?", timeframe[0]).
          order("positive_reactions_count DESC").limit(4).pluck(:id).include?(article.id)
        bust("/top/#{timeframe[1]}")
        bust("/top/#{timeframe[1]}?i=i")
        bust("/top/#{timeframe[1]}/?i=i")
      end
      if Article.where(published: true).where("published_at > ?", timeframe[0]).
          order("hotness_score DESC").limit(3).pluck(:id).include?(article.id)
        bust("/")
        bust("?i=i")
      end
    end
    if article.published && article.published_at > 1.hour.ago
      bust("/latest")
      bust("/latest?i=i")
    end
  end

  def bust_tag_pages(article)
    return unless article.published
    article.tag_list.each do |tag|
      if article.published_at.to_i > 3.minutes.ago.to_i
        bust("/t/#{tag}/latest")
        bust("/t/#{tag}/latest?i=i")
      end
      [[1.week.ago, "week"], [1.month.ago, "month"], [1.year.ago, "year"], [5.years.ago, "infinity"]].
        each do |timeframe|
        if Article.where(published: true).where("published_at > ?", timeframe[0]).tagged_with(tag).
            order("positive_reactions_count DESC").limit(3).pluck(:id).include?(article.id)
          bust("/top/#{timeframe[1]}")
          bust("/top/#{timeframe[1]}?i=i")
          bust("/top/#{timeframe[1]}/?i=i")
        end
        if Article.where(published: true).where("published_at > ?", timeframe[0]).tagged_with(tag).
            order("hotness_score DESC").limit(3).pluck(:id).include?(article.id)
          bust("/")
          bust("?i=i")
        end
      end
    end
  end
end
