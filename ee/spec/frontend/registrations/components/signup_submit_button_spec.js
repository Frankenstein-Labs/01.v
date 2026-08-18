import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SignupSubmitButton from 'ee/registrations/components/signup_submit_button.vue';
import { arkoseState, ARKOSE_STATE_KEY, resetArkoseState } from 'ee/arkose_labs/state';
import { resetObservable } from '~/lib/utils/observable';

describe('EE SignupSubmitButton', () => {
  let wrapper;

  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = () => {
    wrapper = mountExtended(SignupSubmitButton, {
      propsData: {
        buttonText: 'Continue',
      },
    });
  };

  beforeEach(() => {
    resetArkoseState();
    createComponent();
  });

  afterEach(() => {
    resetObservable(ARKOSE_STATE_KEY);
  });

  it('renders the submit button', () => {
    expect(findButton().text()).toBe('Continue');
  });

  it('is not in loading state by default', () => {
    expect(findButton().props('loading')).toBe(false);
  });

  it('shows loading state when arkoseState.awaitingToken is true', async () => {
    arkoseState.awaitingToken = true;
    await nextTick();

    expect(findButton().props('loading')).toBe(true);
  });

  it('stops loading when arkoseState.awaitingToken becomes false', async () => {
    arkoseState.awaitingToken = true;
    await nextTick();

    arkoseState.awaitingToken = false;
    await nextTick();

    expect(findButton().props('loading')).toBe(false);
  });
});
