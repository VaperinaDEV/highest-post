# frozen_string_literal: true
# name: highest-post
# about: Adds highest_post_excerpt to TopicListItem serializer
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
  register_topic_preloader_associations(:highest_post)

  add_to_serializer(
    :topic_list_item,
    :highest_post_excerpt,
    include_condition: -> { SiteSetting.highest_post_enabled }
  ) do
    post = object.highest_post
    next nil unless post

    cooked_to_use = post.cooked

    # discourse-ai content localization support (safe, no crash if absent)
    begin
      if SiteSetting.respond_to?(:content_localization_enabled) &&
         SiteSetting.content_localization_enabled &&
         post.respond_to?(:post_localizations)
        current_locale = scope&.user&.locale.presence || SiteSetting.default_locale
        localization = post.post_localizations.find { |l| l.locale == current_locale }
        cooked_to_use = localization.cooked if localization&.cooked.present?
      end
    rescue => e
      Rails.logger.warn("HighestPost: localization lookup failed: #{e.message}")
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
