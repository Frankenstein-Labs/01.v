import { nextTick, h } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DuoChatEmptyStateHeader from 'ee/ai/duo_agentic_chat/components/duo_chat_empty_state_header.vue';
import {
  eventHub,
  DUO_CHAT_REGISTER_EMPTY_STATE_HEADER,
  DUO_CHAT_REQUEST_EMPTY_STATE_HEADER,
} from 'ee/ai/events/panel';

// Render-function stub (no template) so it works under the runtime-only Vue
// build, and with a format valid in both Vue 2 and Vue 3.
const StubAction = {
  name: 'StubAction',
  props: { label: { type: String, default: '' } },
  render() {
    return h('div', this.label);
  },
};

describe('DuoChatEmptyStateHeader', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = mountExtended(DuoChatEmptyStateHeader);
  };

  const findDefaultTitle = () => wrapper.find('h2');
  const findStub = () => wrapper.findComponent(StubAction);

  const register = ({ id = 'workplan', component = StubAction, props = {} } = {}) =>
    eventHub.$emit(DUO_CHAT_REGISTER_EMPTY_STATE_HEADER, { id, component, props });

  describe('when nothing is registered', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the default Duo Agent Platform copy', () => {
      expect(findDefaultTitle().text()).toBe('GitLab Duo Agent Platform');
      expect(findStub().exists()).toBe(false);
    });
  });

  describe('handshake', () => {
    it('emits a request for current registrations on mount', () => {
      const spy = jest.fn();
      eventHub.$on(DUO_CHAT_REQUEST_EMPTY_STATE_HEADER, spy);
      expect(spy).toHaveBeenCalledTimes(0);

      createComponent();

      expect(spy).toHaveBeenCalledTimes(1);
      eventHub.$off(DUO_CHAT_REQUEST_EMPTY_STATE_HEADER, spy);
    });
  });

  describe('when an action is registered after mount', () => {
    beforeEach(async () => {
      createComponent();
      register({ props: { label: 'hello' } });
      await nextTick();
    });

    it('renders the registered action instead of the default copy', () => {
      expect(findStub().exists()).toBe(true);
      expect(findStub().props('label')).toBe('hello');
      expect(findDefaultTitle().exists()).toBe(false);
    });
  });

  describe('when the same id re-registers', () => {
    beforeEach(async () => {
      createComponent();
      register({ props: { label: 'first' } });
      await nextTick();
    });

    it('replaces the previous registration instead of duplicating', async () => {
      register({ props: { label: 'second' } });
      await nextTick();

      expect(wrapper.findAllComponents(StubAction)).toHaveLength(1);
      expect(findStub().props('label')).toBe('second');
    });
  });

  describe('when a null component is registered for the id', () => {
    beforeEach(async () => {
      createComponent();
      register();
      await nextTick();
    });

    it('removes the slot and restores the default copy', async () => {
      expect(findStub().exists()).toBe(true);

      register({ component: null });
      await nextTick();

      expect(findStub().exists()).toBe(false);
      expect(findDefaultTitle().exists()).toBe(true);
    });
  });
});
