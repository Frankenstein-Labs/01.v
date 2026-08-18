# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::IssueLinkEntity, feature_category: :vulnerability_management do
  # rubocop: disable RSpec/FactoryBot/AvoidCreate
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  # rubocop: enable RSpec/FactoryBot/AvoidCreate

  let_it_be(:issue) { build_stubbed(:issue, project: project, author: user) }

  let(:issue_link) { build_stubbed(:vulnerabilities_issue_link, issue: issue) }

  let(:opts) { {} }

  let(:entity) do
    described_class.represent(issue_link, opts)
  end

  describe '#as_json' do
    subject(:serialized_issue_link) { entity.as_json }

    shared_examples 'required fields' do
      it 'are present' do
        expect(serialized_issue_link).to include(:issue_iid)
        expect(serialized_issue_link).to include(:author)
        expect(serialized_issue_link).to include(:created_at)
        expect(serialized_issue_link).to include(:author)
        expect(serialized_issue_link).to include(:link_type)
      end
    end

    context 'when the request is not nil' do
      let(:opts) { { request: request } }

      context 'when the user is available' do
        let(:request) { EntityRequest.new(current_user: user) }

        it_behaves_like 'required fields'

        context 'when the user can not read issue' do
          it 'does not contain issue_url' do
            expect(serialized_issue_link).not_to include(:issue_url)
          end
        end

        context 'when the user can read issue' do
          before_all do
            project.add_developer(user)
          end

          it 'contains issue_url' do
            expect(serialized_issue_link).to include(:issue_url)
          end
        end
      end

      context 'when the user is not available' do
        let(:request) { EntityRequest.new({}) }

        it_behaves_like 'required fields'

        it 'does not contain issue_url' do
          expect(serialized_issue_link).not_to include(:issue_url)
        end
      end
    end

    context 'when the request is nil' do
      it_behaves_like 'required fields'

      it 'does not contain issue_url' do
        expect(serialized_issue_link).not_to include(:issue_url)
      end
    end

    context 'when issue is a group-level work item' do
      # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Requires persisted records for URL generation and permissions
      let_it_be(:group) { create(:group) }
      let_it_be(:group_user) { create(:user, developer_of: [group, project]) }
      let_it_be(:group_issue) { create(:issue, :group_level, namespace: group) }
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let(:issue_link) { create(:vulnerabilities_issue_link, issue: group_issue, vulnerability: vulnerability) }
      # rubocop:enable RSpec/FactoryBot/AvoidCreate
      let(:opts) { { request: request } }
      let(:request) { EntityRequest.new(current_user: group_user) }

      before do
        project.update!(group: group)
        stub_licensed_features(epics: true)
      end

      it 'generates issue_url without raising error' do
        expect { serialized_issue_link[:issue_url] }.not_to raise_error
      end

      it 'exposes issue_url with group-level path' do
        expect(serialized_issue_link[:issue_url]).to match(
          %r{/groups/#{Regexp.escape(group.full_path)}/-/work_items/#{group_issue.iid}}
        )
      end
    end
  end
end
