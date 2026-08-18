# frozen_string_literal: true

module EE
  module IssuablePolicy
    extend ActiveSupport::Concern

    prepended do
      condition(:is_author) do
        @user && @subject.author_id == @user.id
      end

      condition(:amazon_q_integration_enabled) do
        ::Ai::AmazonQ.enabled?
      end

      with_scope :subject
      condition(:issuable_resource_links_available) do
        @subject.issuable_resource_links_available?
      end

      condition(:user_allowed_to_measure_comment_temperature) do
        ::Feature.enabled?(:comment_temperature, @user) &&
          ::Gitlab::Llm::FeatureAuthorizer.new(
            container: subject_container,
            feature_name: :measure_comment_temperature,
            user: @user
          ).allowed?
      end

      rule { user_allowed_to_measure_comment_temperature }.policy do
        enable :measure_comment_temperature
      end

      rule { can?(:read_issue) }.policy do
        enable :read_issuable_metric_image
      end

      rule { can?(:create_issue) & can?(:update_issue) }.policy do
        enable :upload_issuable_metric_image
      end

      rule { is_author | (can?(:create_issue) & can?(:update_issue)) }.policy do
        enable :update_issuable_metric_image
        enable :delete_issuable_metric_image
      end

      rule { ~is_container_member }.policy do
        prevent :upload_issuable_metric_image
        prevent :update_issuable_metric_image
        prevent :delete_issuable_metric_image
      end

      rule { ~can?(:read_issue) | ~issuable_resource_links_available }.policy do
        prevent :admin_issuable_resource_link
        prevent :read_issuable_resource_link
      end

      rule { ~amazon_q_integration_enabled | ~can?(:access_duo_features) }.policy do
        prevent :trigger_amazon_q
      end
    end
  end
end
