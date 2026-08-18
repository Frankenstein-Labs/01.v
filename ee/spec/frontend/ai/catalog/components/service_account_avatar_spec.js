import { shallowMount } from '@vue/test-utils';
import { GlAvatarLabeled, GlAvatarLink } from '@gitlab/ui';
import ServiceAccountAvatar from 'ee/ai/catalog/components/service_account_avatar.vue';
import { mockServiceAccount } from '../mock_data';

describe('ServiceAccountAvatar', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ServiceAccountAvatar, {
      propsData: {
        serviceAccount: mockServiceAccount,
        ...props,
      },
    });
  };

  const findServiceAccountAvatar = () => wrapper.findComponent(GlAvatarLabeled);
  const findServiceAccountLink = () => wrapper.findComponent(GlAvatarLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders service account avatar', () => {
    expect(findServiceAccountAvatar().props()).toMatchObject({
      size: 32,
      src: mockServiceAccount.avatarUrl,
      label: mockServiceAccount.name,
      subLabel: `@${mockServiceAccount.username}`,
    });
  });

  it('renders service account link', () => {
    expect(findServiceAccountLink().attributes()).toMatchObject({
      href: mockServiceAccount.webPath,
      title: mockServiceAccount.name,
    });
  });
});
