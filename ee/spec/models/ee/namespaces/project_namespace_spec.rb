# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ProjectNamespace, feature_category: :groups_and_projects do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:project_namespace) { project.project_namespace }

  describe '#licensed_feature_available?' do
    it 'delegates to the associated project' do
      expect(project).to receive(:licensed_feature_available?).with(:some_feature)

      project_namespace.licensed_feature_available?(:some_feature)
    end

    context 'with namespaced plans', :saas do
      before do
        stub_licensed_features(epic_colors: true)

        allow(Gitlab::CurrentSettings.current_application_settings)
          .to receive(:should_check_namespace_plan?).and_return(true)

        create(:gitlab_subscription, :ultimate, namespace: group)
      end

      it 'checks the parent group license' do
        expect(project_namespace.licensed_feature_available?(:epic_colors)).to be(true)
      end
    end
  end
end
