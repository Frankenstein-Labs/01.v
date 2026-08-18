# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HooksHelper, feature_category: :integrations do
  let(:group) { build_stubbed(:group) }
  let(:project) { build_stubbed(:project) }
  let(:group_hook) { build_stubbed(:group_hook, group: group) }
  let(:project_hook) { build_stubbed(:project_hook, project: project) }
  let(:trigger) { 'push_events' }

  describe '#test_hook_path' do
    it 'returns group namespaced link' do
      expect(helper.test_hook_path(group_hook, trigger))
        .to eq(test_group_hook_path(group, group_hook, trigger: trigger))
    end
  end

  describe '#hook_log_path' do
    context 'with a group hook' do
      let(:web_hook_log) { build_stubbed(:web_hook_log, web_hook: group_hook) }

      it 'returns group-namespaced link' do
        expect(helper.hook_log_path(group_hook, web_hook_log))
          .to eq(web_hook_log.present.details_path)
      end
    end
  end

  describe '#webhook_form_data' do
    it 'includes vulnerability_events in triggers' do
      result = helper.webhook_form_data(group_hook)
      expected_triggers = ::Gitlab::Json.parse(result[:triggers])
      expect(expected_triggers).to include('vulnerability_events' => group_hook.vulnerability_events)
    end

    it 'includes group event triggers for group hooks' do
      result = helper.webhook_form_data(group_hook)
      triggers = ::Gitlab::Json.parse(result[:triggers])

      expect(triggers).to include('member_events', 'project_events', 'subgroup_events')
    end

    it 'excludes group event triggers for project hooks' do
      result = helper.webhook_form_data(project_hook)
      triggers = ::Gitlab::Json.parse(result[:triggers])
      expect(triggers).not_to include('member_events', 'project_events', 'subgroup_events')
    end
  end
end
