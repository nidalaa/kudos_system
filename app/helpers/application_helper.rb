module ApplicationHelper
  EMOJI_MAP = {
    "taco"        => "🌮",
    "heart"       => "❤️",
    "thumbsup"    => "👍",
    "fire"        => "🔥",
    "clap"        => "👏",
    "100"         => "💯",
    "star"        => "⭐",
    "tada"        => "🎉",
    "rocket"      => "🚀",
    "mind_blown"  => "🤯",
    "raised_hands"=> "🙌",
    "muscle"      => "💪",
    "pray"        => "🙏",
    "moneybag"    => "💰",
    "chart_with_upwards_trend" => "📈",
    "fist_bump"   => "👊",
    "accessibility" => "♿",
    "books"       => "📚"
  }.freeze

  def format_reaction(reaction)
    if reaction.include?(":")
      emoji_name, username = reaction.split(":", 2)
      "#{EMOJI_MAP.fetch(emoji_name, ":#{emoji_name}:")} #{username}"
    else
      reaction
    end
  end
end
