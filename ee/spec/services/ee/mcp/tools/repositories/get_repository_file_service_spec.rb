# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Repositories::GetRepositoryFileService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository) }

  let(:service) { described_class.new(name: 'get_repository_file', version: '0.1.0') }
  let(:ref) { project.default_branch }

  before_all do
    project.add_developer(user)
  end

  before do
    service.set_cred(current_user: user)
  end

  def call(file_path)
    service.execute(params: { arguments: { 'project_id' => project.full_path,
                                           'file_path' => file_path, 'ref' => ref } })
  end

  def set_exclusion_rules(rules)
    project.project_setting.update!(duo_context_exclusion_settings: { 'exclusion_rules' => rules })
  end

  context 'when the project has no exclusion rules' do
    it 'returns the file' do
      expect(call('README.md')[:isError]).to be_falsey
    end
  end

  context 'when the path matches an exclusion rule' do
    before do
      set_exclusion_rules(['*.md'])
    end

    it 'refuses to return the file' do
      result = call('README.md')

      expect(result[:isError]).to be true
      expect(result[:content].first[:text]).to include('is excluded from AI context')
    end

    it 'does not read the blob' do
      expect(::Gitlab::Git::Blob).not_to receive(:find)

      call('README.md')
    end

    it 'still returns a file that does not match' do
      expect(call('files/ruby/popen.rb')[:isError]).to be_falsey
    end
  end

  context 'when a negation rule re-includes the path' do
    before do
      set_exclusion_rules(['*.md', '!README.md'])
    end

    it 'returns the file' do
      expect(call('README.md')[:isError]).to be_falsey
    end
  end

  context 'when the rule matches a directory glob' do
    before do
      set_exclusion_rules(['files/ruby/*'])
    end

    it 'refuses to return a file inside it' do
      expect(call('files/ruby/popen.rb')[:isError]).to be true
    end
  end
end
