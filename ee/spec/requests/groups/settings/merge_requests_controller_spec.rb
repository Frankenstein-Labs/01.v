# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::MergeRequestsController, feature_category: :code_review_workflow do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:admin) }

  before do
    sign_in(user)
    stub_licensed_features(group_level_merge_checks_setting: true)
    group.add_owner(user)
  end

  describe 'PATCH #update' do
    subject do
      patch group_settings_merge_requests_path(group), params: {
        group_id: group,
        namespace_setting: {
          only_allow_merge_if_pipeline_succeeds: true,
          allow_merge_on_skipped_pipeline: true,
          only_allow_merge_if_all_discussions_are_resolved: true,
          allow_merge_without_pipeline: true,
          auto_duo_code_review_enabled: true
        }
      }
    end

    before do
      allow_next_found_instance_of(Group) do |instance|
        allow(instance).to receive(:auto_duo_code_review_settings_available?).and_return(true)
      end
    end

    it 'persists EE-specific merge request settings', :aggregate_failures do
      subject

      expect(group.namespace_settings.reload).to have_attributes(
        only_allow_merge_if_pipeline_succeeds: true,
        allow_merge_on_skipped_pipeline: true,
        only_allow_merge_if_all_discussions_are_resolved: true,
        allow_merge_without_pipeline: true,
        auto_duo_code_review_enabled: true
      )
    end
  end
end
