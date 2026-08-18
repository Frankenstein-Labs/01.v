# frozen_string_literal: true

module EE
  module VisibilityLevelHelper
    include SafeFormatHelper
    extend ::Gitlab::Utils::Override

    private

    override :group_public_visibility_description
    def group_public_visibility_description(group)
      # sometimes this method is called without a group and in that case we can just return super
      return super unless group && !group.new_record? && ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      help_link = link_to('', help_page_path('user/free_user_limit.md'), target: '_blank', rel: 'noopener noreferrer')
      billing_link = link_to('', group_billings_path(group), target: '_blank', rel: 'noopener noreferrer')
      safe_format(
        s_(
          'VisibilityLevel|The group, any public projects, and any of their members, issues, ' \
            'and merge requests can be viewed without authentication. ' \
            'Public groups and projects will be indexed by search engines. ' \
            'Read more about %{help_link_start}free user limits%{help_link_end}, ' \
            'or %{billing_link_start}upgrade to a paid tier%{billing_link_end}.'
        ),
        tag_pair(help_link, :help_link_start, :help_link_end),
        tag_pair(billing_link, :billing_link_start, :billing_link_end)
      )
    end
  end
end
