# frozen_string_literal: true

# name: highest-post
# about: Adds highest_post_excerpt to TopicListItem serializer
# version: 0.0.4
# authors: dsims (updated by Don)
# url: https://github.com/dsims/discourse-highest-post
# required_version: 3.6.0

enabled_site_setting :highest_post_enabled

after_initialize do
  ##
  # Extend Topic with a has_one association for highest_post
  #
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

  ##
  # Serializer: highest_post_excerpt
  #
  # Uses PrettyText.excerpt with the new Discourse option `keep_images: true`
  # This ensures images stay in the excerpt instead of being stripped or replaced.
  #
  add_to_serializer(:topic_list_item, :highest_post_excerpt) do
    post = object.highest_post
    next nil unless post

    PrettyText.excerpt(
      post.cooked,
      length: SiteSetting.post_excerpt_maxlength,
      keep_images: true,
    )
  end

  ##
  # Ensure the serializer field is included
  #
  add_to_serializer(:topic_list_item, :include_highest_post_excerpt?) do
    SiteSetting.highest_post_enabled
  end
end
