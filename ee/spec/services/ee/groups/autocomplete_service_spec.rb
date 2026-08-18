# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AutocompleteService, feature_category: :groups_and_projects do
  let_it_be_with_refind(:group) do
    create(:group, :nested, :private, avatar: fixture_file_upload('spec/fixtures/dk.png'))
  end

  let_it_be(:sub_group) { create(:group, :private, parent: group) }

  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:epic) { create(:epic, group: group, author: user) }

  subject { described_class.new(group, user) }

  def expect_labels_to_equal(labels, expected_labels)
    extract_title = ->(label) { label['title'] }
    expect(labels.map(&extract_title)).to match_array(expected_labels.map(&extract_title))
  end

  describe '#issues' do
    let_it_be(:group_issue) { create(:work_item, :group_level, namespace: group) }
    let_it_be(:epic_work_item) { create(:work_item, :epic, :group_level, namespace: group) }

    context 'when licensed feature epics is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'includes epic work item icon in list' do
        issues = subject.issues.map(&:icon_name)

        expect(issues).to include('work-item-issue', 'work-item-epic')
      end
    end
  end

  describe '#labels_as_hash' do
    let!(:label1) { create(:group_label, group: group) }
    let!(:label2) { create(:group_label, group: group) }
    let!(:sub_group_label) { create(:group_label, group: sub_group) }
    let!(:parent_group_label) { create(:group_label, group: group.parent) }

    context 'some labels are already assigned' do
      before do
        epic.labels << label1
      end

      it 'marks already assigned as set' do
        results = subject.labels_as_hash(epic)
        expected_labels = [label1, label2, parent_group_label]

        expect_labels_to_equal(results, expected_labels)

        assigned_label_titles = epic.labels.map(&:title)
        results.each do |hash|
          if assigned_label_titles.include?(hash['title'])
            expect(hash[:set]).to eq(true)
          else
            expect(hash.key?(:set)).to eq(false)
          end
        end
      end
    end
  end

  describe '#epics' do
    let(:expected_attributes) { %i[iid title group_id] }

    before do
      stub_licensed_features(epics: true)
    end

    it 'returns nothing if not allowed' do
      guest = create(:user)

      epics = described_class.new(group, guest).epics

      expect(epics).to be_empty
    end

    it 'returns epics from group' do
      result = subject.epics.map { |epic| epic.slice(expected_attributes) }

      expect(result).to contain_exactly(epic.slice(expected_attributes))
    end

    it 'returns only confidential epics if confidential_only is true' do
      confidential_epic = create(:epic, :confidential, group: group)

      result = subject.epics(confidential_only: true)
                 .map { |epic| epic.slice(expected_attributes) }

      expect(result).to contain_exactly(confidential_epic.slice(expected_attributes))
    end
  end

  describe '#iterations', feature_category: :team_planning do
    let_it_be(:cadence) { create(:iterations_cadence, group: group) }
    let_it_be(:open_iteration) { create(:iteration, iterations_cadence: cadence) }
    let_it_be(:closed_iteration) { create(:iteration, :closed, iterations_cadence: cadence) }
    let_it_be(:other_iteration) do
      other_group = create(:group, :private)
      create(:iteration, iterations_cadence: create(:iterations_cadence, group: other_group))
    end

    subject { described_class.new(group, user).iterations }

    context 'when the iterations feature is unavailable' do
      before do
        stub_licensed_features(iterations: false)
      end

      it { is_expected.to be_empty }
    end

    context 'when the iterations feature is available' do
      before do
        stub_licensed_features(iterations: true)
      end

      it { is_expected.to contain_exactly(open_iteration) }
    end
  end

  describe '#wikis' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, :public) }
    let_it_be_with_reload(:wiki) { create(:group_wiki, group: group) }

    let(:service) { described_class.new(group, user) }

    before do
      allow(service).to receive(:can?).and_return(true)
      create(:wiki_page, wiki: wiki, title: 'page1', content: 'content1')
    end

    context 'when user can read wiki' do
      it 'returns wiki pages' do
        allow(service).to receive(:can?).and_return(true)

        results = service.wikis

        expect(results.size).to eq(1)
        expect(results.first).to include(path: "/groups/#{group.full_path}/-/wikis/page1", slug: 'page1',
          title: 'page1')
      end

      %w[templates uploads].each_with_index do |prefix, index|
        context "with #{prefix}" do
          let(:page_number) { index + 2 }

          before do
            create(:wiki_page, wiki: wiki, title: "#{prefix}/page#{page_number}", content: "content#{page_number}")
          end

          it "does not return #{prefix}" do
            results = service.wikis

            expect(results.map { |r| r[:slug] }).not_to include("#{prefix}/page#{page_number}")
          end
        end
      end

      context 'with frontmatter title' do
        before do
          create(
            :wiki_page,
            wiki: wiki,
            title: 'page4',
            content: "---\ntitle: Real title\n---\ncontent"
          )
        end

        it 'uses the title from frontmatter' do
          results = service.wikis
          page4 = results.find { |r| r[:slug] == 'page4' }

          expect(page4).to include(title: 'Real title')
        end
      end
    end

    context 'when user cannot read wiki' do
      it 'returns empty array' do
        service = described_class.new(group, nil)
        allow(service).to receive(:can?).and_return(false)

        results = service.wikis

        expect(results).to be_empty
      end
    end
  end

  describe '#vulnerability' do
    let_it_be_with_refind(:project) { create(:project, group: group).tap(&:mark_as_vulnerable!) }
    let_it_be(:vulnerability) { create(:vulnerability, :with_read, project: project) }
    let_it_be(:guest) { create(:user) }

    let(:autocomplete_user) { user }

    subject { described_class.new(group, autocomplete_user).vulnerabilities.map(&:id) }

    context 'when the feature is not available' do
      context 'when the user is not allowed' do
        it { is_expected.to be_empty }
      end

      context 'when the user is allowed' do
        before do
          project.add_developer(user)
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when the user is not allowed' do
        let(:autocomplete_user) { guest }

        it { is_expected.to be_empty }
      end

      context 'when the user is allowed' do
        before do
          project.add_developer(user)
        end

        it { is_expected.to contain_exactly(vulnerability.id) }
      end
    end
  end

  describe '#commands' do
    context 'when target is an epic' do
      let_it_be(:parent_epic) { create(:epic, group: group, author: user) }
      let_it_be(:epic)        { create(:epic, group: group, author: user, parent: parent_epic) }

      context 'with subepics feature enabled' do
        before do
          stub_licensed_features(epics: true, subepics: true)
        end

        it 'returns available commands' do
          available_commands = [
            :todo, :unsubscribe, :react, :shrug, :tableflip, :title, :close,
            :child_epic, :remove_child_epic, :parent_epic, :remove_parent_epic, :confidential
          ]

          expect(subject.commands(epic).map { |c| c[:name] }).to match_array(available_commands)
        end
      end

      context 'with subepics feature disabled' do
        before do
          stub_licensed_features(epics: true, subepics: false)
        end

        it 'returns available commands' do
          available_commands = [
            :todo, :unsubscribe, :react, :shrug, :tableflip, :title, :close, :confidential
          ]

          expect(subject.commands(epic).map { |c| c[:name] }).to match_array(available_commands)
        end
      end
    end
  end
end
