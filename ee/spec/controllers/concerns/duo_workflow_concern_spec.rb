# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DuoWorkflowConcern, feature_category: :duo_agent_platform do
  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:user) }

  subject(:instance) do
    Class.new do
      include DuoWorkflowConcern

      attr_accessor :project, :current_user

      def initialize(project, current_user)
        @project = project
        @current_user = current_user
      end
    end.new(project, user)
  end

  describe '#duo_workflow_enabled?' do
    before do
      allow(project).to receive_messages(duo_remote_flows_enabled: true, duo_features_enabled: true)
      allow(Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(true)
    end

    it 'returns true when all conditions are met' do
      expect(instance.duo_workflow_enabled?(project)).to be true
    end

    it 'returns false when duo_agent_platform_available? is false' do
      allow(Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(false)
      expect(instance.duo_workflow_enabled?(project)).to be false
    end

    it 'returns false when duo_remote_flows_enabled is false' do
      allow(project).to receive(:duo_remote_flows_enabled).and_return(false)
      expect(instance.duo_workflow_enabled?(project)).to be false
    end

    it 'returns false when duo_features_enabled is set to false' do
      allow(project).to receive(:duo_features_enabled).and_return(false)
      expect(instance.duo_workflow_enabled?).to be false
    end

    it 'returns false when project is nil' do
      allow(instance).to receive(:project).and_return(nil)
      expect(instance.duo_workflow_enabled?).to be false
    end

    it 'returns false when user is nil' do
      allow(instance).to receive(:current_user).and_return(nil)
      expect(instance.duo_workflow_enabled?(project)).to be false
    end

    it 'uses provided project and user parameters' do
      custom_project = build_stubbed(:project)
      custom_user = build_stubbed(:user)
      allow(custom_project).to receive_messages(duo_remote_flows_enabled: true, duo_features_enabled: true)
      allow(Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(custom_project).and_return(true)

      expect(instance.duo_workflow_enabled?(custom_project, custom_user)).to be true
    end
  end
end
