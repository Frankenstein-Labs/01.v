import Vue from 'vue';
import VueApollo from 'vue-apollo';
import handRaiseLeadEventHub from 'ee/hand_raise_leads/hand_raise_lead/event_hub';
import HandRaiseLeadModalStub from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_modal.vue';
import { initLazyHandRaiseLeadModal } from 'ee/hand_raise_leads/hand_raise_lead/init_lazy_hand_raise_lead_modal';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

jest.mock('ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_modal.vue', () => ({
  name: 'HandRaiseLeadModalStub',
  props: ['user', 'submitPath'],
  mountedSpy: jest.fn(),
  render(h) {
    return h('div');
  },
  mounted() {
    this.$options.mountedSpy();
    // Mirrors the real component's mounted() hook, which registers its own
    // 'openModal' listener on the shared hub, so tests can verify the wrapper in
    // init_lazy_hand_raise_lead_modal.js hands off correctly and never double-invokes `openModal`.
    jest
      .requireActual('ee/hand_raise_leads/hand_raise_lead/event_hub')
      .default.$on('openModal', (options) => this.openModal(options));
  },
  methods: {
    openModal: jest.fn(),
  },
}));

jest.mock('ee/subscriptions/graphql/graphql', () => {
  const createMockApollo = jest.requireActual('helpers/mock_apollo_helper').default;
  return createMockApollo();
});

describe('initLazyHandRaiseLeadModal', () => {
  let el;

  const cleanEl = () => {
    if (el && el.parentNode) {
      el.parentNode.removeChild(el);
    }
  };

  const createElement = (dataset = {}) => {
    cleanEl();
    const element = document.createElement('div');
    Object.assign(element.dataset, dataset);
    document.body.appendChild(element);
    return element;
  };

  const cleanUpMountedModals = () => {
    [...document.body.children].forEach((node) => {
      if (node !== el) {
        node.remove();
      }
    });
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    handRaiseLeadEventHub.$off('openModal');
    cleanUpMountedModals();
    cleanEl();
  });

  describe('isHandRaiseLeadAvailable return value', () => {
    const handRaiseLeadUser = JSON.stringify({ namespace_id: '1' });
    const handRaiseLeadSubmitPath = '/-/subscriptions/hand_raise_leads';

    it.each`
      scenario                                | dataset                                           | expected
      ${'both are present'}                   | ${{ handRaiseLeadUser, handRaiseLeadSubmitPath }} | ${true}
      ${'handRaiseLeadUser is missing'}       | ${{ handRaiseLeadSubmitPath }}                    | ${false}
      ${'handRaiseLeadSubmitPath is missing'} | ${{ handRaiseLeadUser }}                          | ${false}
      ${'neither is present'}                 | ${{}}                                             | ${false}
    `('returns $expected when $scenario', ({ dataset, expected }) => {
      el = createElement(dataset);

      expect(initLazyHandRaiseLeadModal(el)).toBe(expected);
    });

    it('returns true when the placeholder already exists on the page, even though no listener is registered', () => {
      const placeholder = document.createElement('div');
      placeholder.className = 'js-hand-raise-lead-modal';
      document.body.appendChild(placeholder);

      el = createElement({ handRaiseLeadUser, handRaiseLeadSubmitPath });

      expect(initLazyHandRaiseLeadModal(el)).toBe(true);

      placeholder.remove();
    });
  });

  describe('hand raise lead modal wiring', () => {
    const handRaiseLeadUser = JSON.stringify({
      user_name: 'sidney',
      first_name: 'Sidney',
      last_name: 'Jones',
      company_name: 'ACME',
      namespace_id: '1',
    });
    const handRaiseLeadSubmitPath = '/-/subscriptions/hand_raise_leads';

    const initWithHandRaiseLeadData = () => {
      el = createElement({ handRaiseLeadUser, handRaiseLeadSubmitPath });

      return initLazyHandRaiseLeadModal(el);
    };

    let onSpy;

    beforeEach(() => {
      onSpy = jest.spyOn(handRaiseLeadEventHub, '$on');
    });

    it('does not register a listener when handRaiseLeadUser/submitPath are not provided', () => {
      el = createElement();

      initLazyHandRaiseLeadModal(el);

      expect(onSpy).not.toHaveBeenCalled();
    });

    describe('when a hand raise lead modal placeholder already exists on the page', () => {
      let placeholder;

      beforeEach(() => {
        placeholder = document.createElement('div');
        placeholder.className = 'js-hand-raise-lead-modal';
        document.body.appendChild(placeholder);

        initWithHandRaiseLeadData();
      });

      afterEach(() => {
        placeholder.remove();
      });

      it('does not register a listener', () => {
        expect(onSpy).not.toHaveBeenCalled();
      });
    });

    describe('when handRaiseLeadUser and handRaiseLeadSubmitPath are provided', () => {
      beforeEach(() => {
        initWithHandRaiseLeadData();
      });

      it('registers a listener, then lazily imports and mounts the modal and opens it on click', async () => {
        expect(onSpy).toHaveBeenCalledWith('openModal', expect.any(Function));

        const options = { productInteraction: 'test', ctaTracking: {}, glmContent: 'glm' };
        handRaiseLeadEventHub.$emit('openModal', options);

        await waitForPromises();

        expect(HandRaiseLeadModalStub.methods.openModal).toHaveBeenCalledTimes(1);
        expect(HandRaiseLeadModalStub.methods.openModal).toHaveBeenCalledWith(options);
      });

      it('chains a click that arrives while the import is still in flight onto the same mount, without mounting a second modal', async () => {
        const firstOptions = { productInteraction: 'first' };
        const secondOptions = { productInteraction: 'second' };

        handRaiseLeadEventHub.$emit('openModal', firstOptions);
        handRaiseLeadEventHub.$emit('openModal', secondOptions);

        await waitForPromises();

        expect(HandRaiseLeadModalStub.methods.openModal).toHaveBeenCalledTimes(2);
        expect(HandRaiseLeadModalStub.methods.openModal).toHaveBeenNthCalledWith(1, firstOptions);
        expect(HandRaiseLeadModalStub.methods.openModal).toHaveBeenNthCalledWith(2, secondOptions);
        // Only a single modal was ever mounted (i.e. only one import was kicked off),
        // even though the hub emitted twice while that import was in flight.
        expect(HandRaiseLeadModalStub.mountedSpy).toHaveBeenCalledTimes(1);
      });

      it('stops listening on the shared hub once mounted, so later clicks are not double-handled', async () => {
        const offSpy = jest.spyOn(handRaiseLeadEventHub, '$off');

        handRaiseLeadEventHub.$emit('openModal', { productInteraction: 'first' });
        await waitForPromises();

        expect(offSpy).toHaveBeenCalledWith('openModal', expect.any(Function));

        // A further click reaches only the modal's own listener (registered in its
        // `mounted()` hook), not our now-removed standalone handler, so `openModal`
        // is invoked exactly once for it.
        HandRaiseLeadModalStub.methods.openModal.mockClear();
        handRaiseLeadEventHub.$emit('openModal', { productInteraction: 'second' });
        await waitForPromises();

        expect(HandRaiseLeadModalStub.methods.openModal).toHaveBeenCalledTimes(1);
      });
    });
  });
});
