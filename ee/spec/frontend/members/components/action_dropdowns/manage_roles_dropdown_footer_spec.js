import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ManageRolesDropdownFooter from 'ee/members/components/action_dropdowns/manage_roles_dropdown_footer.vue';

describe('ManageRolesDropdownFooter', () => {
  let wrapper;

  const manageMemberRolesPath = 'some path';

  const createComponent = (provide = {}) => {
    wrapper = shallowMount(ManageRolesDropdownFooter, {
      provide: {
        manageMemberRolesPath,
        ...provide,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  it('renders a button with the correct text and link', () => {
    createComponent();

    expect(findButton().exists()).toBe(true);
    expect(findButton().text()).toBe('Manage roles');
    expect(findButton().attributes('href')).toBe(manageMemberRolesPath);
  });

  it('renders no button when no `manageMemberRolesPath` is provided', () => {
    createComponent({ manageMemberRolesPath: null });

    expect(findButton().exists()).toBe(false);
  });
});
