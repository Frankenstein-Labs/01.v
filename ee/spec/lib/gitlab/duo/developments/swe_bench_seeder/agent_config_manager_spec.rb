# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::AgentConfigManager, feature_category: :duo_chat do
  let(:user) { instance_double(User) }
  let(:repository) do
    instance_double(Repository, root_ref: 'main', commit: head_commit, blob_at: nil)
  end

  let(:head_commit) { double(sha: 'abc123') } # rubocop:disable RSpec/VerifiedDoubles -- sha is delegated via method_missing
  let(:project) do
    instance_double(Project, repository: repository, default_branch_or_main: 'main').tap do |p|
      allow(p).to receive(:reset).and_return(p)
    end
  end

  describe '.swebench_image_for' do
    context 'when instance_id contains double underscore' do
      it 'returns the formatted image path' do
        result = described_class.swebench_image_for('django__django-13112')
        expect(result).to eq(
          'registry.gitlab.com/gitlab-org/modelops/ai-model-validation-and-research/' \
            'ai-evaluation/swebench-images/prebaked/sweb.eval.x86_64.django_1776_django-13112:prebaked-v1'
        )
      end
    end

    context 'when instance_id does not contain double underscore' do
      it 'returns nil' do
        expect(described_class.swebench_image_for('simple-id')).to be_nil
      end
    end

    context 'when instance_id is nil' do
      it 'returns nil' do
        expect(described_class.swebench_image_for(nil)).to be_nil
      end
    end

    context 'when instance_id is empty string' do
      it 'returns nil' do
        expect(described_class.swebench_image_for('')).to be_nil
      end
    end
  end

  describe '.commit_agent_config' do
    let(:instance_id) { 'django__django-13112' }
    let(:config_content) { { 'key' => 'value' } }

    before do
      allow(described_class).to receive_messages(
        swebench_image_for: 'test-image',
        agent_config: config_content
      )
    end

    context 'when config is nil' do
      before do
        allow(described_class).to receive(:agent_config).and_return(nil)
      end

      it 'returns early without committing' do
        expect(repository).not_to receive(:create_file)
        expect(repository).not_to receive(:update_file)
        described_class.commit_agent_config(project, user, instance_id: instance_id)
      end
    end

    context 'when file does not exist' do
      before do
        allow(repository).to receive(:blob_at).and_return(nil)
        allow(repository).to receive(:create_file)
      end

      it 'creates the file' do
        expect(repository).to receive(:create_file).with(
          user,
          '.gitlab/duo/agent-config.yml',
          anything,
          hash_including(message: 'Add SWE-bench environment configuration for Duo flows', branch_name: 'main')
        )
        expect { described_class.commit_agent_config(project, user, instance_id: instance_id) }
          .to output(%r{Committed .gitlab/duo/agent-config.yml}).to_stdout
      end
    end

    context 'when file already exists' do
      let(:existing_blob) { instance_double(Blob) }

      before do
        allow(repository).to receive(:blob_at).with('abc123', '.gitlab/duo/agent-config.yml').and_return(existing_blob)
        allow(repository).to receive(:update_file)
      end

      it 'updates the file' do
        expect(repository).to receive(:update_file).with(
          user,
          '.gitlab/duo/agent-config.yml',
          anything,
          hash_including(message: 'Update SWE-bench environment configuration for Duo flows', branch_name: 'main')
        )
        expect { described_class.commit_agent_config(project, user, instance_id: instance_id) }
          .to output(%r{Updated .gitlab/duo/agent-config.yml}).to_stdout
      end
    end

    context 'when root_ref is nil' do
      before do
        allow(repository).to receive_messages(root_ref: nil, blob_at: nil)
        allow(repository).to receive(:create_file)
      end

      it 'uses default_branch_or_main' do
        expect(repository).to receive(:create_file).with(
          user,
          '.gitlab/duo/agent-config.yml',
          anything,
          hash_including(branch_name: 'main')
        )
        described_class.commit_agent_config(project, user, instance_id: instance_id)
      end
    end

    context 'when head_commit is nil' do
      before do
        allow(repository).to receive(:commit).and_return(nil)
        allow(repository).to receive(:create_file)
      end

      it 'treats as file not existing and creates it' do
        expect(repository).to receive(:create_file)
        described_class.commit_agent_config(project, user, instance_id: instance_id)
      end
    end
  end

  describe '.agent_config' do
    let(:config_path) { described_class::AGENT_CONFIG_PATH }
    let(:base_config) { { 'timeout' => 300, 'retries' => 3 } }

    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(config_path).and_return(YAML.dump(base_config))
    end

    context 'when image is provided' do
      it 'includes the image in the config' do
        result = described_class.agent_config(image: 'test-image:v1')
        expect(result['image']).to eq('test-image:v1')
        expect(result['timeout']).to eq(300)
      end
    end

    context 'when image is nil' do
      it 'does not add image to config' do
        result = described_class.agent_config(image: nil)
        expect(result).not_to have_key('image')
        expect(result['timeout']).to eq(300)
      end
    end

    context 'when image is blank' do
      it 'does not add image to config' do
        result = described_class.agent_config(image: '')
        expect(result).not_to have_key('image')
      end
    end

    context 'when config file is empty' do
      before do
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(config_path).and_return('')
      end

      it 'returns empty hash' do
        result = described_class.agent_config(image: nil)
        expect(result).to eq({})
      end
    end
  end
end
