import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import ApproverAction from 'ee/security_orchestration/components/policy_editor/scan_result/action/approver_action.vue';
import GroupSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/group_select.vue';
import RoleSelect from 'ee/security_orchestration/components/shared/role_select.vue';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';
import {
  GROUP_TYPE,
  ROLE_TYPE,
  USER_TYPE,
  DEFAULT_ASSIGNED_POLICY_PROJECT,
} from 'ee/security_orchestration/constants';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { verify, findYamlPreview } from '../utils';
import {
  mockGroupApproversApprovalManifest,
  mockRoleApproversApprovalManifest,
  mockUserApproversApprovalManifest,
  USER,
  GROUP,
  mockDefaultApprovalManifest,
} from './mocks';

describe('Scan result policy actions', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
        SettingPopover: true,
      },
    });
  };

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(APPROVAL_POLICY_TYPE);
  });

  const findApprovalsInput = () => wrapper.findComponentByTestId('approvals-required-input');
  const findAvailableTypeListBox = () => wrapper.findComponentByTestId('available-types');
  const findApproverAction = () => wrapper.findComponent(ApproverAction);
  const findGroupSelect = () => wrapper.findComponent(GroupSelect);
  const findRoleSelect = () => wrapper.findComponent(RoleSelect);
  const findUserSelect = () => wrapper.findComponent(UserSelect);

  describe('initial state', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render action section', () => {
      expect(findApproverAction().exists()).toBe(true);
      expect(findYamlPreview(wrapper).text()).toBe(mockDefaultApprovalManifest);
    });
  });

  describe('role approvers', () => {
    beforeEach(() => {
      createWrapper({
        provide: {
          roleApproverTypes: ['developer'],
        },
      });
    });

    it('selects role approvers', async () => {
      const DEVELOPER = 'developer';

      const verifyRuleMode = () => {
        expect(findApproverAction().exists()).toBe(true);
        expect(findRoleSelect().exists()).toBe(true);
        expect(findApproverAction().props('initAction').role_approvers).toEqual([DEVELOPER]);
      };

      await findAvailableTypeListBox().vm.$emit('select', ROLE_TYPE);
      await findRoleSelect().vm.$emit('select-items', { role_approvers: [DEVELOPER] });
      await findApprovalsInput().vm.$emit('update', 2);

      await verify({ manifest: mockRoleApproversApprovalManifest, verifyRuleMode, wrapper });
    });
  });

  describe('individual users', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('selects user approvers', async () => {
      const verifyRuleMode = () => {
        expect(findApproverAction().exists()).toBe(true);
        expect(findUserSelect().exists()).toBe(true);
        expect(findApproverAction().props('initAction').user_approvers_ids).toEqual([USER.id]);
      };

      await findAvailableTypeListBox().vm.$emit('select', USER_TYPE);
      await findUserSelect().vm.$emit('select-items', { user_approvers_ids: [USER.id] });
      await findApprovalsInput().vm.$emit('update', 2);

      await verify({ manifest: mockUserApproversApprovalManifest, verifyRuleMode, wrapper });
    });
  });

  describe('groups', () => {
    beforeEach(() => {
      createWrapper({ provide: { namespaceType: 'group' } });
    });

    it('selects group approvers', async () => {
      const verifyRuleMode = () => {
        expect(findApproverAction().exists()).toBe(true);
        expect(findGroupSelect().exists()).toBe(true);
        expect(findApproverAction().props('initAction').group_approvers_ids).toEqual([GROUP.id]);
      };

      await findAvailableTypeListBox().vm.$emit('select', GROUP_TYPE);
      await findGroupSelect().vm.$emit('select-items', { group_approvers_ids: [GROUP.id] });
      await findApprovalsInput().vm.$emit('update', 2);

      await verify({ manifest: mockGroupApproversApprovalManifest, verifyRuleMode, wrapper });
    });
  });
});
