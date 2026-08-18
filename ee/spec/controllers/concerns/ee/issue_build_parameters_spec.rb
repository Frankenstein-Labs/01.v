# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::IssueBuildParameters, feature_category: :team_planning do
  let(:user) { instance_double(User) }
  let(:group) { instance_double(Group) }
  let(:project) do
    instance_double(
      Project,
      group: group,
      licensed_feature_available?: false
    )
  end

  let(:vulnerability) { instance_double(Vulnerability, title: 'Test Vulnerability') }

  let(:controller_class) do
    Class.new do
      include IssueBuildParameters
      include EE::IssueBuildParameters

      attr_reader :current_user, :project, :params_hash

      def initialize(current_user, project, params_hash)
        @current_user = current_user
        @project = project
        @params_hash = params_hash
      end

      def params
        ActionController::Parameters.new(@params_hash)
      end

      # rubocop: disable Gitlab/PredicateMemoization -- mock behavior
      def can?(user, ability, resource)
        @can_abilities ||= {}
        @can_abilities[[user, ability, resource]] ||= false
      end
      # rubocop: enable Gitlab/PredicateMemoization

      def vulnerability
        @vulnerability ||= nil
      end

      attr_reader :vulnerability_id

      def render_vulnerability_description
        "Vulnerability description content"
      end

      def set_vulnerability_id(id)
        @vulnerability_id = id
      end

      def set_vulnerability(vuln)
        @vulnerability = vuln
      end
    end
  end

  subject(:issue_build_params) { controller_class.new(user, project, params_hash) }

  describe '#issue_attributes' do
    let(:params_hash) { {} }

    before do
      allow(WorkItems::TypesFramework::Provider).to receive(:unfiltered_base_types_for_issues).and_return(%w[issue
        incident task])
    end

    context 'without any EE licenses' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(false)
        allow(group).to receive(:feature_available?).with(:epics).and_return(false)
        allow(group).to receive(:feature_available?).with(:iterations).and_return(false)
      end

      it 'returns base attributes only' do
        attributes = issue_build_params.issue_attributes

        expect(attributes).to include(:title, :description, :assignee_id, :confidential)
        expect(attributes).not_to include(:weight)
        expect(attributes).not_to include(:epic_id)
        expect(attributes).not_to include(:sprint_id)
      end
    end

    context 'with issue_weights license available' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(true)
        allow(group).to receive(:feature_available?).with(:epics).and_return(false)
        allow(group).to receive(:feature_available?).with(:iterations).and_return(false)
      end

      it 'includes weight in attributes' do
        attributes = issue_build_params.issue_attributes

        expect(attributes).to include(:weight)
      end
    end

    context 'with epics feature available' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(false)
        allow(group).to receive(:feature_available?).with(:epics).and_return(true)
        allow(group).to receive(:feature_available?).with(:iterations).and_return(false)
      end

      it 'includes epic_id in attributes' do
        attributes = issue_build_params.issue_attributes

        expect(attributes).to include(:epic_id)
      end
    end

    context 'with iterations feature available' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(false)
        allow(group).to receive(:feature_available?).with(:epics).and_return(false)
        allow(group).to receive(:feature_available?).with(:iterations).and_return(true)
      end

      it 'includes sprint_id in attributes' do
        attributes = issue_build_params.issue_attributes

        expect(attributes).to include(:sprint_id)
      end
    end

    context 'with all EE features available' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(true)
        allow(group).to receive(:feature_available?).with(:epics).and_return(true)
        allow(group).to receive(:feature_available?).with(:iterations).and_return(true)
      end

      it 'includes weight, epic_id, and sprint_id in attributes' do
        attributes = issue_build_params.issue_attributes

        expect(attributes).to include(:weight)
        expect(attributes).to include(:epic_id)
        expect(attributes).to include(:sprint_id)
      end

      it 'includes EE attributes before base attributes' do
        attributes = issue_build_params.issue_attributes

        expect(attributes.first).to eq(:sprint_id)
        expect(attributes.second).to eq(:epic_id)
        expect(attributes.third).to eq(:weight)
      end
    end

    context 'when project has no group' do
      let(:project) do
        instance_double(
          Project,
          group: nil,
          licensed_feature_available?: false
        )
      end

      before do
        allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(true)
      end

      it 'does not include epic_id or sprint_id but includes weight' do
        attributes = issue_build_params.issue_attributes

        expect(attributes).to include(:weight)
        expect(attributes).not_to include(:epic_id)
        expect(attributes).not_to include(:sprint_id)
      end
    end
  end

  describe '#issue_params' do
    before do
      allow(WorkItems::TypesFramework::Provider).to receive(:unfiltered_base_types_for_issues).and_return(%w[issue
        incident task])
      allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(false)
      allow(group).to receive(:feature_available?).with(:epics).and_return(false)
      allow(group).to receive(:feature_available?).with(:iterations).and_return(false)
    end

    context 'without vulnerability_id' do
      let(:params_hash) do
        {
          issue: {
            title: 'Test Issue',
            description: 'Test Description'
          }
        }
      end

      it 'returns params without vulnerability modifications' do
        result = issue_build_params.issue_params

        expect(result[:title]).to eq('Test Issue')
        expect(result[:description]).to eq('Test Description')
      end
    end

    context 'with vulnerability_id present' do
      let(:params_hash) do
        {
          vulnerability_id: '123',
          issue: {
            title: 'Custom Title',
            description: 'Custom Description'
          }
        }
      end

      before do
        issue_build_params.set_vulnerability_id('123')
        issue_build_params.set_vulnerability(vulnerability)
        allow(vulnerability).to receive(:title).and_return('Security Issue')
      end

      it 'merges vulnerability title as default when not provided' do
        params_hash[:issue].delete(:title)
        issue_build_params.set_vulnerability_id('123')

        result = issue_build_params.issue_params

        expect(result[:title]).to include('Investigate vulnerability:')
        expect(result[:title]).to include('Security Issue')
      end

      it 'prefers user-provided title over vulnerability title' do
        result = issue_build_params.issue_params

        expect(result[:title]).to eq('Custom Title')
      end

      it 'merges vulnerability description as default when not provided' do
        params_hash[:issue].delete(:description)
        issue_build_params.set_vulnerability_id('123')

        result = issue_build_params.issue_params

        expect(result[:description]).to eq('Vulnerability description content')
      end

      it 'prefers user-provided description over vulnerability description' do
        result = issue_build_params.issue_params

        expect(result[:description]).to eq('Custom Description')
      end

      it 'sets confidential to true by default' do
        params_hash[:issue].delete(:confidential)
        issue_build_params.set_vulnerability_id('123')

        result = issue_build_params.issue_params

        expect(result[:confidential]).to be true
      end

      it 'prefers user-provided confidential value' do
        params_hash[:issue][:confidential] = false
        issue_build_params.set_vulnerability_id('123')

        result = issue_build_params.issue_params

        expect(result[:confidential]).to be false
      end

      it 'formats vulnerability title correctly' do
        issue_build_params.set_vulnerability_id('123')
        params_hash[:issue].delete(:title)

        result = issue_build_params.issue_params

        expect(result[:title]).to eq('Investigate vulnerability: Security Issue')
      end
    end

    context 'with vulnerability_id but missing issue parameter' do
      let(:params_hash) do
        {
          vulnerability_id: '123'
        }
      end

      before do
        issue_build_params.set_vulnerability_id('123')
        issue_build_params.set_vulnerability(vulnerability)
        allow(vulnerability).to receive(:title).and_return('Critical Bug')
      end

      it 'applies vulnerability defaults to empty parameters' do
        result = issue_build_params.issue_params

        expect(result[:title]).to include('Investigate vulnerability:')
        expect(result[:title]).to include('Critical Bug')
        expect(result[:description]).to eq('Vulnerability description content')
        expect(result[:confidential]).to be true
      end
    end

    context 'with all parameters provided including EE attributes' do
      let(:params_hash) do
        {
          vulnerability_id: '456',
          issue: {
            title: 'Full Issue',
            description: 'Full Description',
            weight: 5,
            epic_id: 10,
            sprint_id: 20,
            confidential: true
          }
        }
      end

      before do
        allow(project).to receive(:licensed_feature_available?).with(:issue_weights).and_return(true)
        allow(group).to receive(:feature_available?).with(:epics).and_return(true)
        allow(group).to receive(:feature_available?).with(:iterations).and_return(true)
        issue_build_params.set_vulnerability_id('456')
        issue_build_params.set_vulnerability(vulnerability)
      end

      it 'preserves EE attributes alongside vulnerability parameters' do
        result = issue_build_params.issue_params

        expect(result[:title]).to eq('Full Issue')
        expect(result[:weight]).to eq(5)
        expect(result[:epic_id]).to eq(10)
        expect(result[:sprint_id]).to eq(20)
        expect(result[:confidential]).to be true
      end
    end

    context 'with nil vulnerability_id' do
      let(:params_hash) do
        {
          issue: {
            title: 'Regular Issue'
          }
        }
      end

      it 'does not modify params for vulnerability' do
        result = issue_build_params.issue_params

        expect(result[:title]).to eq('Regular Issue')
        expect(result).not_to include(:vulnerability_title)
      end
    end
  end
end
