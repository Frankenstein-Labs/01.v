# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repository, :elastic, :sidekiq_inline, feature_category: :global_search do
  let_it_be_with_reload(:project) { create :project, :public, :repository }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    index!(project)
  end

  def index!(project)
    project.repository.index_commits_and_blobs

    ensure_elasticsearch_index!
  end

  describe 'searching' do
    let(:options) { { search_level: 'global' } }

    it 'searches blobs' do
      expect(project.repository.elastic_search('def popen', type: 'blob', options: options)[:blobs][:total_count]).to eq(1)
      expect(project.repository.elastic_search('files/ruby/popen.rb', type: 'blob', options: options)[:blobs][:total_count]).to eq(1)
      expect(project.repository.elastic_search('def | popen', type: 'blob', options: options)[:blobs][:total_count] > 1).to be_truthy
    end

    it 'searches commits' do
      expect(project.repository.elastic_search('initial', type: 'commit', options: options)[:commits][:total_count]).to eq(1)

      root_ref = project.repository.root_ref_sha.upcase
      expect(project.repository.elastic_search(root_ref, type: 'commit', options: options)[:commits][:total_count]).to eq(1)

      partial_ref = root_ref[0...5]
      expect(project.repository.elastic_search(partial_ref, type: 'commit', options: options)[:commits][:total_count]).to eq(1)
      expect(project.repository.elastic_search(partial_ref + '*', type: 'commit', options: options)[:commits][:total_count]).to eq(1)
    end
  end

  context 'filtering' do
    it 'can filter blobs' do
      options = { search_level: 'global' }
      # Finds custom-highlighting/test.gitlab-custom
      expect(project.repository.elastic_search('def | popen filename:test', type: 'blob', options: options)[:blobs][:total_count]).to eq(1)

      # Should not find anything, since filename doesn't match on path
      expect(project.repository.elastic_search('def | popen filename:files', type: 'blob', options: options)[:blobs][:total_count]).to eq(0)

      # Finds files/ruby/popen.rb, files/markdown/ruby-style-guide.md, files/ruby/regex.rb, files/ruby/version_info.rb
      expect(project.repository.elastic_search('def | popen path:ruby', type: 'blob', options: options)[:blobs][:total_count]).to eq(4)

      # Finds files/markdown/ruby-style-guide.md
      expect(project.repository.elastic_search('def | popen extension:md', type: 'blob', options: options)[:blobs][:total_count]).to eq(1)

      # Finds files/ruby/popen.rb
      expect(project.repository.elastic_search('* blob:7e3e39ebb9b2bf433b4ad17313770fbe4051649c', type: 'blob', options: options)[:blobs][:total_count]).to eq(1)

      # filename filter without search term
      count = project.repository.ls_files('master').count { |path| path.split('/')[-1].include?('test') }
      expect(project.repository.elastic_search('filename:test', type: 'blob', options: options)[:blobs][:total_count]).to eq(count)
      expect(project.repository.elastic_search('filename:test', type: 'blob', options: options)[:blobs][:total_count]).to be > 0

      # extension filter without search term
      count = project.repository.ls_files('master').count { |path| path.split('/')[-1].split('.')[-1].include?('md') }
      expect(project.repository.elastic_search('extension:md', type: 'blob', options: options)[:blobs][:total_count]).to eq(count)
      expect(project.repository.elastic_search('extension:md', type: 'blob', options: options)[:blobs][:total_count]).to be > 0

      # path filter without search term
      count = project.repository.ls_files('master').count { |path| path.include?('ruby') }
      expect(project.repository.elastic_search('path:ruby', type: 'blob', options: options)[:blobs][:total_count]).to eq(count)
      expect(project.repository.elastic_search('path:ruby', type: 'blob', options: options)[:blobs][:total_count]).to be > 0

      # blob filter without search term
      expect(project.repository.elastic_search('blob:7e3e39ebb9b2bf433b4ad17313770fbe4051649c', type: 'blob', options: options)[:blobs][:total_count]).to eq(1)
    end
  end

  def search_and_check!(on, query, type:, per: 1000)
    results = on.elastic_search(query, type: type, per: per, options: { search_level: 'global' })[:"#{type}s"][:results]

    blobs, commits = results.partition { |result| result['_source']['blob'].present? }

    case type
    when 'blob'
      expect(blobs).not_to be_empty
      expect(commits).to be_empty
    when 'commit'
      expect(blobs).to be_empty
      expect(commits).not_to be_empty
    else
      raise ArgumentError
    end
  end

  # A negation query can match both commits and blobs as they both have _type
  # 'repository'. Ensure this doesn't happen, in both global and project search
  it 'filters commits from blobs, and vice-versa' do
    search_and_check!(described_class, '-foo', type: 'blob')
    search_and_check!(described_class, '-foo', type: 'commit')
    search_and_check!(project.repository, '-foo', type: 'blob')
    search_and_check!(project.repository, '-foo', type: 'commit')
  end

  describe 'class method find_commits_by_message_with_elastic', :sidekiq_might_not_need_inline do
    let_it_be_with_reload(:project2) { create :project, :public, :repository }
    let(:results) { described_class.find_commits_by_message_with_elastic('initial', options: { search_level: 'global' }) }

    before do
      index!(project2)
    end

    it 'returns commits' do
      expect(results).to contain_exactly(instance_of(Commit), instance_of(Commit))
      expect(results.count).to eq(2)
      expect(results.total_count).to eq(2)
    end

    context 'with a deleted project' do
      before do
        # Call DELETE directly to avoid triggering our callback to clear the ES index
        project.delete
      end

      it 'skips its commits' do
        expect(results).to contain_exactly(instance_of(Commit))
        expect(results.count).to eq(1)
        expect(results.total_count).to eq(1)
      end
    end

    context 'with a project pending deletion' do
      before do
        project2.update!(pending_delete: true)
      end

      it 'skips its commits' do
        expect(results).to contain_exactly(instance_of(Commit))
        expect(results.count).to eq(1)
        expect(results.total_count).to eq(1)
      end
    end
  end

  describe "find_commits_by_message_with_elastic" do
    let(:options) { { search_level: 'project', project_ids: [project.id] } }

    it "returns commits" do
      expect(project.repository.find_commits_by_message_with_elastic('initial', options: options).first).to be_a(Commit)
      expect(project.repository.find_commits_by_message_with_elastic('initial', options: options).count).to eq(1)
      expect(project.repository.find_commits_by_message_with_elastic('initial', options: options).total_count).to eq(1)
    end
  end
end
