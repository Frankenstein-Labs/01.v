# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UrlBuilder do
  subject { described_class }

  describe '.build' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_licensed_features(okrs: true)
    end

    context 'when work_item_legacy_url: true', feature_category: :team_planning do
      where(:factory, :path_generator) do
        :epic                             | ->(work_item) { "/groups/#{work_item.resource_parent.full_path}/-/epics/#{work_item.iid}" }
        [:work_item, :epic, :group_level] | ->(work_item) { "/groups/#{work_item.resource_parent.full_path}/-/epics/#{work_item.iid}" }
        :note_on_epic                     | ->(note)      { "/groups/#{note.noteable.resource_parent.full_path}/-/epics/#{note.noteable.iid}#note_#{note.id}" }

        # Work Items only workflows
        [:work_item, :epic]               | ->(work_item) { "/#{work_item.resource_parent.full_path}/-/work_items/#{work_item.iid}" }
        [:issue, :objective]              | ->(work_item) { "/#{work_item.resource_parent.full_path}/-/work_items/#{work_item.iid}" }
        [:issue, :key_result]             | ->(work_item) { "/#{work_item.resource_parent.full_path}/-/work_items/#{work_item.iid}" }
      end

      with_them do
        let(:object) { build_stubbed(*Array(factory)) }
        let(:path) { path_generator.call(object) }

        before do
          stub_feature_flags(work_item_legacy_url: true)
        end

        it 'returns the full URL' do
          expect(subject.build(object)).to eq("#{Settings.gitlab['url']}#{path}")
        end

        it 'returns only the path if only_path is set' do
          expect(subject.build(object, only_path: true)).to eq(path)
        end
      end
    end

    where(:factory, :path_generator) do
      :epic                             | ->(work_item) { "/groups/#{work_item.group.full_path}/-/epics/#{work_item.iid}" }
      [:work_item, :epic]               | ->(work_item) { "/#{work_item.project.full_path}/-/work_items/#{work_item.iid}" }
      [:work_item, :epic, :group_level] | ->(work_item) { "/groups/#{work_item.namespace.full_path}/-/work_items/#{work_item.iid}" }

      [:issue, :objective]              | ->(work_item) { "/#{work_item.project.full_path}/-/work_items/#{work_item.iid}" }
      [:issue, :key_result]             | ->(work_item) { "/#{work_item.project.full_path}/-/work_items/#{work_item.iid}" }

      :note_on_epic          | ->(note) { "/groups/#{note.noteable.group.full_path}/-/work_items/#{note.noteable.iid}#note_#{note.id}" }
      :note_on_vulnerability | ->(note) { "/#{note.project.full_path}/-/security/vulnerabilities/#{note.noteable.id}#note_#{note.id}" }

      :epic_board            | ->(epic_board)    { "/groups/#{epic_board.group.full_path}/-/epic_boards/#{epic_board.id}" }
      :vulnerability         | ->(vulnerability) { "/#{vulnerability.project.full_path}/-/security/vulnerabilities/#{vulnerability.id}" }

      :project_compliance_violation | ->(violation) { "/#{violation.project.full_path}/-/security/compliance_violations/#{violation.id}" }

      :group_wiki | ->(wiki) { "/groups/#{wiki.container.full_path}/-/wikis/home" }

      :note_on_compliance_violation | ->(note) { "/#{note.project.full_path}/-/security/compliance_violations/#{note.noteable.id}#note_#{note.id}" }

      [:issue, :key_result, :group_level] | ->(issue) { "/groups/#{issue.namespace.full_path}/-/work_items/#{issue.iid}" }

      :ai_catalog_agent            | ->(item) { "/explore/ai-catalog/agents/#{item.id}" }
      :ai_catalog_flow             | ->(item) { "/explore/ai-catalog/flows/#{item.id}" }
      :ai_catalog_third_party_flow | ->(item) { "/explore/ai-catalog/agents/#{item.id}" }
    end

    with_them do
      let(:object) { build_stubbed(*Array(factory)) }
      let(:path) { path_generator.call(object) }

      it 'returns the full URL' do
        expect(subject.build(object)).to eq("#{Settings.gitlab['url']}#{path}")
      end

      it 'returns only the path if only_path is set' do
        expect(subject.build(object, only_path: true)).to eq(path)
      end
    end

    context 'when passing a group wiki note' do
      let_it_be(:group) { create(:group) }
      let_it_be(:wiki_page_meta) { create(:wiki_page_meta, container: group) }
      let_it_be(:wiki_page_slug) { create(:wiki_page_slug, wiki_page_meta: wiki_page_meta, canonical: true) }

      let(:note) { build_stubbed(:note, noteable: wiki_page_meta, namespace: wiki_page_meta.namespace) }

      let(:path) { "/groups/#{group.full_path}/-/wikis/#{note.noteable.canonical_slug}#note_#{note.id}" }

      before do
        wiki_page_meta.canonical_slug = wiki_page_slug.slug
      end

      it 'returns the full URL' do
        expect(subject.build(note)).to eq("#{Gitlab.config.gitlab.url}#{path}")
      end

      it 'returns only the path if only_path is given' do
        expect(subject.build(note, only_path: true)).to eq(path)
      end
    end

    context 'when passing an AI catalog item without an id' do
      let(:item) do
        build(:ai_catalog_agent)
      end

      it 'returns nil' do
        expect(subject.build(item)).to be_nil
      end
    end
  end
end
