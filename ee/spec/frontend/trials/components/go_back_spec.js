import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import GoBack from 'ee/trials/components/go_back.vue';

describe('GoBack', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(GoBack, {
      mocks: {
        $router: {
          go: jest.fn(),
        },
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  it('has the button', () => {
    expect(findButton().exists()).toBe(true);
  });

  it('has the correct button text', () => {
    expect(findButton().text()).toBe('Go back');
  });

  it('redirects to the previous page on Cancel button click', () => {
    findButton().vm.$emit('click');

    expect(wrapper.vm.$router.go).toHaveBeenCalledWith(-1);
  });
});
