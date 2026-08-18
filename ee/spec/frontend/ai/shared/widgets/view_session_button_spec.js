import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ViewSessionButton from 'ee/ai/shared/widgets/view_session_button.vue';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import duoChatAvailableQuery from 'ee/ai/graphql/duo_chat_available.query.graphql';

Vue.use(VueApollo);

describe('ViewSessionButton', () => {
  let wrapper;
  let duoChatAvailableHandler;

  const duoChatAvailableResponse = (available = true) => ({
    data: {
      currentUser: {
        id: 'gid://gitlab/User/1',
        duoChatAvailable: available,
      },
    },
  });

  const createComponent = async (props = {}) => {
    wrapper = shallowMount(ViewSessionButton, {
      apolloProvider: createMockApollo([[duoChatAvailableQuery, duoChatAvailableHandler]]),
      propsData: {
        sessionId: 42,
        ...props,
      },
    });

    await waitForPromises();
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(true));
  });

  it('renders the label', async () => {
    await createComponent();

    expect(wrapper.text()).toBe('View session');
  });

  describe('when clicked', () => {
    beforeEach(async () => {
      jest.spyOn(eventHub, '$emit');
      await createComponent();

      findButton().vm.$emit('click');
    });

    it('emits SHOW_SESSION with the session id so the panel opens', () => {
      expect(eventHub.$emit).toHaveBeenCalledWith(SHOW_SESSION, { id: 42 });
    });
  });

  describe('when the user cannot use Duo', () => {
    beforeEach(async () => {
      duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(false));

      await createComponent();
    });

    it('renders no button, because the session cannot be opened', () => {
      expect(findButton().exists()).toBe(false);
    });
  });

  describe('when the availability query fails', () => {
    beforeEach(async () => {
      duoChatAvailableHandler = jest.fn().mockRejectedValue(new Error('nope'));

      await createComponent();
    });

    it('renders no button', () => {
      expect(findButton().exists()).toBe(false);
    });
  });
});
