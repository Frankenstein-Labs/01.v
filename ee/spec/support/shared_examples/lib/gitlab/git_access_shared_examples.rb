# frozen_string_literal: true

RSpec.shared_examples 'git access for a read-only GitLab instance' do |ssh: false|
  include EE::GeoHelpers

  it 'denies push access' do
    project.add_maintainer(user)

    expect { push_changes }.to raise_forbidden("You can't push code to a read-only GitLab instance.")
  end

  context 'for a Geo setup' do
    let_it_be(:primary_node, freeze: false) do
      create(
        :geo_node,
        :primary,
        url: 'https://localhost:3000/gitlab',
        internal_url: 'https://localhost:3001/gitlab'
      )
    end

    let_it_be(:secondary_node, freeze: false) { create(:geo_node) }

    before do
      stub_licensed_features(geo: true)
    end

    context 'that is incorrectly set up' do
      let(:error_message) { "You can't push code to a read-only GitLab instance." }

      it 'denies push access with primary present' do
        project.add_maintainer(user)

        expect { push_changes }.to raise_forbidden(error_message)
      end
    end

    context 'that is correctly set up' do
      let(:console_messages) do
        [
          "This request to a Geo secondary node will be forwarded to the",
          "Geo primary node:",
          "",
          "  #{primary_repo_ssh_url}"
        ]
      end

      before do
        stub_current_geo_node(secondary_node)
      end

      context 'for a git clone/pull' do
        it 'returns success' do
          project.add_maintainer(user)

          expect(pull_changes).to be_a(Gitlab::GitAccessResult::Success)
        end
      end

      context 'for a git push' do
        # this behaviour is isolated to Gitlab::GitAccess.check, in reality the request should be redirected before
        # running that function
        if ssh
          it 'expects a GeoCustomSshError' do
            expect { push_changes }.to raise_error(EE::Gitlab::GitAccess::GeoCustomSshError, "The repo does not exist or is out-of-date on this secondary site")
          end
        else
          it 'denies push access' do
            expect { push_changes }.to raise_forbidden("You can't push code to a read-only GitLab instance.")
          end
        end
      end
    end
  end
end

RSpec.shared_examples 'git non-ssh access for a read-only GitLab instance' do
  it_behaves_like 'git access for a read-only GitLab instance', ssh: false
end

RSpec.shared_examples 'git ssh access for a read-only GitLab instance' do
  it_behaves_like 'git access for a read-only GitLab instance', ssh: true
end
