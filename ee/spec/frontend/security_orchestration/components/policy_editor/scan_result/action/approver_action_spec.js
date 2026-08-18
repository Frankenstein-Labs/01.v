import { nextTick } from 'vue';
import { GlFormInput, GlPopover, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { GROUP_TYPE, USER_TYPE, ROLE_TYPE } from 'ee/security_orchestration/constants';
import ApproverAction from 'ee/security_orchestration/components/policy_editor/scan_result/action/approver_action.vue';
import ApproverSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/approver_select.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';

describe('ApproverAction', () => {
  let wrapper;

  const APPROVERS_IDS = [1, 2, 3];
  const APPROVERS_NAMES = ['Name 1', 'Name 2'];

  const DEFAULT_ACTION = {
    approvals_required: 1,
    type: 'require_approval',
  };

  const EXISTING_USER_ACTION = {
    approvals_required: 1,
    type: 'require_approval',
    user_approvers_ids: APPROVERS_IDS,
  };

  const EXISTING_USER_ACTION_WITH_NAMES = {
    approvals_required: 1,
    type: 'require_approval',
    user_approvers: APPROVERS_NAMES,
  };

  const EXISTING_GROUP_ACTION = {
    approvals_required: 1,
    type: 'require_approval',
    group_approvers_ids: APPROVERS_IDS,
  };

  const EXISTING_GROUP_ACTION_WITH_NAMES = {
    approvals_required: 1,
    type: 'require_approval',
    group_approvers: APPROVERS_NAMES,
  };

  const EXISTING_MIXED_ACTION = {
    approvals_required: 1,
    type: 'require_approval',
    user_approvers_ids: APPROVERS_IDS,
    group_approvers_ids: APPROVERS_IDS,
  };

  const createWrapper = (propsData = {}, provide = {}) => {
    wrapper = shallowMountExtended(ApproverAction, {
      propsData: {
        actionIndex: 0,
        initAction: DEFAULT_ACTION,
        ...propsData,
      },
      provide: {
        namespaceId: '1',
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findApprovalsRequiredInput = () => wrapper.findComponent(GlFormInput);
  const findActionApprover = () => wrapper.findComponent(ApproverSelect);
  const findAllApproverSelectionWrapper = () => wrapper.findAllComponents(ApproverSelect);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findAddButton = () => wrapper.findComponentByTestId('add-approver');

  const emit = async (event, ...values) => {
    findActionApprover().vm.$emit(event, ...values);
    await nextTick();
  };

  describe('default', () => {
    beforeEach(createWrapper);

    it('renders', () => {
      expect(findActionApprover().props()).toEqual({
        actionIndex: 0,
        disabled: false,
        disabledTypes: [],
        errors: [],
        selectedItems: [],
        selectedNames: [],
        selectedType: '',
        showAdditionalText: false,
        showRemoveButton: false,
      });
    });

    it('adds a new approver type', async () => {
      expect(findAllApproverSelectionWrapper()).toHaveLength(1);
      await findAddButton().vm.$emit('click');
      expect(findAllApproverSelectionWrapper()).toHaveLength(2);
    });

    it('does not render errors', () => {
      expect(findActionApprover().props('errors')).toEqual([]);
    });

    it('selects approver type', async () => {
      expect(findAllApproverSelectionWrapper().at(0).props('selectedType')).toBe('');
      await emit('select-type', GROUP_TYPE, 0);

      expect(findAllApproverSelectionWrapper().at(0).props('selectedType')).toBe(GROUP_TYPE);
    });

    it('selects approver items', async () => {
      await emit('select-items', { group_approvers_ids: [1, 2] });
      expect(wrapper.emitted('changed')[0]).toEqual([
        {
          approvals_required: 1,
          type: 'require_approval',
          group_approvers_ids: [1, 2],
        },
      ]);
    });

    it('renders the number of approvers input with a valid state', () => {
      const approvalsRequiredInput = findApprovalsRequiredInput();
      expect(approvalsRequiredInput.exists()).toBe(true);
      expect(approvalsRequiredInput.attributes('state')).toBe('true');
    });

    it('triggers an update when changing number of approvals required', async () => {
      const approvalRequestPlusOne = DEFAULT_ACTION.approvals_required + 1;
      const formInput = findApprovalsRequiredInput();

      await formInput.vm.$emit('update', approvalRequestPlusOne);

      expect(wrapper.emitted('changed')[0]).toEqual([
        {
          approvals_required: approvalRequestPlusOne,
          type: 'require_approval',
        },
      ]);
    });

    it('renders the correct message for the first type added', () => {
      expect(findSectionLayout().text()).toContain('Require  approval from:');
    });

    it('does not render the popover when the action is not a warn type', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('warn action', () => {
    beforeEach(() => {
      return createWrapper({ isWarnType: true });
    });

    it('renders the message', () => {
      expect(findSectionLayout().text()).toContain(
        'Warn users with a bot comment and select approvers. The approvers are required unless developers dismiss the warn mode policy. After dismissal, approvers become optional.',
      );
      expect(findSectionLayout().text()).toContain('Developers may dismiss findings to proceed');
    });
  });

  describe('errors', () => {
    it('passes errors to select component', () => {
      const error = { title: 'Error', message: 'Something went wrong', index: 0 };
      createWrapper({ errors: [error] });
      expect(findActionApprover().props('errors')).toEqual([error]);
    });

    it('renders the number of approvers input with an invalid state', () => {
      createWrapper({ errors: [{ field: 'actions', index: 0 }] });
      const approvalsRequiredInput = findApprovalsRequiredInput();
      expect(approvalsRequiredInput.exists()).toBe(true);
      expect(approvalsRequiredInput.attributes('state')).toBe(undefined);
    });
  });

  describe('update approver type', () => {
    describe('initial selection', () => {
      it('updates the approver type', async () => {
        createWrapper();

        expect(findActionApprover().props('selectedType')).toEqual('');
        await emit('select-type', GROUP_TYPE, 0);
        expect(findActionApprover().props('selectedType')).toEqual(GROUP_TYPE);

        await emit('select-type', USER_TYPE, 0);
        expect(findActionApprover().props('selectedType')).toEqual(USER_TYPE);
      });
    });

    describe('change approver type', () => {
      beforeEach(async () => {
        createWrapper();
        await emit('select-type', GROUP_TYPE, 0);
      });

      const changeApproverType = async () => {
        await emit('select-type', ROLE_TYPE, 0);
      };

      it('replaces the type with new type', async () => {
        await changeApproverType();
        expect(findActionApprover().props('selectedType')).toEqual(ROLE_TYPE);
      });

      it('emits changes with the appropriate values', async () => {
        await emit('select-items', { user_approvers_ids: [1, 2] });
        expect(wrapper.emitted('changed')[0]).toEqual([
          {
            approvals_required: 1,
            type: 'require_approval',
            user_approvers_ids: [1, 2],
          },
        ]);
      });
    });
  });

  describe('remove action', () => {
    it('does not render remove button for section layout', () => {
      createWrapper();

      expect(findSectionLayout().props('showRemoveButton')).toBe(false);
    });
  });

  describe('remove approver type', () => {
    beforeEach(async () => {
      createWrapper();

      await emit('select-type', GROUP_TYPE, 0);
    });

    const removeApproverType = async (index = 0, type = GROUP_TYPE) => {
      await emit('remove', index, type);
    };

    it('removes type from the list', async () => {
      expect(findActionApprover().props('selectedType')).toBe(GROUP_TYPE);
      await findAddButton().vm.$emit('click');
      await findAllApproverSelectionWrapper().at(1).vm.$emit('select-type', USER_TYPE, 1);

      expect(findAllApproverSelectionWrapper()).toHaveLength(2);

      expect(findAllApproverSelectionWrapper().at(1).props('selectedType')).toBe(USER_TYPE);

      findAllApproverSelectionWrapper().at(1).vm.$emit('remove', 1);
      await nextTick();
      expect(findAllApproverSelectionWrapper()).toHaveLength(1);
    });

    it('removes type from payload when selected type is replaced with new type', async () => {
      await emit('select-type', GROUP_TYPE, 0);
      await emit('select-items', { group_approvers_ids: [1, 2] });

      const ACTION = {
        approvals_required: 1,
        type: 'require_approval',
        group_approvers_ids: [1, 2],
      };

      expect(wrapper.emitted('changed')[0]).toEqual([ACTION]);

      await emit('select-type', USER_TYPE, 0);

      expect(wrapper.emitted('changed')[1]).toEqual([
        {
          approvals_required: 1,
          type: 'require_approval',
        },
      ]);
    });

    it.each(['user_approvers_ids', 'user_approvers', 'group_approvers_ids', 'group_approvers'])(
      'emits "changed" with the appropriate values',
      async (type) => {
        await emit('select-items', { [type]: [1, 2] });
        expect(wrapper.emitted('changed')[0]).toEqual([
          {
            approvals_required: 1,
            type: 'require_approval',
            [type]: [1, 2],
          },
        ]);
        await removeApproverType();
        expect(findAllApproverSelectionWrapper()).toHaveLength(0);
        expect(wrapper.emitted('changed')[1]).toEqual([
          {
            approvals_required: 1,
            type: 'require_approval',
          },
        ]);
      },
    );
  });

  describe('existing user approvers', () => {
    it('renders the user select when there are existing user approvers', () => {
      createWrapper({
        initAction: EXISTING_USER_ACTION,
      });

      expect(findAllApproverSelectionWrapper()).toHaveLength(1);
      expect(findActionApprover().props('selectedType')).toBe(USER_TYPE);
      expect(findActionApprover().props('selectedItems')).toEqual([1, 2, 3]);
    });

    it('renders the user select when there are existing group approvers with names', () => {
      createWrapper({
        initAction: EXISTING_USER_ACTION_WITH_NAMES,
      });
      expect(findAllApproverSelectionWrapper()).toHaveLength(1);
      expect(findActionApprover().props('selectedType')).toBe(USER_TYPE);
      expect(findActionApprover().props('selectedItems')).toEqual([]);
      expect(findActionApprover().props('selectedNames')).toEqual(APPROVERS_NAMES);
    });

    it.each`
      initAction                          | payloadKey
      ${EXISTING_USER_ACTION_WITH_NAMES}  | ${'user_approvers_ids'}
      ${EXISTING_GROUP_ACTION_WITH_NAMES} | ${'group_approvers_ids'}
    `('replaces deprecated name properties with ids', async ({ initAction, payloadKey }) => {
      createWrapper({
        initAction,
      });

      expect(findActionApprover().props('selectedNames')).toEqual(APPROVERS_NAMES);
      await emit('select-items', { [payloadKey]: [1, 2] });

      expect(wrapper.emitted('changed')[0]).toEqual([
        { approvals_required: 1, type: 'require_approval', [payloadKey]: [1, 2] },
      ]);
    });
  });

  describe('existing group approvers', () => {
    it('renders the group select when there are existing group approvers', () => {
      createWrapper({
        initAction: EXISTING_GROUP_ACTION,
      });
      expect(findAllApproverSelectionWrapper()).toHaveLength(1);
      expect(findActionApprover().props('selectedType')).toBe(GROUP_TYPE);
      expect(findActionApprover().props('selectedItems')).toEqual([1, 2, 3]);
      expect(findActionApprover().props('selectedNames')).toEqual([]);
    });

    it('renders the group select when there are existing group approvers with names', () => {
      createWrapper({
        initAction: EXISTING_GROUP_ACTION_WITH_NAMES,
      });
      expect(findAllApproverSelectionWrapper()).toHaveLength(1);
      expect(findActionApprover().props('selectedType')).toBe(GROUP_TYPE);
      expect(findActionApprover().props('selectedItems')).toEqual([]);
      expect(findActionApprover().props('selectedNames')).toEqual(APPROVERS_NAMES);
    });
  });

  describe('existing mixed approvers', () => {
    beforeEach(() => {
      createWrapper({
        initAction: EXISTING_MIXED_ACTION,
      });
    });

    it('renders the user select with only the user approvers', () => {
      expect(findAllApproverSelectionWrapper()).toHaveLength(2);
      expect(findAllApproverSelectionWrapper().at(0).props('selectedType')).toBe(USER_TYPE);
      expect(findAllApproverSelectionWrapper().at(1).props('selectedType')).toBe(GROUP_TYPE);

      expect(findAllApproverSelectionWrapper().at(0).props('selectedItems')).toEqual([1, 2, 3]);
      expect(findAllApproverSelectionWrapper().at(1).props('selectedItems')).toEqual([1, 2, 3]);
    });
  });

  describe('updates role approvers', () => {
    it('updates role approvers with new values', async () => {
      createWrapper({
        initAction: { ...DEFAULT_ACTION, role_approvers: ['developer'] },
      });

      expect(findAllApproverSelectionWrapper().at(0).props('selectedType')).toBe(ROLE_TYPE);
      await emit('select-items', { role_approvers: ['developer', 'maintainer'] });

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            approvals_required: 1,
            role_approvers: ['developer', 'maintainer'],
            type: 'require_approval',
          },
        ],
      ]);
    });

    it('updates role approvers with no values', async () => {
      createWrapper({
        initAction: DEFAULT_ACTION,
      });
      await emit('select-items', { role_approvers: ['owner'] });

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            ...DEFAULT_ACTION,
            role_approvers: ['owner'],
          },
        ],
      ]);
    });
  });

  describe('sanitize required approval actions', () => {
    it.each(['invalid', NaN, undefined, null, -1, -10, 0.5])(
      'validates required approval action number for invalid type',
      (approvalsRequired) => {
        createWrapper({
          initAction: { ...DEFAULT_ACTION, approvals_required: approvalsRequired },
        });

        expect(findApprovalsRequiredInput().props('value')).toBe(1);
        expect(findApprovalsRequiredInput().props('state')).toBe(false);
      },
    );
  });
});
