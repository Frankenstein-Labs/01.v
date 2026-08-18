# frozen_string_literal: true

module Ai
  module DuoWorkflows
    # A WebHook subtype used to deliver Duo flow lifecycle callbacks to an
    # external client that registered it (see API::Ai::DuoWorkflows::FlowCallbacks)
    # and referenced its id via `callback_hook_id` when triggering a flow.
    # Reusing the WebHook model (rather than a bespoke poster) buys us, for free:
    #
    #   * encryption at rest for the callback URL and secret (attr_encrypted),
    #   * SSRF protection + local-request policy on delivery,
    #   * delivery logging (WebHookLog),
    #   * signature/idempotency headers via WebHookService.
    #
    # Organization-scoped (like SystemHook) to satisfy the web_hooks
    # num_nonnulls(group_id, organization_id, project_id) = 1 check without a new
    # column. The hook is looked up by id from the workflow's
    # messaging_callback_context, so it does not need to appear in any project's
    # webhook UI.
    class FlowCallbackHook < WebHook
      self.allow_legacy_sti_class = true

      has_many :web_hook_logs, foreign_key: 'web_hook_id', inverse_of: :web_hook

      belongs_to :organization, class_name: 'Organizations::Organization'

      validates :organization_id, presence: true

      scope :for_organization, ->(organization_id) { where(organization_id: organization_id) }
      scope :recent_first, -> { order(id: :desc) }

      def pluralized_name
        _('Duo flow callback hooks')
      end

      def parent
        organization
      end

      def application_context
        super.merge(organization: organization)
      end
    end
  end
end
