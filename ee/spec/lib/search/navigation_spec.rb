# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Navigation, feature_category: :global_search do
  describe '#tabs' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let(:project_double) { instance_double(Project) }
    let(:group_double) { instance_double(Group) }
    let(:group) { nil }
    let(:options) { {} }
    let(:search_navigation) { described_class.new(user: user, project: project, group: group, options: options) }

    before do
      allow(search_navigation).to receive_messages(can?: true, tab_enabled_for_project?: false)
    end

    subject(:tabs) { search_navigation.tabs }

    context 'for commits tab' do
      context 'when project search' do
        let(:project) { project_double }
        let(:group) { nil }

        where(:tab_enabled_for_project, :condition) do
          true  | true
          false | false
        end

        with_them do
          before do
            allow(search_navigation).to receive(:tab_enabled_for_project?).and_return(tab_enabled_for_project)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:commits][:condition]).to eq(condition)
          end
        end
      end

      context 'when group search' do
        let(:project) { nil }
        let(:group) { group_double }

        where(:setting_enabled, :show_elasticsearch_tabs, :condition) do
          true  | true  | true
          true  | false | false
          false | true  | true
          false | false | false
        end

        with_them do
          let(:options) { { show_elasticsearch_tabs: show_elasticsearch_tabs } }

          before do
            stub_application_setting(global_search_commits_enabled: setting_enabled)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:commits][:condition]).to eq(condition)
          end
        end
      end

      context 'when global search' do
        let(:project) { nil }
        let(:group) { nil }

        where(:setting_enabled, :show_elasticsearch_tabs, :condition) do
          true  | true  | true
          false | true  | false
          false | false | false
          true  | false | false
          false | nil   | false
          true  | nil   | false
        end

        with_them do
          let(:options) { { show_elasticsearch_tabs: show_elasticsearch_tabs } }

          before do
            stub_application_setting(global_search_commits_enabled: setting_enabled)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:commits][:condition]).to eq(condition)
          end
        end
      end
    end

    context 'for wiki tab' do
      context 'when project search' do
        let(:project) { project_double }
        let(:group) { nil }

        where(:tab_enabled_for_project, :condition) do
          true  | true
          false | false
        end

        with_them do
          before do
            allow(search_navigation).to receive(:tab_enabled_for_project?).and_return(tab_enabled_for_project)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:wiki_blobs][:condition]).to eq(condition)
          end
        end
      end

      context 'when group search' do
        let(:project) { nil }
        let(:group) { group_double }

        where(:setting_enabled, :show_elasticsearch_tabs, :condition) do
          true  | true  | true
          true  | false | false
          false | true  | true
          false | false | false
        end

        with_them do
          let(:options) { { show_elasticsearch_tabs: show_elasticsearch_tabs } }

          before do
            stub_application_setting(global_search_wiki_enabled: setting_enabled)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:wiki_blobs][:condition]).to eq(condition)
          end
        end
      end

      context 'when global search' do
        let(:project) { nil }
        let(:group) { nil }

        where(:setting_enabled, :show_elasticsearch_tabs, :condition) do
          true  | true  | true
          false | true  | false
          false | false | false
          true  | false | false
          false | nil   | false
          true  | nil   | false
        end

        with_them do
          let(:options) { { show_elasticsearch_tabs: show_elasticsearch_tabs } }

          before do
            stub_application_setting(global_search_wiki_enabled: setting_enabled)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:wiki_blobs][:condition]).to eq(condition)
          end
        end
      end
    end

    context 'for code tab' do
      context 'when project search' do
        let(:project) { project_double }
        let(:group) { nil }

        where(:tab_enabled_for_project, :condition) do
          true  | true
          false | false
        end

        with_them do
          before do
            allow(search_navigation).to receive(:tab_enabled_for_project?).and_return(tab_enabled_for_project)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:blobs][:condition]).to eq(condition)
          end
        end
      end

      context 'when group search' do
        let(:project) { nil }
        let(:group) { group_double }

        where(:show_elasticsearch_tabs, :zoekt_enabled, :zoekt_enabled_for_group, :condition) do
          true  | false | false | true
          true  | true  | false | true
          false | false | false | false
          false | true  | false | false
          true  | false | true  | true
          true  | true  | true  | true
          false | false | true  | false
          false | true  | true  | true
        end

        with_them do
          before do
            allow(::Search::Zoekt).to receive(:search?).with(group).and_return(zoekt_enabled_for_group)
          end

          let(:options) { { show_elasticsearch_tabs: show_elasticsearch_tabs, zoekt_enabled: zoekt_enabled } }

          it 'data item condition is set correctly' do
            expect(tabs[:blobs][:condition]).to eq(condition)
          end
        end
      end

      context 'when global search' do
        let(:project) { nil }
        let(:group) { nil }

        where(:global_search_code_enabled, :show_elasticsearch_tabs, :zoekt_enabled, :condition) do
          false | false | false | false
          false | false | true  | false
          false | true  | false | false
          false | true  | true  | false
          true  | false | false | false
          true  | true  | false | true
          true  | true  | true  | true
          true  | false | true  | true
        end

        with_them do
          let(:options) { { show_elasticsearch_tabs: show_elasticsearch_tabs, zoekt_enabled: zoekt_enabled } }

          before do
            stub_application_setting(global_search_code_enabled: global_search_code_enabled)
          end

          it 'data item condition is set correctly' do
            expect(tabs[:blobs][:condition]).to eq(condition)
          end
        end
      end
    end

    context 'for comments tab' do
      where(:tab_enabled, :show_elasticsearch_tabs, :project, :condition) do
        true  | true  | nil                  | true
        true  | true  | ref(:project_double) | true
        false | false | nil                  | false
        false | false | ref(:project_double) | false
        false | true  | nil                  | true
        false | true  | ref(:project_double) | false
        true  | false | nil                  | true
        true  | false | ref(:project_double) | true
      end

      with_them do
        let(:options) { { show_elasticsearch_tabs: show_elasticsearch_tabs } }

        it 'data item condition is set correctly' do
          allow(search_navigation).to receive(:tab_enabled_for_project?).with(:notes).and_return(tab_enabled)

          expect(tabs[:notes][:condition]).to eq(condition)
        end
      end
    end
  end
end
