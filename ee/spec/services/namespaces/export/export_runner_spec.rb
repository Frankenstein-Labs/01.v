# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::ExportRunner, feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  subject(:run_export) { described_class.new(group, user).execute }

  describe '#execute' do
    context 'when unlicensed' do
      before do
        stub_licensed_features(export_user_permissions: false)
      end

      before_all do
        group.add_owner(user)
      end

      it 'raises an error' do
        expect { run_export }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when licensed' do
      before do
        stub_licensed_features(export_user_permissions: true)
      end

      context 'when current_user is a group maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        it 'raises an error' do
          expect { run_export }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end

      context 'when current user is a group owner' do
        before_all do
          group.add_owner(user)
        end

        it 'returns successful response' do
          expect(run_export).to be_success
        end
      end
    end
  end
end
