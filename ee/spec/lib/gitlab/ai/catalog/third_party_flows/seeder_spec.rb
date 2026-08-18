# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ai::Catalog::ThirdPartyFlows::Seeder, feature_category: :workflow_catalog do
  let_it_be(:default_organization) { create(:organization) }

  before do
    allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  describe '.run!' do
    it 'creates a new instance and calls run!' do
      seeder = instance_double(described_class)
      allow(seeder).to receive(:run!)
      allow(described_class).to receive(:new).and_return(seeder)

      described_class.run!

      expect(described_class).to have_received(:new)
      expect(seeder).to have_received(:run!)
    end
  end

  describe '#agents' do
    let(:seeder) { described_class.new }

    let(:claude_definition) { seeder.agents.find { |a| a[:name] == 'Claude Agent by GitLab' }[:definition] }
    let(:codex_definition) { seeder.agents.find { |a| a[:name] == 'Codex Agent by GitLab' }[:definition] }

    let(:install_command) { ::Gitlab::DuoWorkflow::GlabSetup.install_command }
    let(:path_command) { %(export PATH="#{::Gitlab::DuoWorkflow::GlabSetup::GLAB_BIN_DIR}:$PATH") }

    def commands_in(yaml_definition)
      YAML.safe_load(yaml_definition, permitted_classes: [], aliases: false)['commands']
    end

    it 'installs glab with the command shared with the Duo Agent Platform workloads' do
      commands = [claude_definition, codex_definition].map { |definition| commands_in(definition) }

      expect(commands).to all(include(a_string_starting_with(install_command)).and(include(path_command)))
    end

    # The documented examples are copied from these definitions, so a version
    # bump that leaves the docs behind would ship an outdated install command.
    it 'matches the flow examples in the documentation' do
      doc = Rails.root.join('doc/user/duo_agent_platform/agents/external_examples.md').read
      examples = doc.scan(/```yaml\n(.*?)```/m).flatten.map { |block| commands_in(block) }

      expect(examples.size).to eq(2)
      expect(examples).to all(include(a_string_starting_with(install_command)).and(include(path_command)))
    end

    context 'when not running in development' do
      it 'uses the production AI Gateway proxy URLs' do
        expect(claude_definition)
          .to include('ANTHROPIC_BASE_URL="https://cloud.gitlab.com/ai/v1/proxy/anthropic"')
        expect(codex_definition)
          .to include('model_providers.gitlab.base_url="https://cloud.gitlab.com/ai/v1/proxy/openai/v1"')
      end
    end

    context 'when running in development' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(::Gitlab::AiGateway).to receive(:url).and_return('http://gdk.test:5052')
      end

      it 'uses the locally-configured AI Gateway proxy URLs' do
        expect(claude_definition)
          .to include('ANTHROPIC_BASE_URL="http://gdk.test:5052/v1/proxy/anthropic"')
        expect(codex_definition)
          .to include('model_providers.gitlab.base_url="http://gdk.test:5052/v1/proxy/openai/v1"')
      end
    end
  end

  describe '#run!' do
    let(:seeder) { described_class.new }

    context 'when all conditions are met' do
      it 'seeds external agents successfully' do
        expect { seeder.run! }.to change { Ai::Catalog::Item.count }.by(2)
          .and change { Ai::Catalog::ItemVersion.count }.by(2)
      end

      it 'creates items with correct attributes' do
        claude_definition = seeder.agents.find { |a| a[:name] == 'Claude Agent by GitLab' }
        codex_definition = seeder.agents.find { |a| a[:name] == 'Codex Agent by GitLab' }

        seeder.run!

        items = Ai::Catalog::Item.where(
          organization: default_organization,
          project: nil,
          item_type: Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE,
          verification_level: :gitlab_maintained,
          visibility: :public
        )

        expect(items.count).to eq(2)

        claude_agent = items.find_by_name(claude_definition[:name])
        codex_agent = items.find_by_name(codex_definition[:name])

        expect(claude_agent).to be_present
        expect(codex_agent).to be_present

        expect(claude_agent.latest_version).to have_attributes(
          schema_version: Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION,
          version: Ai::Catalog::BaseService::DEFAULT_VERSION,
          release_date: be_present,
          definition: YAML.load(
            claude_definition[:definition]
          ).merge('yaml_definition' => claude_definition[:definition])
        )

        expect(codex_agent.latest_version).to have_attributes(
          schema_version: Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION,
          version: Ai::Catalog::BaseService::DEFAULT_VERSION,
          release_date: be_present,
          definition: YAML.load(
            codex_definition[:definition]
          ).merge('yaml_definition' => codex_definition[:definition])
        )
      end

      it 'sets latest_released_version correctly' do
        seeder.run!

        Ai::Catalog::Item.where(organization: default_organization).find_each do |item|
          expect(item.latest_released_version).to eq(item.latest_version)
        end
      end

      it 'outputs success message' do
        expect { seeder.run! }.to output(/Completed successfully/).to_stdout
      end
    end

    it 'raises an error if the seed script has already run' do
      seeder.run!

      expect { seeder.run! }.to raise_error("Error: External agents already seeded")
    end

    it 'does not raise an error if other data is already in the catalog' do
      create(:ai_catalog_third_party_flow)
      expect { seeder.run! }.to output(/Completed successfully/).to_stdout
    end

    context 'when running on production SaaS', :saas do
      it 'raises an error' do
        expect { seeder.run! }.to raise_error("Error: Cannot be run on production GitLab SaaS environments")
      end

      context 'and running in development' do
        before do
          allow(Rails.env).to receive(:development?).and_return(true)
        end

        it 'runs without raising an error' do
          expect { seeder.run! }.to output(/Completed successfully/).to_stdout
        end
      end
    end

    context 'when organization is not found' do
      before do
        allow(Organizations::Organization).to receive(:default_organization).and_return(nil)
      end

      it 'raises an error' do
        seeder = described_class.new
        expect { seeder.run! }.to raise_error("Error: no organization found on instance")
      end
    end

    context 'when ai_catalog_third_party_flows feature flag is disabled' do
      before do
        stub_feature_flags(ai_catalog_third_party_flows: false)
      end

      it 'raises an error' do
        expect { seeder.run! }.to raise_error("Error: ai_catalog_third_party_flows feature flag must be enabled")
      end
    end

    context 'when item save fails' do
      before do
        allow_next_instance_of(Ai::Catalog::Item) do |item|
          allow(item).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
        end
      end

      it 'raises the error' do
        expect { seeder.run! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
