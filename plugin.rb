# frozen_string_literal: true

# name: highest-post
# about: Adds highest_post_excerpt to TopicListItem serializer
# version: 0.0.7
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

    html = PrettyText.excerpt(
      post.cooked,
      SiteSetting.post_excerpt_maxlength,
      keep_images: true,
      strip_links: true,
      strip_details: true
    )

    doc = Nokogiri::HTML::fragment(html)
    imgs = doc.css("img:not(.emoji)")

    imgs.each do |img|
      img.remove_attribute("title")
    end

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
