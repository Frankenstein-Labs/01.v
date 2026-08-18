import { GlForm, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CreateSyncForm from 'ee/roles_and_permissions/components/ldap_sync/create_sync_form.vue';
import ServerFormGroup from 'ee/roles_and_permissions/components/ldap_sync/server_form_group.vue';
import SyncMethodFormGroup from 'ee/roles_and_permissions/components/ldap_sync/sync_method_form_group.vue';
import GroupCnFormGroup from 'ee/roles_and_permissions/components/ldap_sync/group_cn_form_group.vue';
import UserFilterFormGroup from 'ee/roles_and_permissions/components/ldap_sync/user_filter_form_group.vue';
import AdminRoleFormGroup from 'ee/roles_and_permissions/components/ldap_sync/admin_role_form_group.vue';
import { ldapServers } from '../../mock_data';

describe('CreateSyncForm component', () => {
  let wrapper;

  const createWrapper = ({ busy = false } = {}) => {
    wrapper = shallowMountExtended(CreateSyncForm, {
      propsData: { busy },
      provide: { ldapServers },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findServerFormGroup = () => wrapper.findComponent(ServerFormGroup);
  const findSyncMethodFormGroup = () => wrapper.findComponent(SyncMethodFormGroup);
  const findGroupCnFormGroup = () => wrapper.findComponent(GroupCnFormGroup);
  const findUserFilterFormGroup = () => wrapper.findComponent(UserFilterFormGroup);
  const findAdminRoleFormGroup = () => wrapper.findComponent(AdminRoleFormGroup);

  const findFormButtons = () => wrapper.findAllComponents(GlButton);
  const findCancelButton = () => findFormButtons().at(0);
  const findSubmitButton = () => findFormButtons().at(1);

  const submitForm = () => {
    findSubmitButton().vm.$emit('click');
    return nextTick();
  };

  const selectServer = (value = 'ldapmain') => {
    findServerFormGroup().vm.$emit('input', value);
  };

  const selectSyncMethod = (value = 'group_cn') => {
    findSyncMethodFormGroup().vm.$emit('input', value);
    return nextTick();
  };

  const selectGroup = () => {
    findGroupCnFormGroup().vm.$emit('input', 'group1');
  };

  const fillUserFilter = () => {
    findUserFilterFormGroup().vm.$emit('input', 'uid=john,ou=people,dc=example,dc=com');
  };

  const selectAdminRole = () => {
    findAdminRoleFormGroup().vm.$emit('input', 'gid://gitlab/MemberRole/1');
  };

  beforeEach(() => createWrapper());

  it('shows form', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('shows server dropdown with first server pre-selected', () => {
    expect(findServerFormGroup().props()).toMatchObject({
      value: 'ldapmain',
      state: true,
      disabled: false,
    });
  });

  it('shows sync method radios', () => {
    expect(findSyncMethodFormGroup().props()).toMatchObject({
      value: null,
      state: true,
      disabled: false,
    });
  });

  describe('when no sync method is selected', () => {
    it('does not show group dropdown', () => {
      expect(findGroupCnFormGroup().exists()).toBe(false);
    });

    it('does not show user filter textarea', () => {
      expect(findUserFilterFormGroup().exists()).toBe(false);
    });

    it('does not show admin role dropdown', () => {
      expect(findAdminRoleFormGroup().exists()).toBe(false);
    });
  });

  describe('when group cn is selected', () => {
    beforeEach(() => selectSyncMethod('group_cn'));

    it('shows group dropdown', () => {
      expect(findGroupCnFormGroup().props()).toMatchObject({
        value: null,
        server: 'ldapmain',
        state: true,
        disabled: false,
      });
    });

    it('does not show user filter textarea', () => {
      expect(findUserFilterFormGroup().exists()).toBe(false);
    });

    it('shows admin role dropdown', () => {
      expect(findAdminRoleFormGroup().props()).toMatchObject({
        value: null,
        state: true,
        disabled: false,
      });
    });
  });

  describe('when user filter is selected', () => {
    beforeEach(() => selectSyncMethod('user_filter'));

    it('does not show group dropdown', () => {
      expect(findGroupCnFormGroup().exists()).toBe(false);
    });

    it('shows user filter textarea', () => {
      expect(findUserFilterFormGroup().props()).toMatchObject({
        value: '',
        state: true,
        disabled: false,
      });
    });

    it('shows admin role dropdown', () => {
      expect(findAdminRoleFormGroup().props()).toMatchObject({
        value: null,
        state: true,
        disabled: false,
      });
    });
  });

  it('clears selected group when server is changed', async () => {
    await selectSyncMethod('group_cn');
    findServerFormGroup().vm.$emit('ldapmain');
    findGroupCnFormGroup().vm.$emit('group1');
    findServerFormGroup().vm.$emit('ldapalt');

    expect(findGroupCnFormGroup().props('value')).toBe(null);
  });

  describe('Cancel button', () => {
    it('shows button', () => {
      expect(findCancelButton().text()).toBe('Cancel');
      expect(findCancelButton().props('disabled')).toBe(false);
    });

    it('emits cancel event when clicked', () => {
      findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  describe('Add button', () => {
    it('shows button', () => {
      expect(findSubmitButton().text()).toBe('Add');
      expect(findSubmitButton().props()).toMatchObject({ variant: 'confirm', loading: false });
    });

    it('does not emit submit event when some fields are invalid', () => {
      submitForm();

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it.each`
      syncMethod       | fillField         | expectedFieldData
      ${'group_cn'}    | ${selectGroup}    | ${{ cn: 'group1' }}
      ${'user_filter'} | ${fillUserFilter} | ${{ filter: 'uid=john,ou=people,dc=example,dc=com' }}
    `(
      'emits submit event when sync method is $syncMethod and all fields are filled',
      async ({ syncMethod, fillField, expectedFieldData }) => {
        selectServer();
        await selectSyncMethod(syncMethod);
        fillField();
        selectAdminRole();
        submitForm();

        expect(wrapper.emitted('submit')).toHaveLength(1);
        expect(wrapper.emitted('submit')[0][0]).toEqual({
          provider: 'ldapmain',
          ...expectedFieldData,
          adminMemberRoleId: 'gid://gitlab/MemberRole/1',
        });
      },
    );
  });

  describe('when form is submitted', () => {
    describe.each`
      name             | findFormGroup              | syncMethod       | fillField           | expectedValue
      ${'server'}      | ${findServerFormGroup}     | ${null}          | ${selectServer}     | ${'ldapmain'}
      ${'sync method'} | ${findSyncMethodFormGroup} | ${null}          | ${selectSyncMethod} | ${'group_cn'}
      ${'group cn'}    | ${findGroupCnFormGroup}    | ${'group_cn'}    | ${selectGroup}      | ${'group1'}
      ${'user filter'} | ${findUserFilterFormGroup} | ${'user_filter'} | ${fillUserFilter}   | ${'uid=john,ou=people,dc=example,dc=com'}
      ${'admin role'}  | ${findAdminRoleFormGroup}  | ${'group_cn'}    | ${selectAdminRole}  | ${'gid://gitlab/MemberRole/1'}
    `('$name form group', ({ syncMethod, findFormGroup, fillField, expectedValue }) => {
      beforeEach(() => {
        createWrapper();
        selectServer(null); // Unselect the server. It pre-selects the first server by default.
        return selectSyncMethod(syncMethod);
      });

      it('shows form group as invalid', async () => {
        await submitForm();

        expect(findFormGroup().props('state')).toBe(false);
      });

      describe('when field is filled', () => {
        beforeEach(() => {
          submitForm();
          fillField();
        });

        it('passes value to form group', () => {
          expect(findFormGroup().props('value')).toBe(expectedValue);
        });

        it('shows form group as valid', () => {
          expect(findFormGroup().props('state')).toBe(true);
        });
      });
    });
  });

  describe.each`
    syncMethod       | findSelectedSyncMethodGroup
    ${'group_cn'}    | ${findGroupCnFormGroup}
    ${'user_filter'} | ${findUserFilterFormGroup}
  `(
    'when $syncMethod is selected and busy prop is true',
    ({ syncMethod, findSelectedSyncMethodGroup }) => {
      beforeEach(async () => {
        createWrapper();
        await selectSyncMethod(syncMethod);
        return wrapper.setProps({ busy: true });
      });

      it.each`
        name                            | findComponent
        ${'server dropdown'}            | ${findServerFormGroup}
        ${'sync method radios'}         | ${findSyncMethodFormGroup}
        ${syncMethod}                   | ${findSelectedSyncMethodGroup}
        ${'custom admin role dropdown'} | ${findAdminRoleFormGroup}
        ${'cancel button'}              | ${findCancelButton}
      `('disables $name', ({ findComponent }) => {
        expect(findComponent().props('disabled')).toBe(true);
      });

      it('shows submit button as loading', () => {
        expect(findSubmitButton().props('loading')).toBe(true);
      });
    },
  );

  describe.each`
    oldSyncMethod    | findOldFormGroup           | newSyncMethod    | findNewFormGroup
    ${'group_cn'}    | ${findGroupCnFormGroup}    | ${'user_filter'} | ${findUserFilterFormGroup}
    ${'user_filter'} | ${findUserFilterFormGroup} | ${'group_cn'}    | ${findGroupCnFormGroup}
  `(
    'when $oldSyncMethod is selected, form is submitted, and $newSyncMethod is selected afterwards',
    ({ oldSyncMethod, newSyncMethod, findNewFormGroup }) => {
      beforeEach(async () => {
        createWrapper();
        await selectSyncMethod(oldSyncMethod);
        await submitForm();
        return selectSyncMethod(newSyncMethod);
      });

      it(`disables validation for ${newSyncMethod} field`, async () => {
        findNewFormGroup().vm.$emit('input', '');
        await nextTick();

        expect(findNewFormGroup().props('state')).toBe(true);
      });

      it(`enables validation for ${newSyncMethod} field when form is submitted`, async () => {
        findNewFormGroup().vm.$emit('input', '');
        await submitForm();

        expect(findNewFormGroup().props('state')).toBe(false);
      });
    },
  );
});
