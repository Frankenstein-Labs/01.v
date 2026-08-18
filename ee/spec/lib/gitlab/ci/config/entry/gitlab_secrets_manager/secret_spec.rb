# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Entry::GitlabSecretsManager::Secret, feature_category: :secrets_management do
  let(:entry) { described_class.new(config) }

  before do
    entry.compose!
  end

  describe 'validations' do
    context 'when all config value is correct' do
      let(:config) do
        {
          name: 'name'
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when name is nil' do
      let(:config) do
        {
          name: nil
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret name can\'t be blank'
      end
    end

    context 'when name contains path traversal characters' do
      %w[secret/../other ../../../sys/health secret/name].each do |invalid_name|
        context "with name '#{invalid_name}'" do
          let(:config) { { name: invalid_name } }

          it { expect(entry).not_to be_valid }

          it 'reports format error' do
            expect(entry.errors)
              .to include "secret name can contain only letters, digits and '_'."
          end
        end
      end
    end

    context 'when name contains other invalid characters' do
      %w[secret-key secret.key secret!].each do |invalid_name|
        context "with name '#{invalid_name}'" do
          let(:config) { { name: invalid_name } }

          it { expect(entry).not_to be_valid }
        end
      end
    end

    context 'when name contains only valid characters' do
      %w[my_secret DB_PASSWORD_123 SECRET a].each do |valid_name|
        context "with name '#{valid_name}'" do
          let(:config) { { name: valid_name } }

          it { expect(entry).to be_valid }
        end
      end
    end

    context 'when there is an unknown key present' do
      let(:config) { { foo: :bar } }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include "secret name can't be blank"
      end
    end

    context 'when config is not a hash' do
      let(:config) { "" }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret config should be a hash'
      end
    end
  end

  describe '#value' do
    context 'when config has only name' do
      let(:config) do
        {
          name: 'name'
        }
      end

      let(:result) do
        {
          name: "name"
        }
      end

      it 'returns config without source' do
        expect(entry.value).to eq(result)
      end
    end

    context 'when config has name and source with project' do
      let(:config) do
        {
          name: 'secret_name',
          source: 'project'
        }
      end

      let(:result) do
        {
          name: 'secret_name',
          source: 'project'
        }
      end

      it 'returns config with source' do
        expect(entry.value).to eq(result)
      end
    end

    context 'when config has name and source with group path' do
      let(:config) do
        {
          name: 'secret_name',
          source: 'group/my_group'
        }
      end

      let(:result) do
        {
          name: 'secret_name',
          source: 'group/my_group'
        }
      end

      it 'returns config with group source' do
        expect(entry.value).to eq(result)
      end
    end

    context 'when source is nil' do
      let(:config) do
        {
          name: 'secret_name',
          source: nil
        }
      end

      let(:result) do
        {
          name: 'secret_name'
        }
      end

      it 'returns config without source key' do
        expect(entry.value).to eq(result)
      end
    end
  end

  describe 'source validation' do
    context 'when source is project' do
      let(:config) do
        {
          name: 'password',
          source: 'project'
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when source is group with valid group_path' do
      let(:config) do
        {
          name: 'password',
          source: 'group/my_group_path_123'
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when source is invalid format' do
      let(:config) do
        {
          name: 'password',
          source: 'invalid_format'
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include "secret source must follow the format group/group_full_path or 'project'"
      end
    end

    context 'when source is group without group_path' do
      let(:config) do
        {
          name: 'password',
          source: 'group/'
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include "secret source must follow the format group/group_full_path or 'project'"
      end
    end

    context 'when source is group with non alphanumeric group path' do
      let(:config) do
        {
          name: 'password',
          source: 'group/abc def'
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include "secret source must follow the format group/group_full_path or 'project'"
      end
    end

    context 'when source is group with nested path (full_path format)' do
      let(:config) do
        {
          name: 'password',
          source: 'group/parent_group/child_group'
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when source is nil' do
      let(:config) do
        {
          name: 'password',
          source: nil
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when source is not provided' do
      let(:config) do
        {
          name: 'password'
        }
      end

      it { expect(entry).to be_valid }
    end
  end

  describe 'allowed_keys validation' do
    context 'when unknown key is present' do
      let(:config) do
        {
          name: 'password',
          source: 'project',
          unknown_key: 'value'
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret config contains unknown keys: unknown_key'
      end
    end

    context 'when multiple unknown keys are present' do
      let(:config) do
        {
          name: 'password',
          unknown_key1: 'value1',
          unknown_key2: 'value2'
        }
      end

      it { expect(entry).not_to be_valid }
    end
  end

  describe 'group accessibility validation' do
    let(:entry) { described_class.new(config, project: project) }

    before do
      entry.compose!
    end

    context 'when project belongs to a group hierarchy' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: root_group) }
      let_it_be(:project) { create(:project, group: child_group) }
      let_it_be(:unrelated_group) { create(:group) }

      context 'when source group is an ancestor of the project' do
        let(:config) do
          {
            name: 'password',
            source: "group/#{root_group.full_path}"
          }
        end

        it { expect(entry).to be_valid }
      end

      context 'when source group is the direct parent of the project' do
        let(:config) do
          {
            name: 'password',
            source: "group/#{child_group.full_path}"
          }
        end

        it { expect(entry).to be_valid }
      end

      context 'when source group is not accessible to the project' do
        let(:config) do
          {
            name: 'password',
            source: "group/#{unrelated_group.full_path}"
          }
        end

        it { expect(entry).not_to be_valid }

        it 'reports error' do
          expect(entry.errors)
            .to include "secret source group with path '#{unrelated_group.full_path}' not found"
        end
      end

      context 'when source group does not exist' do
        let(:config) do
          {
            name: 'password',
            source: 'group/non_existent_group'
          }
        end

        it { expect(entry).not_to be_valid }

        it 'reports error' do
          expect(entry.errors)
            .to include "secret source group with path 'non_existent_group' not found"
        end
      end
    end

    context 'when project does not belong to a group' do
      let_it_be(:project) { create(:project) }
      let_it_be(:some_group) { create(:group) }

      let(:config) do
        {
          name: 'password',
          source: "group/#{some_group.full_path}"
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include "secret source group with path '#{some_group.full_path}' not found"
      end
    end

    context 'when project is not provided in metadata' do
      let(:entry) { described_class.new(config) }
      let(:config) do
        {
          name: 'password',
          source: 'group/some_group'
        }
      end

      it 'skips the validation' do
        expect(entry).to be_valid
      end
    end

    context 'when source is project' do
      let_it_be(:project) { create(:project) }

      let(:config) do
        {
          name: 'password',
          source: 'project'
        }
      end

      it 'does not run group accessibility validation' do
        expect(entry).to be_valid
      end
    end

    context 'when source is group/ with blank group path' do
      let_it_be(:project) { create(:project, group: create(:group)) }

      let(:config) do
        {
          name: 'password',
          source: 'group/'
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports format error' do
        expect(entry.errors)
          .to include "secret source must follow the format group/group_full_path or 'project'"
      end
    end
  end
end
