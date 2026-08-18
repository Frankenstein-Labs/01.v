import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import * as utils from 'ee/security_orchestration/components/policy_editor/scan_result/lib/from_yaml';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT, GROUP_TYPE } from 'ee/security_orchestration/constants';
import GroupSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/group_select.vue';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { GROUP, mockRoleApproversApprovalManifest } from './mocks';

describe('Split View', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        glFeatures,
        ...provide,
      },
      stubs: {
        SettingPopover: true,
      },
    });
  };

  const findAvailableTypeListBox = () => wrapper.findComponentByTestId('available-types');
  const findGroupSelect = () => wrapper.findComponent(GroupSelect);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(APPROVAL_POLICY_TYPE);
  });

  describe('rendering', () => {
    let createPolicyObjectMock;
    beforeEach(() => {
      createWrapper({
        provide: {
          policyEditorEnabled: true,
          namespaceType: 'group',
        },
      });

      createPolicyObjectMock = jest
        .spyOn(utils, 'createPolicyObject')
        .mockImplementation(() => ({ policy: {}, parsingError: {} }));
    });

    it('updates policy only once when update via rule mode', async () => {
      await findAvailableTypeListBox().vm.$emit('select', GROUP_TYPE);
      await findGroupSelect().vm.$emit('select-items', { group_approvers_ids: [GROUP.id] });
      expect(createPolicyObjectMock).toHaveBeenCalledTimes(0);
    });

    it('updated policy when yaml is updated', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockRoleApproversApprovalManifest);

      expect(createPolicyObjectMock).toHaveBeenCalledTimes(2);
    });
  });
});
