import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InviteGroupsModal from '~/invite_members/components/invite_groups_modal.vue';
import InviteModalBase from 'ee/invite_members/components/invite_modal_base.vue';

describe('InviteGroupsModal', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(InviteGroupsModal, {
      propsData: {
        id: '1',
        rootId: '1',
        name: 'test name',
        isProject: false,
        invalidGroups: [],
        accessLevels: { Guest: 10, Reporter: 20, Developer: 30, Maintainer: 40, Owner: 50 },
        defaultAccessLevel: 10,
        helpLink: 'https://example.com',
        fullPath: 'project',
        freeUserCapEnabled: false,
        ...props,
      },
    });
  };

  const findBase = () => wrapper.findComponent(InviteModalBase);

  it('renders InviteModalBase component and passes correct props', () => {
    createComponent({ isProject: true });

    expect(findBase().props('isProject')).toBe(true);
  });
});
