import { GlFormInput, GlCollapsibleListbox, GlForm, GlFormGroup } from '@gitlab/ui';
import { nextTick } from 'vue';
import { createAlert } from '~/alert';
import RoleForm from 'ee/roles_and_permissions/components/manage_role/role_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import PermissionsSelector from 'ee/roles_and_permissions/components/manage_role/permissions_selector.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { mockMemberRole } from '../../mock_data';

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

jest.mock('~/lib/utils/url_utility');

describe('RoleForm', () => {
  let wrapper;

  const createComponent = ({
    title = 'Create role',
    role,
    submitText = 'Create role',
    showBaseRole = true,
    busy = false,
  } = {}) => {
    wrapper = shallowMountExtended(RoleForm, {
      propsData: { title, role, submitText, showBaseRole, busy },
      stubs: {
        GlFormInput: stubComponent(GlFormInput, { props: ['state'] }),
        GlFormGroup: stubComponent(GlFormGroup, { props: ['state'] }),
      },
    });

    return waitForPromises();
  };

  const findSubmitButton = () => wrapper.findComponentByTestId('submit-button');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findNameField = () => wrapper.findAllComponents(GlFormInput).at(0);
  const findBaseRoleFormGroup = () => wrapper.findComponentByTestId('base-role-form-group');
  const findRoleDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDescriptionField = () => wrapper.findAllComponents(GlFormInput).at(1);
  const findPermissionsSelector = () => wrapper.findComponent(PermissionsSelector);
  const findForm = () => wrapper.findComponent(GlForm);

  const fillForm = () => {
    findRoleDropdown().vm.$emit('select', 'GUEST');
    findNameField().vm.$emit('input', 'My role name');
    findDescriptionField().vm.$emit('input', 'My description');
    findPermissionsSelector().vm.$emit('change', ['A']);

    return nextTick();
  };

  const submitForm = () => {
    findForm().vm.$emit('submit', { preventDefault: () => {} });
    return nextTick();
  };

  it('shows the title', () => {
    createComponent({ title: 'My custom title' });

    expect(wrapper.findComponent(PageHeading).props('heading')).toBe('My custom title');
  });

  it('shows the submit text on the save button', () => {
    createComponent({ submitText: 'My custom submit text ' });

    expect(findSubmitButton().text()).toBe('My custom submit text');
  });

  it.each([true, false])(
    'shows/hides base role dropdown when showBaseRole is %s',
    (showBaseRole) => {
      createComponent({ showBaseRole });

      expect(findBaseRoleFormGroup().exists()).toBe(showBaseRole);
    },
  );

  describe('common behavior', () => {
    beforeEach(() => createComponent());

    it('shows the role dropdown with the expected options', () => {
      const expectedOptions = [
        'MINIMAL_ACCESS',
        'GUEST',
        'PLANNER',
        'REPORTER',
        'DEVELOPER',
        'MAINTAINER',
      ];

      expect(
        findRoleDropdown()
          .props('items')
          .map((role) => role.value),
      ).toStrictEqual(expectedOptions);
    });

    it('shows submit button', () => {
      expect(findSubmitButton().attributes('type')).toBe('submit');
      expect(findSubmitButton().props()).toMatchObject({
        variant: 'confirm',
        loading: false,
      });
    });

    it('shows cancel button', () => {
      expect(findCancelButton().text()).toBe('Cancel');
      expect(findCancelButton().props('disabled')).toBe(false);
    });

    it('emits cancel event when cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  describe('when there is a role', () => {
    beforeEach(() => createComponent({ role: mockMemberRole }));

    it('populates the name field', () => {
      expect(findNameField().attributes('value')).toBe('Custom role');
    });

    it('populates the description field', () => {
      expect(findDescriptionField().attributes('value')).toBe('Custom role description');
    });

    it('populates the base role dropdown', () => {
      expect(findRoleDropdown().props('selected')).toBe('DEVELOPER');
    });

    it('disables the base role dropdown', () => {
      expect(findRoleDropdown().props('disabled')).toBe(true);
    });

    it('populates the permissions selector', () => {
      expect(findPermissionsSelector().props('permissions')).toEqual(['A', 'B']);
    });
  });

  describe('field validation', () => {
    beforeEach(() => createComponent());

    it('shows a warning if no base role is selected', async () => {
      expect(findBaseRoleFormGroup().props('state')).toBe(true);

      await submitForm();

      expect(findBaseRoleFormGroup().props('state')).toBe(false);
    });

    it('shows a warning if name field is empty', async () => {
      expect(findNameField().props('state')).toBe(true);

      await submitForm();

      expect(findNameField().attributes('state')).toBe(undefined);
    });

    it('shows a warning if no permissions are selected', async () => {
      expect(findPermissionsSelector().props('isValid')).toBe(true);

      findPermissionsSelector().vm.$emit('update:permissions', []);
      await submitForm();

      expect(findPermissionsSelector().props('isValid')).toBe(false);
    });
  });

  describe('when role form is submitted', () => {
    it('dismisses any previous alert', () => {
      createComponent();
      submitForm();

      // Verify that the first alert was created and not dismissed.
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(mockAlertDismiss).toHaveBeenCalledTimes(0);

      submitForm();

      // Verify that the second alert was created and the first was dismissed.
      expect(createAlert).toHaveBeenCalledTimes(2);
      expect(mockAlertDismiss).toHaveBeenCalledTimes(1);
    });

    it('emits submit event with form data', () => {
      createComponent();
      fillForm();
      submitForm();

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual({
        name: 'My role name',
        description: 'My description',
        baseAccessLevel: 'GUEST',
        permissions: ['A'],
      });
    });
  });

  describe('when busy prop is true', () => {
    it('marks save button as loading', () => {
      createComponent({ busy: true });

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('marks cancel button as disabled', () => {
      createComponent({ busy: true });

      expect(findCancelButton().props('disabled')).toBe(true);
    });
  });
});
