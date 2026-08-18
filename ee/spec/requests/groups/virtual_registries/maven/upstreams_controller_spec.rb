# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::VirtualRegistries::Maven::UpstreamsController, feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:maven_upstream) { create(:virtual_registries_packages_maven_upstream, group:) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  describe 'GET #edit' do
    subject { get edit_group_virtual_registries_maven_upstream_path(group, maven_upstream) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is guest user' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like 'returning response status', :ok

        it_behaves_like 'disallowed access to maven virtual registry'

        context 'when the upstream does not exist' do
          subject { get group_virtual_registries_maven_upstream_path(group, id: non_existing_record_id) }

          it_behaves_like 'returning response status', :not_found
        end

        context 'when the upstream belongs to another group' do
          let(:other_group) { create(:group) }
          let(:maven_upstream) { create(:virtual_registries_packages_maven_upstream, group: other_group) }

          it_behaves_like 'returning response status', :not_found
        end
      end
    end
  end

  describe 'GET #show' do
    subject(:get_show) { get group_virtual_registries_maven_upstream_path(group, maven_upstream) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :ok

        it 'assigns the upstream to @maven_upstream' do
          get_show

          expect(assigns(:maven_upstream)).to eq(maven_upstream)
          expect(response).to render_template(:show)
        end

        context 'when the upstream does not exist' do
          subject { get group_virtual_registries_maven_upstream_path(group, id: non_existing_record_id) }

          it_behaves_like 'returning response status', :not_found
        end

        context 'when the upstream belongs to another group' do
          let(:other_group) { create(:group) }
          let(:maven_upstream) { create(:virtual_registries_packages_maven_upstream, group: other_group) }

          it_behaves_like 'returning response status', :not_found
        end

        context 'when updateVirtualRegistry ability is not allowed' do
          before do
            get_show
          end

          it 'sets the frontend ability to false' do
            expect(response.body).to have_pushed_frontend_ability(updateVirtualRegistry: false)
          end
        end

        context 'when user is maintainer' do
          before_all do
            group.add_maintainer(user)
          end

          context 'when updateVirtualRegistry ability is allowed' do
            before do
              get_show
            end

            it 'sets the frontend ability to true' do
              expect(response.body).to have_pushed_frontend_ability(updateVirtualRegistry: true)
            end
          end
        end
      end
    end
  end
end
