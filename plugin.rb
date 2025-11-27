# frozen_string_literal: true

# name: highest-post
# about: Adds highest_post_excerpt to TopicListItem serializer
# version: 0.0.5
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

    PrettyText.excerpt(
      post.cooked,
      SiteSetting.post_excerpt_maxlength,
      strip_links: true,
      strip_details: true,
      keep_images: true
    )
  end
end
