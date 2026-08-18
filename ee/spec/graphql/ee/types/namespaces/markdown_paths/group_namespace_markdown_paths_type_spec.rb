# frozen_string_literal: true

require "spec_helper"

RSpec.describe Types::Namespaces::MarkdownPaths::GroupNamespaceMarkdownPathsType, feature_category: :shared do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, developers: user) }

  describe '#autocomplete_sources_path' do
    context 'with EE features' do
      context 'when epics feature is available' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'includes epics in the autocomplete paths' do
          result = resolve_field(:autocomplete_sources_path, group, current_user: user)

          expect(result).to be_a(Hash)
          expect(result).to include(
            epics: "/groups/#{group.full_path}/-/autocomplete_sources/epics?type=WorkItem"
          )
        end

        context 'with iid' do
          it 'includes epics with type_id param' do
            result = resolve_field(:autocomplete_sources_path, group, args: { iid: '456' }, current_user: user)

            expect(result[:epics])
              .to eq("/groups/#{group.full_path}/-/autocomplete_sources/epics?type=WorkItem&type_id=456")
          end
        end

        context 'with work_item_type_id' do
          it 'includes epics with work_item_type_id param' do
            gid = 'gid://gitlab/WorkItems::Type/789'
            result = resolve_field(:autocomplete_sources_path, group,
              args: { iid: 'new-work-item-iid', work_item_type_id: gid }, current_user: user)

            expect(result[:epics])
              .to eq("/groups/#{group.full_path}/-/autocomplete_sources/epics?type=WorkItem&work_item_type_id=789")
          end
        end
      end

      context 'when iterations feature is available' do
        before do
          stub_licensed_features(iterations: true)
        end

        it 'includes iterations in the autocomplete paths' do
          result = resolve_field(:autocomplete_sources_path, group, current_user: user)

          expect(result).to be_a(Hash)
          expect(result).to include(
            iterations: "/groups/#{group.full_path}/-/autocomplete_sources/iterations?type=WorkItem"
          )
        end

        context 'with iid' do
          it 'includes iterations with type_id param' do
            result = resolve_field(:autocomplete_sources_path, group, args: { iid: '456' }, current_user: user)

            expect(result[:iterations])
              .to eq("/groups/#{group.full_path}/-/autocomplete_sources/iterations?type=WorkItem&type_id=456")
          end
        end
      end

      context 'when security_dashboard feature is available' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        it 'includes vulnerabilities in the autocomplete paths' do
          result = resolve_field(:autocomplete_sources_path, group, current_user: user)

          expect(result).to be_a(Hash)
          expect(result).to include(
            vulnerabilities: "/groups/#{group.full_path}/-/autocomplete_sources/vulnerabilities?type=WorkItem"
          )
        end

        context 'with iid' do
          it 'includes vulnerabilities with type_id param' do
            result = resolve_field(:autocomplete_sources_path, group, args: { iid: '456' }, current_user: user)

            expect(result[:vulnerabilities])
              .to eq("/groups/#{group.full_path}/-/autocomplete_sources/vulnerabilities?type=WorkItem&type_id=456")
          end
        end
      end

      context 'when all EE features are available' do
        before do
          stub_licensed_features(epics: true, iterations: true, security_dashboard: true)
        end

        it 'includes all EE paths along with CE paths' do
          result = resolve_field(:autocomplete_sources_path, group, current_user: user)

          expect(result).to be_a(Hash)
          expect(result).to include(
            # CE paths
            members: "/groups/#{group.full_path}/-/autocomplete_sources/members?type=WorkItem",
            issues: "/groups/#{group.full_path}/-/autocomplete_sources/issues?type=WorkItem",
            mergeRequests: "/groups/#{group.full_path}/-/autocomplete_sources/merge_requests?type=WorkItem",
            labels: "/groups/#{group.full_path}/-/autocomplete_sources/labels?type=WorkItem",
            milestones: "/groups/#{group.full_path}/-/autocomplete_sources/milestones?type=WorkItem",
            commands: "/groups/#{group.full_path}/-/autocomplete_sources/commands?type=WorkItem",
            # EE paths
            epics: "/groups/#{group.full_path}/-/autocomplete_sources/epics?type=WorkItem",
            iterations: "/groups/#{group.full_path}/-/autocomplete_sources/iterations?type=WorkItem",
            vulnerabilities: "/groups/#{group.full_path}/-/autocomplete_sources/vulnerabilities?type=WorkItem"
          )
        end
      end

      context 'when EE features are not available' do
        before do
          stub_licensed_features(epics: false, iterations: false, security_dashboard: false)
        end

        it 'does not include EE paths' do
          result = resolve_field(:autocomplete_sources_path, group, current_user: user)

          expect(result).to be_a(Hash)
          expect(result).not_to have_key(:epics)
          expect(result).not_to have_key(:iterations)
          expect(result).not_to have_key(:vulnerabilities)

          # Should still include CE paths
          expect(result).to include(
            members: "/groups/#{group.full_path}/-/autocomplete_sources/members?type=WorkItem",
            issues: "/groups/#{group.full_path}/-/autocomplete_sources/issues?type=WorkItem"
          )
        end
      end
    end
  end
end
