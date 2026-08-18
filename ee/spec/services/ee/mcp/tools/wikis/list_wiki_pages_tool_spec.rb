# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Wikis::ListWikiPagesTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }

  let(:params) { { group_id: group.full_path } }
  let(:tool) { described_class.new(current_user: user, params: params) }

  before_all do
    group.add_developer(user)
  end

  describe '#graphql_operation' do
    it 'returns the group query document', :aggregate_failures do
      query = tool.graphql_operation

      expect(query).to include('query listGroupWikiPages')
      expect(query).to include('group(fullPath: $fullPath)')
      expect(query).not_to include('project(')
    end
  end

  describe '#group_wikis_supported?' do
    it 'is enabled' do
      expect(tool.send(:group_wikis_supported?)).to be(true)
    end
  end

  describe '#build_variables' do
    context 'when group_id is a numeric ID' do
      let(:params) { { group_id: group.id.to_s } }

      it 'resolves the numeric ID to the group full path' do
        expect(tool.build_variables[:fullPath]).to eq(group.full_path)
      end
    end
  end

  describe '#execute' do
    it 'executes the group query instead of returning the unavailable message' do
      allow(GitlabSchema).to receive(:execute).and_call_original

      tool.execute

      expect(GitlabSchema).to have_received(:execute).with(
        include('listGroupWikiPages'),
        variables: hash_including(fullPath: group.full_path),
        context: hash_including(current_user: user)
      )
    end

    context 'when group wikis are licensed' do
      # Each example gets its own group. Writing a wiki page goes to Gitaly, which is not rolled
      # back between examples, so a shared group would leak pages across tests (and, depending on
      # order, a page could even be wiped by another group's cleanup before it is read).
      let(:licensed_group) { create(:group).tap { |licensed| licensed.add_developer(user) } }
      let(:params) { { group_id: licensed_group.full_path } }

      before do
        stub_licensed_features(group_wikis: true)
      end

      it 'returns the group wiki pages with slugs', :aggregate_failures do
        wiki_page = create(:wiki_page, container: licensed_group)

        result = tool.execute

        expect(result[:isError]).to be(false)
        items = result[:structuredContent][:items]
        expect(items.map { |item| item['title'] }).to include(wiki_page.title)
        expect(items).to all(include('slug'))
      end

      it 'returns an empty list when the group has no wiki pages', :aggregate_failures do
        result = tool.execute

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent][:items]).to eq([])
        expect(result[:structuredContent][:metadata]).to have_key(:end_cursor)
      end
    end

    context 'when the group is not found' do
      it 'returns a group not found error', :aggregate_failures do
        allow(GitlabSchema).to receive(:execute).and_return({ 'data' => { 'group' => nil } })

        result = tool.execute

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to eq(
          "Group not found, or you do not have access to it."
        )
      end
    end

    # A user can reach this tool (foundational-agent access) without being able to read the group's
    # wiki. `:read_wiki` is prevented either when the plan omits group wikis OR when the wiki isn't
    # available to that user, so `Group.wikiPages` resolves to null in both cases and the tool must
    # surface that clearly rather than reporting an empty wiki or a raw error.
    shared_examples 'a group wiki the user cannot access' do
      let(:result) { tool.execute }

      it 'returns an unavailable message without exposing wiki data', :aggregate_failures do
        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include(
          "This wiki isn't available"
        )
      end
    end

    context "when the group's plan does not include group wikis (e.g. trial or credit access)" do
      before do
        stub_licensed_features(group_wikis: false)
      end

      it_behaves_like 'a group wiki the user cannot access'
    end

    context 'when the user cannot read the wiki even though the group is licensed for it' do
      before do
        stub_licensed_features(group_wikis: true)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_wiki, an_instance_of(Group)).and_return(false)
      end

      it_behaves_like 'a group wiki the user cannot access'
    end
  end
end
