# frozen_string_literal: true

RSpec.shared_examples 'a secrets permission' do
  # Note: The including spec must define:
  # - `permission` subject that creates the base permission object
  # - `link_group_to_resource(resource, group, access_level)` method to create group links

  it { is_expected.to validate_presence_of(:resource) }
  it { is_expected.to validate_presence_of(:principal_id) }
  it { is_expected.to validate_presence_of(:principal_type) }
  it { is_expected.to validate_presence_of(:actions) }

  describe 'normalized_expired_at' do
    context 'when expired_at is present' do
      context 'with date-only format' do
        it 'normalizes it to string' do
          permission.expired_at = '2025-10-12'
          expect(permission.normalized_expired_at).to eq('2025-10-12T00:00:00Z')
        end
      end

      context 'with full datetime format' do
        it 'converts to UTC ISO8601 format' do
          permission.expired_at = '2025-10-12T15:30:00+02:00'
          expect(permission.normalized_expired_at).to eq('2025-10-12T13:30:00Z')
        end
      end
    end

    context 'when expired_at is blank' do
      it 'returns nil' do
        permission.expired_at = ''
        expect(permission.normalized_expired_at).to be_nil
      end
    end

    context 'when expired_at is nil' do
      it 'returns nil' do
        permission.expired_at = nil
        expect(permission.normalized_expired_at).to be_nil
      end
    end
  end

  describe 'expired_at validation' do
    using RSpec::Parameterized::TableSyntax

    where(:case_name, :expired_at_input, :valid, :error_msg) do
      # --- valid
      'future ISO8601 (UTC)'        | 5.days.from_now.utc.iso8601.to_s       | true  | nil
      'future only date      '      | 2.days.from_now.to_date.iso8601.to_s   | true  | nil
      'blank allowed'               | ''                                     | true  | nil
      'nil allowed'                 | nil                                    | true  | nil

      # --- invalid: past time
      'past ISO8601 (UTC)'          | 1.day.ago.utc.iso8601.to_s             | false | 'must be in the future'
      'date-only in the past'       | '2025-01-30'                           | false | 'must be in the future'

      # --- invalid: bad formats
      'bad month'                   | '2025-13-01T00:00:00Z'                 | false | 'must be RFC3339'
      'nonsense'                    | 'not-a-date'                           | false | 'must be RFC3339'
    end

    with_them do
      it 'validates' do
        permission.expired_at = expired_at_input

        if valid
          expect(permission).to be_valid
        else
          expect(permission).to be_invalid
          expect(permission.errors[:expired_at].join).to include(error_msg)
        end
      end
    end
  end

  describe 'common validations' do
    it 'is valid with valid attributes' do
      expect(permission).to be_valid
    end

    it 'validates non-empty actions includes a read action' do
      permission.actions = ['write']
      expect(permission).not_to be_valid
      expect(permission.errors[:actions]).to include("must include read, read_metadata, or read_value")
    end

    it 'accepts read_metadata as the metadata read action' do
      permission.actions = %w[read_metadata write]
      expect(permission).to be_valid
    end

    it 'accepts read_value as a standalone read action' do
      permission.actions = ['read_value']
      expect(permission).to be_valid
    end

    it 'accepts read_value alongside a metadata read' do
      permission.actions = %w[read_metadata read_value]
      expect(permission).to be_valid
    end

    it 'validates principal_type is valid' do
      permission.principal_type = 'InvalidType'
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_type]).to include('must be one of: User, Role, Group, MemberRole')
    end

    it 'validates actions are valid' do
      permission.actions = ['foo']
      expect(permission).not_to be_valid
      expect(permission.errors[:actions]).to include('contains invalid action: foo')
    end

    it 'validates role_id when principal_type is Role' do
      permission.principal_type = 'Role'
      permission.principal_id = 999 # Invalid role ID
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_id][0])
        .to match(/must be one of: reporter \(20\), security_manager \(25\), developer \(30\), maintainer \(40\)/)
    end
  end

  describe '#management_capabilities' do
    using RSpec::Parameterized::TableSyntax

    where(:actions, :expected_data, :expected_metadata) do
      %w[read]                       | []                   | %w[read]
      %w[read_metadata]              | []                   | %w[read]
      %w[read_value]                 | []                   | []
      %w[read_metadata read_value]   | []                   | %w[read]
      %w[read write]                 | %w[create update]    | %w[read create update]
      %w[read delete]                | %w[delete]           | %w[read delete]
    end

    with_them do
      it 'maps actions to management-policy capabilities and excludes value reads' do
        permission.actions = actions
        result = permission.management_capabilities

        expect(result[:data]).to match_array(expected_data)
        expect(result[:metadata]).to match_array(expected_metadata)
      end
    end
  end

  describe '#api_capabilities' do
    it 'grants value read only when read_value is present' do
      permission.actions = %w[read_metadata read_value]
      result = permission.api_capabilities

      expect(result[:data]).to contain_exactly('read')
      expect(result[:metadata]).to contain_exactly('list')
    end

    it 'is empty without read_value' do
      permission.actions = %w[read_metadata write]
      result = permission.api_capabilities

      expect(result[:data]).to be_empty
      expect(result[:metadata]).to be_empty
    end
  end

  describe '#set_actions_from_capabilities' do
    it 'maps metadata read back to the deprecated read alias' do
      permission.set_actions_from_capabilities(
        management_metadata: Set.new(%w[read list scan]),
        management_data: Set.new(%w[list scan]),
        api_data: Set.new
      )

      expect(permission.actions).to contain_exactly('read')
    end

    it 'maps a value-path read from the api policy to read_value' do
      permission.set_actions_from_capabilities(
        management_metadata: Set.new(%w[read]),
        management_data: Set.new,
        api_data: Set.new(%w[read])
      )

      expect(permission.actions).to contain_exactly('read', 'read_value')
    end

    it 'maps create and update to write, and delete to delete' do
      permission.set_actions_from_capabilities(
        management_metadata: Set.new(%w[read create update delete]),
        management_data: Set.new(%w[create update delete]),
        api_data: Set.new
      )

      expect(permission.actions).to contain_exactly('read', 'write', 'delete')
    end
  end

  describe 'User principal validation' do
    context 'when principal_type is User' do
      it 'validates successfully when the user is a member' do
        expect(permission).to be_valid
      end

      it 'is invalid when user does not exist' do
        permission.principal_id = User.count + 1
        expect(permission).not_to be_valid
        expect(permission.errors[:principal_id]).to include('user does not exist')
      end

      it 'is invalid when user is not a member of the resource' do
        non_member_user = create(:user)
        permission.principal_id = non_member_user.id
        expect(permission).not_to be_valid
        expect(permission.errors[:principal_id].first).to include('user is not a member of the')
      end

      context 'with user role validation' do
        let(:test_user) { create(:user) }
        let(:principal_id) { test_user.id }

        before do
          permission.resource.public_send(:"add_#{access_level_name}", test_user)
        end

        context 'when user has Guest role' do
          let(:access_level_name) { :guest }

          it 'is invalid' do
            expect(permission).not_to be_valid
            expect(permission.errors[:principal_id]).to include('user must have at least Reporter role')
          end
        end

        context 'when user has Reporter role' do
          let(:access_level_name) { :reporter }

          it 'is valid' do
            expect(permission).to be_valid
          end
        end

        context 'when user has Developer role' do
          let(:access_level_name) { :developer }

          it 'is valid' do
            expect(permission).to be_valid
          end
        end
      end
    end
  end

  describe 'Group principal validation' do
    context 'when principal_type is Group' do
      it 'is invalid when group does not exist' do
        permission.principal_type = 'Group'
        permission.principal_id = Group.count + 1
        expect(permission).not_to be_valid
        expect(permission.errors[:principal_id]).to include('group does not exist')
      end

      it 'is invalid when group does not have access to the resource' do
        unrelated_group = create(:group)
        permission.principal_type = 'Group'
        permission.principal_id = unrelated_group.id
        expect(permission).not_to be_valid
        expect(permission.errors[:principal_id].first).to include('group does not have access to this')
      end

      context 'with group role validation' do
        let(:shared_group) { create(:group) }
        let(:principal_type) { 'Group' }
        let(:principal_id) { shared_group.id }

        context 'when group has Guest access level' do
          let(:access_level) { Gitlab::Access::GUEST }

          before do
            link_group_to_resource(permission.resource, shared_group, access_level)
          end

          it 'is invalid' do
            expect(permission).not_to be_valid
            expect(permission.errors[:principal_id]).to include('group must have at least Reporter role')
          end
        end

        context 'when group has Reporter access level' do
          let(:access_level) { Gitlab::Access::REPORTER }

          before do
            link_group_to_resource(permission.resource, shared_group, access_level)
          end

          it 'is valid' do
            expect(permission).to be_valid
          end
        end

        context 'when group has Developer access level' do
          let(:access_level) { Gitlab::Access::DEVELOPER }

          before do
            link_group_to_resource(permission.resource, shared_group, access_level)
          end

          it 'is valid' do
            expect(permission).to be_valid
          end
        end

        context 'when group has Maintainer access level' do
          let(:access_level) { Gitlab::Access::MAINTAINER }

          before do
            link_group_to_resource(permission.resource, shared_group, access_level)
          end

          it 'is valid' do
            expect(permission).to be_valid
          end
        end
      end
    end
  end
end
