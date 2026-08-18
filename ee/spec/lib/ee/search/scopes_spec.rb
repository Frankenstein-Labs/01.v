# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Scopes, feature_category: :global_search do
  describe '.available_for_context' do
    context 'when availability is empty' do
      before do
        allow(described_class).to receive(:scope_definitions).and_return({
          test_scope: {
            label: -> { 'Test' },
            sort: 99,
            availability: {}
          }
        })
      end

      it 'does not include the scope with empty availability' do
        expect(described_class.available_for_context(context: :project)).not_to include(:test_scope)
      end
    end

    context 'for global context' do
      it 'includes code scopes with advanced search' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)
        stub_application_setting(
          global_search_code_enabled: true,
          global_search_wiki_enabled: true,
          global_search_commits_enabled: true
        )
        scopes = described_class.available_for_context(context: :global, requested_search_type: :advanced)

        expect(scopes).to include('blobs', 'commits', 'wiki_blobs', 'notes')
      end

      context 'when setting elasticsearch_code_scope is false' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).and_return(true)
          stub_ee_application_setting(elasticsearch_code_scope: false)
        end

        context 'when zoekt is not available' do
          before do
            allow(Search::Zoekt).to receive(:search?).and_return(false)
          end

          it 'does not include blobs' do
            scopes = described_class.available_for_context(context: :global)

            expect(scopes).to include(
              'commits',
              'work_items',
              'merge_requests',
              'milestones',
              'notes',
              'projects',
              'users',
              'wiki_blobs'
            )
            expect(scopes).not_to include('blobs')
          end
        end

        context 'when zoekt is available' do
          before do
            allow(Search::Zoekt).to receive(:search?).and_return(true)
          end

          it 'includes blobs' do
            scopes = described_class.available_for_context(context: :global)

            expect(scopes).to include(
              'blobs',
              'commits',
              'work_items',
              'merge_requests',
              'milestones',
              'notes',
              'projects',
              'users',
              'wiki_blobs'
            )
          end
        end
      end
    end

    context 'for group context' do
      it 'returns scopes available for group search with advanced' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)
        scopes = described_class.available_for_context(context: :group, requested_search_type: :advanced)

        expect(scopes).to include('blobs', 'merge_requests', 'projects', 'work_items')
        expect(scopes).to include('milestones', 'users')
        expect(scopes).not_to include('snippet_titles')
      end

      context 'when setting elasticsearch_code_scope is false' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).and_return(true)
          stub_ee_application_setting(elasticsearch_code_scope: false)
        end

        context 'when zoekt is not available' do
          before do
            allow(Search::Zoekt).to receive(:search?).and_return(false)
          end

          it 'does not include blobs' do
            scopes = described_class.available_for_context(context: :group)

            expect(scopes).to include(
              'commits',
              'merge_requests',
              'milestones',
              'notes',
              'projects',
              'users',
              'wiki_blobs',
              'work_items'
            )
            expect(scopes).not_to include('blobs')
          end
        end

        context 'when zoekt is available' do
          before do
            allow(Search::Zoekt).to receive(:search?).and_return(true)
          end

          it 'includes blobs' do
            scopes = described_class.available_for_context(context: :group)

            expect(scopes).to include(
              'blobs',
              'commits',
              'merge_requests',
              'milestones',
              'notes',
              'projects',
              'users',
              'wiki_blobs',
              'work_items'
            )
          end
        end
      end
    end

    context 'for project context' do
      context 'when setting elasticsearch_code_scope is false' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).and_return(true)
          stub_ee_application_setting(elasticsearch_code_scope: false)
        end

        context 'when zoekt is not available' do
          before do
            allow(Search::Zoekt).to receive(:search?).and_return(false)
          end

          it 'includes blobs' do # Through basic search
            scopes = described_class.available_for_context(context: :project)

            expect(scopes).to include(
              'blobs',
              'merge_requests',
              'wiki_blobs',
              'commits',
              'notes',
              'milestones',
              'users',
              'work_items'
            )
          end
        end

        context 'when zoekt is available' do
          before do
            allow(Search::Zoekt).to receive(:search?).and_return(true)
          end

          it 'includes blobs' do
            scopes = described_class.available_for_context(context: :project)

            expect(scopes).to include(
              'blobs',
              'commits',
              'merge_requests',
              'milestones',
              'notes',
              'users',
              'wiki_blobs',
              'work_items'
            )
          end
        end
      end
    end
  end

  describe '.search_type_available?' do
    let(:container) { nil }

    context 'when search_type is :zoekt' do
      it 'checks zoekt availability' do
        allow(Search::Zoekt).to receive(:search?).with(container).and_return(true)
        expect(described_class.send(:search_type_available?, :zoekt, container)).to be true
      end
    end

    context 'when search_type is :advanced' do
      it 'checks elasticsearch availability' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: container).and_return(true)
        expect(described_class.send(:search_type_available?, :advanced, container)).to be true
      end
    end

    context 'when search_type is :basic' do
      it 'returns true' do
        expect(described_class.send(:search_type_available?, :basic, container)).to be true
      end
    end

    context 'when search_type is unknown' do
      it 'returns false' do
        expect(described_class.send(:search_type_available?, :unknown, container)).to be false
      end
    end
  end

  describe '.valid_definition?' do
    let(:group) { build(:group) }

    context 'for blobs scope with EE search types' do
      let(:scope) { :blobs }
      let(:definition) { described_class.scope_definitions[scope] }

      context 'when at group context with advanced search' do
        it 'returns true and validates in EE' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          result = described_class.send(:valid_definition?, scope, definition, :group, group, :advanced)
          expect(result).to be true
        end

        it 'returns false when global setting disabled' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)
          stub_application_setting(global_search_code_enabled: false)

          result = described_class.send(:valid_definition?, scope, definition, :global, nil, :advanced)
          expect(result).to be false
        end
      end

      context 'when at group context with zoekt' do
        it 'returns true and validates in EE' do
          allow(Search::Zoekt).to receive(:search?).with(group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          result = described_class.send(:valid_definition?, scope, definition, :group, group, :zoekt)
          expect(result).to be true
        end
      end

      context 'when at project context with basic search' do
        let(:project) { build(:project) }

        it 'delegates to CE code and returns true' do
          result = described_class.send(:valid_definition?, scope, definition, :project, project, :basic)
          expect(result).to be true
        end
      end

      context 'with no explicit search type' do
        it 'returns true when advanced search is available' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          scopes = described_class.available_for_context(context: :group, container: group)
          expect(scopes).to include('blobs')
        end

        it 'returns true when zoekt is available' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(false)
          allow(Search::Zoekt).to receive(:search?).with(group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          scopes = described_class.available_for_context(context: :group, container: group)
          expect(scopes).to include('blobs')
        end

        it 'delegates to CE when only basic search available' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(false)
          allow(Search::Zoekt).to receive(:search?).with(group).and_return(false)

          scopes = described_class.available_for_context(context: :group, container: group)
          expect(scopes).not_to include('blobs')
        end

        it 'delegates to CE when scope has only basic search type' do
          # Test when ee_search_types is empty (line 91 false branch)
          # This happens when availability has only :basic, no :zoekt or :advanced
          basic_only_definition = {
            label: -> { 'Basic Only' },
            sort: 99,
            availability: {
              group: [:basic]
            }
          }
          allow(described_class).to receive(:scope_definitions).and_return({
            basic_scope: basic_only_definition
          })

          # Should delegate to CE's valid_definition? which will return true for basic
          scopes = described_class.available_for_context(
            context: :group, container: group, requested_search_type: :basic
          )
          expect(scopes).to include('basic_scope')
        end

        it 'treats invalid search_type as if no search_type was specified' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)

          scopes = described_class.available_for_context(
            context: :group, container: group, requested_search_type: 'invalid_xyz'
          )

          # Should include advanced search scopes since ES is available
          expect(scopes).to include('blobs', 'merge_requests', 'work_items')
          expect(scopes).not_to be_empty
        end
      end
    end

    context 'for CE scopes with basic search' do
      let(:scope) { :work_items }
      let(:definition) { described_class.scope_definitions[scope] }

      it 'delegates to CE code for basic search' do
        result = described_class.send(:valid_definition?, scope, definition, :project, nil, :basic)
        expect(result).to be true
      end

      it 'validates in EE when advanced search requested' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)

        result = described_class.send(:valid_definition?, scope, definition, :global, nil, :advanced)
        expect(result).to be true
      end
    end
  end
end
