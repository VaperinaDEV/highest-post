# frozen_string_literal: true
# name: highest-post
# about: Adds highest_post_excerpt to TopicListItem serializer, with discourse-ai localization support
# version: 0.1.0
# authors: dsims (updated by Don)
# url: https://github.com/dsims/discourse-highest-post

enabled_site_setting :highest_post_enabled

after_initialize do
  module ::HighestPost
    def self.prepended(base)
      base.has_one :highest_post,
                   ->(topic) do
                     if topic.highest_post_number > 1
                       where(post_number: topic.highest_post_number)
                     else
                       Post.none
                     end
                   end,
                   class_name: "Post"
    end
  end

  Topic.prepend HighestPost

  # Ha a PostLocalization modell létezik (discourse-ai content localization aktív),
  # preloadeljük a highest_post mellé a fordításokat is
  if defined?(PostLocalization)
    register_topic_preloader_associations(highest_post: :post_localizations)
  else
    register_topic_preloader_associations(:highest_post)
  end

  add_to_serializer(
    :topic_list_item,
    :highest_post_excerpt,
    include_condition: -> { SiteSetting.highest_post_enabled }
  ) do
    post = object.highest_post
    next nil unless post

    # Localization support: ha van PostLocalization a user locale-jére, azt használjuk
    cooked_to_use = post.cooked

    if defined?(PostLocalization)
      current_locale = scope&.user&.locale.presence || SiteSetting.default_locale
      if post.respond_to?(:post_localizations)
        localization = post.post_localizations.find { |l| l.locale == current_locale }
        cooked_to_use = localization.cooked if localization&.cooked.present?
      end
    end

    html = PrettyText.excerpt(
      cooked_to_use,
      SiteSetting.post_excerpt_maxlength,
      keep_images: true,
      strip_links: true,
      strip_details: true
    )

    doc = Nokogiri::HTML::fragment(html)
    imgs = doc.css("img:not(.emoji)")
    imgs.each { |img| img.remove_attribute("title") }

    if imgs.any?
      first = imgs.first
      more_count = imgs.size - 1
      wrapper = Nokogiri::XML::Node.new("div", doc)
      wrapper["class"] = "highest-post-first-img-wrapper"
      wrapper["data-more"] = more_count.to_s if more_count > 0
      first.replace(wrapper)
      wrapper.add_child(first)
    end

    doc.to_html(save_with: 0)
  end
end
