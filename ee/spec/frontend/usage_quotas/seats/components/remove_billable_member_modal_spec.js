import { GlSprintf, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import RemoveBillableMemberModal from 'ee/usage_quotas/seats/components/remove_billable_member_modal.vue';

describe('RemoveBillableMemberModal', () => {
  let wrapper;

  const billableMemberToRemove = {
    id: 2,
    username: 'username',
    name: 'First Last',
  };

  const createComponent = () => {
    wrapper = shallowMount(RemoveBillableMemberModal, {
      stubs: {
        GlSprintf,
        GlModal,
      },
      provide: {
        namespaceName: 'Dummy namespace',
      },
      propsData: {
        billableMemberToRemove,
      },
    });
  };

  describe('on rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the submit button disabled', () => {
      expect(wrapper.findComponent(GlModal).attributes('okdisabled')).toBe('true');
    });

    it('renders the title with username', () => {
      expect(wrapper.findComponent(GlModal).props('title')).toBe(
        `Remove user @${billableMemberToRemove.username} from your subscription`,
      );
    });

    it('renders the confirmation label with username', () => {
      expect(wrapper.findComponent(GlModal).find('label').text()).toContain(
        billableMemberToRemove.username,
      );
    });
  });
});
